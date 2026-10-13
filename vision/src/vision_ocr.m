// Text in a picture, by Vision: a request on a PNG file, at the size it is
// (it is not scaled down), whose words come back with where they are.
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
        // How tall the picture is for its width, to compare down and across.
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
        if (source) {
            NSDictionary *props = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
            double w = [props[(NSString *)kCGImagePropertyPixelWidth] doubleValue];
            double h = [props[(NSString *)kCGImagePropertyPixelHeight] doubleValue];
            if (w > 0 && h > 0) *aspect = h / w;
            CFRelease(source);
        }
        VNRecognizeTextRequest *request = [VNRecognizeTextRequest new];
        request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
        request.usesLanguageCorrection = YES;
        request.automaticallyDetectsLanguage = YES;
        request.minimumTextHeight = 0.0;
        VNImageRequestHandler *handler =
            [[VNImageRequestHandler alloc] initWithURL:url options:@{}];
        NSError *error = nil;
        if (![handler performRequests:@[request] error:&error]) {
            say(message, message_capacity, error.localizedDescription ?: @"Vision failed");
            return 0;
        }
        int count = 0, used = 0, line = 0;
        // As Vision has them: the order is for Vision.Layout to decide,
        // which can see the columns.
        NSArray *ordered = request.results;
        for (VNRecognizedTextObservation *seen in ordered) {
            VNRecognizedText *best = [seen topCandidates:1].firstObject;
            if (!best) continue;
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
                words[count].top = (float)(1.0 - r.origin.y - r.size.height);
                words[count].width = (float)r.size.width;
                words[count].height = (float)r.size.height;
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
