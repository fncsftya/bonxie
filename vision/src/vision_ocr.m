// Text in a picture, by Vision: a request on a PNG file, whose words come back
// with where they are. Vision scales a picture down to a fixed size, so a long
// page (a whole web page, say) is read in overlapping tiles about as tall as
// the picture is wide, each at the size it is.
// It may be called from any thread, and from several at once.

#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <ImageIO/ImageIO.h>

// As Vision.Word in vision.ads.
typedef struct {
    int line;
    int first;   // 1-based, in the text
    int last;
    float left;  // 0..1 across the picture
    float top;   // 0..1 down the picture
    float width;
    float height;
} vn_word;

static void say(char *message, int capacity, NSString *why)
{
    strlcpy(message, why.UTF8String ?: "", capacity);
}

// Returns 1 if it recognized (maybe nothing), 0 if it could not.
int vn_recognize(const char *path, vn_word *words, int max_words,
                 char *text, int text_capacity,
                 int *word_count, int *text_length, int *truncated,
                 double *aspect,
                 char *message, int message_capacity)
{
    @autoreleasepool {
        *word_count = 0;
        *text_length = 0;
        *truncated = 0;
        *aspect = 1.0;
        message[0] = 0;
        NSURL *url = [NSURL fileURLWithFileSystemRepresentation:path
                                                    isDirectory:NO
                                                  relativeToURL:nil];
        if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
            say(message, message_capacity, @"No such picture");
            return 0;
        }
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        CGImageRef picture = source ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
        if (source) CFRelease(source);
        if (!picture) {
            say(message, message_capacity, @"Could not read the picture");
            return 0;
        }
        double width = (double)CGImageGetWidth(picture);
        double height = (double)CGImageGetHeight(picture);
        // How tall the picture is for its width, to compare down and across.
        if (width > 0 && height > 0) *aspect = height / width;
        // Tiles overlap so that no line is cut in every one; a line is kept
        // from the tile in which it is farthest from the cut.
        double tile = height > 1.5 * width ? width : height;
        double overlap = tile < height ? 0.15 * tile : 0.0;
        NSMutableArray *kept = [NSMutableArray array];  // @{text, top, height} as fractions
        for (double y = 0; y < height; y += tile - overlap) {
            double h = MIN(tile, height - y);
            CGImageRef part = CGImageCreateWithImageInRect(picture, CGRectMake(0, y, width, h));
            VNRecognizeTextRequest *request = [VNRecognizeTextRequest new];
            request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
            request.usesLanguageCorrection = YES;
            request.automaticallyDetectsLanguage = YES;
            request.minimumTextHeight = 0.0;
            VNImageRequestHandler *handler =
                [[VNImageRequestHandler alloc] initWithCGImage:part options:@{}];
            NSError *error = nil;
            BOOL done = [handler performRequests:@[request] error:&error];
            CGImageRelease(part);
            if (!done) {
                CGImageRelease(picture);
                say(message, message_capacity, error.localizedDescription ?: @"Vision failed");
                return 0;
            }
            double from = y > 0 ? y + overlap / 2 : 0;
            double to = y + h < height ? y + h - overlap / 2 : height;
            // As Vision has them: the order is for Vision.Layout to decide,
            // which can see the columns.
            for (VNRecognizedTextObservation *seen in request.results) {
                VNRecognizedText *best = [seen topCandidates:1].firstObject;
                if (!best) continue;
                CGRect r = seen.boundingBox;  // normalized, from the bottom left
                double middle = y + (1.0 - r.origin.y - r.size.height / 2) * h;
                if (middle < from || middle >= to) continue;
                [kept addObject:@{@"text": best, @"y": @(y), @"h": @(h)}];
            }
            if (y + h >= height) break;
        }
        CGImageRelease(picture);
        int count = 0, used = 0, line = 0;
        for (NSDictionary *seen in kept) {
            VNRecognizedText *best = seen[@"text"];
            double y = [seen[@"y"] doubleValue], h = [seen[@"h"] doubleValue];
            line++;
            NSString *string = best.string;
            BOOL stop = NO;
            // Words are the runs between white space, so that "foo.bar" and
            // "it's" stay whole.
            NSUInteger i = 0, n = string.length;
            while (i < n && !stop) {
                while (i < n && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                    characterIsMember:[string characterAtIndex:i]]) i++;
                NSUInteger start = i;
                while (i < n && ![[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                    characterIsMember:[string characterAtIndex:i]]) i++;
                if (i == start) break;
                NSRange range = NSMakeRange(start, i - start);
                NSString *word = [string substringWithRange:range];
                const char *utf8 = word.UTF8String;
                int bytes = (int)strlen(utf8);
                if (count >= max_words || used + bytes > text_capacity) {
                    *truncated = 1;
                    stop = YES;
                    break;
                }
                NSError *boxError = nil;
                VNRectangleObservation *box = [best boundingBoxForRange:range error:&boxError];
                if (!box) continue;
                CGRect r = box.boundingBox;  // normalized, from the bottom left
                memcpy(text + used, utf8, bytes);
                words[count].line = line;
                words[count].first = used + 1;
                words[count].last = used + bytes;
                words[count].left = (float)r.origin.x;
                // In the tile, then in the whole picture.
                words[count].top = (float)((y + (1.0 - r.origin.y - r.size.height) * h) / height);
                words[count].width = (float)r.size.width;
                words[count].height = (float)(r.size.height * h / height);
                used += bytes;
                count++;
            }
            if (stop) break;
        }
        *word_count = count;
        *text_length = used;
        return 1;
    }
}
