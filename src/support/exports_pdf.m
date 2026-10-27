/*
 * A document as a PDF: its blocks, set in Georgia with CoreText (which breaks the lines, falls back to a font
 * that has a character, and finds each page's room) and written by Core Graphics, which embeds the fonts and
 * makes a link a link.
 *
 * The blocks come as one UTF-8 buffer, written by Exports.Pdf: blocks apart by RS (0x1E); a block is
 *   kind US level US indent US quoted US figure, then each span as GS marks US address US words
 * (kind 0 paragraph, 1 heading, 2 bullet, 3 number; marks as a sum of 1 italic, 2 bold, 4 struck, 8 underlined,
 * 16 linked). Text holds no control character but those, which Exports.Pdf takes out.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>
#include <stdlib.h>
#include <string.h>

#define RS 0x1E
#define GS 0x1D
#define US 0x1F

static NSString *const StrikeKey = @"BonxieStrike";
static NSString *const LinkKey = @"BonxieLink";
static NSString *const QuoteKey = @"BonxieQuote";

static const CGFloat Margin = 72.0;
static const CGFloat Body_Size = 11.0;
static const CGFloat Step = 24.0;       /* of indent, and of a list's level */
static const CGFloat Hang = 18.0;       /* from a list's mark to its words */
static const CGFloat Quote_Step = 18.0; /* a quoted paragraph is set in by this, its rule in the gap */

static CTFontRef make_font(CGFloat size, BOOL bold, BOOL italic)
{
	CTFontRef base = CTFontCreateWithName(CFSTR("Georgia"), size, NULL);
	CTFontSymbolicTraits traits = (bold ? kCTFontBoldTrait : 0) | (italic ? kCTFontItalicTrait : 0);
	if (traits == 0)
		return base;
	CTFontRef styled = CTFontCreateCopyWithSymbolicTraits(base, size, NULL, traits, traits);
	if (styled == NULL)
		return base;
	CFRelease(base);
	return styled;
}

static CTParagraphStyleRef make_style(CGFloat first, CGFloat head, CGFloat before, CGFloat after, BOOL tabbed)
{
	CGFloat multiple = 1.25;
	CTTextAlignment alignment = kCTTextAlignmentLeft;
	CTTextTabRef tab = CTTextTabCreate(kCTTextAlignmentLeft, head, NULL);
	CFArrayRef tabs = CFArrayCreate(NULL, (const void **)&tab, 1, &kCFTypeArrayCallBacks);
	CTParagraphStyleSetting settings[] = {
		{kCTParagraphStyleSpecifierFirstLineHeadIndent, sizeof first, &first},
		{kCTParagraphStyleSpecifierHeadIndent, sizeof head, &head},
		{kCTParagraphStyleSpecifierParagraphSpacingBefore, sizeof before, &before},
		{kCTParagraphStyleSpecifierParagraphSpacing, sizeof after, &after},
		{kCTParagraphStyleSpecifierLineHeightMultiple, sizeof multiple, &multiple},
		{kCTParagraphStyleSpecifierAlignment, sizeof alignment, &alignment},
		{kCTParagraphStyleSpecifierTabStops, sizeof tabs, &tabs},
	};
	CTParagraphStyleRef style = CTParagraphStyleCreate(settings, tabbed ? 7 : 6);
	CFRelease(tabs);
	CFRelease(tab);
	return style;
}

/* The attributes of words with these marks in a block of this size. */
static NSDictionary *attributes_for(CGFloat size, BOOL bold, BOOL italic, int marks, NSString *address,
				    CTParagraphStyleRef style, NSNumber *quote)
{
	NSMutableDictionary *made = [NSMutableDictionary dictionary];
	CTFontRef font = make_font(size, bold || (marks & 2), italic || (marks & 1));
	CGColorRef ink = CGColorCreateGenericRGB(0.1, 0.1, 0.1, 1.0);
	made[(__bridge id)kCTFontAttributeName] = (__bridge id)font;
	made[(__bridge id)kCTParagraphStyleAttributeName] = (__bridge id)style;
	made[(__bridge id)kCTForegroundColorAttributeName] = (__bridge id)ink;
	CGColorRelease(ink);
	CFRelease(font);
	if (marks & 8)
		made[(__bridge id)kCTUnderlineStyleAttributeName] = @(kCTUnderlineStyleSingle);
	if (marks & 4)
		made[StrikeKey] = @YES;
	if (quote != nil)
		made[QuoteKey] = quote;
	if ((marks & 16) && address.length > 0) {
		NSURL *url = [NSURL URLWithString:address];
		if (url != nil) {
			CGColorRef blue = CGColorCreateGenericRGB(0.02, 0.39, 0.76, 1.0);
			made[LinkKey] = url;
			made[(__bridge id)kCTForegroundColorAttributeName] = (__bridge id)blue;
			made[(__bridge id)kCTUnderlineStyleAttributeName] = @(kCTUnderlineStyleSingle);
			CGColorRelease(blue);
		}
	}
	return made;
}

static NSArray<NSString *> *split(NSString *words, unichar by)
{
	return [words componentsSeparatedByString:[NSString stringWithCharacters:&by length:1]];
}

static NSAttributedString *make_text(NSString *whole)
{
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
	BOOL first = YES;
	for (NSString *block in split(whole, RS)) {
		NSArray<NSString *> *parts = split(block, GS);
		NSArray<NSString *> *head = split(parts[0], US);
		if (head.count < 5)
			continue;
		int kind = head[0].intValue, level = head[1].intValue;
		int indent = head[2].intValue;
		BOOL quoted = head[3].intValue != 0 && kind == 0;
		CGFloat size = Body_Size, left = 0, before = 0, after = 7;
		CGFloat first_indent, head_indent;
		BOOL bold = NO, tabbed = NO;
		NSString *lead = @"";
		if (kind == 1) {
			size = level == 1 ? 22.0 : level == 2 ? 17.0 : 14.0;
			bold = YES;
			before = 12.0;
			after = 6.0;
			first_indent = head_indent = 0;
		} else if (kind >= 2) {
			left = Step * indent + Hang;
			first_indent = left;
			head_indent = left + Hang;
			tabbed = YES;
			lead = kind == 2 ? @"•\t" : [NSString stringWithFormat:@"%@.\t", head[4]];
			after = 3.0;
		} else {
			left = Step * indent + (quoted ? Quote_Step : 0);
			first_indent = head_indent = left;
		}
		NSNumber *bar = quoted ? @(left - 8.0) : nil;
		CTParagraphStyleRef style = make_style(first_indent, head_indent, before, after, tabbed);
		if (!first)
			[text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
		first = NO;
		NSDictionary *plain = attributes_for(size, bold, NO, 0, nil, style, bar);
		if (lead.length > 0)
			[text appendAttributedString:[[NSAttributedString alloc] initWithString:lead attributes:plain]];
		for (NSUInteger i = 1; i < parts.count; i++) {
			NSArray<NSString *> *span = split(parts[i], US);
			if (span.count < 3)
				continue;
			NSDictionary *as = attributes_for(size, bold, NO, span[0].intValue, span[1], style, bar);
			[text appendAttributedString:[[NSAttributedString alloc] initWithString:span[2] attributes:as]];
		}
		CFRelease(style);
	}
	return text;
}

/* What a page's lines have that CTFrameDraw does not draw: strikethrough, the rule of a quote, and links. */
static void mark_page(CGContextRef context, CTFrameRef frame, CGRect room)
{
	CFArrayRef lines = CTFrameGetLines(frame);
	CFIndex count = CFArrayGetCount(lines);
	CGPoint *origins = calloc((size_t)count + 1, sizeof(CGPoint));
	CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
	for (CFIndex i = 0; i < count; i++) {
		CTLineRef line = CFArrayGetValueAtIndex(lines, i);
		CFArrayRef runs = CTLineGetGlyphRuns(line);
		CGPoint origin = CGPointMake(room.origin.x + origins[i].x, room.origin.y + origins[i].y);
		BOOL ruled = NO;
		for (CFIndex r = 0; r < CFArrayGetCount(runs); r++) {
			CTRunRef run = CFArrayGetValueAtIndex(runs, r);
			NSDictionary *as = (__bridge NSDictionary *)CTRunGetAttributes(run);
			CGFloat ascent, descent, leading;
			double width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
			CGPoint at;
			CTRunGetPositions(run, CFRangeMake(0, 1), &at);
			CGRect box = CGRectMake(origin.x + at.x, origin.y + at.y - descent, width, ascent + descent);
			if (as[QuoteKey] != nil && !ruled) {
				CGFloat x = room.origin.x + [as[QuoteKey] doubleValue];
				CGContextSetRGBFillColor(context, 0.73, 0.73, 0.73, 1.0);
				CGContextFillRect(context, CGRectMake(x, box.origin.y - 3.0, 2.5, box.size.height + 6.0));
				ruled = YES;
			}
			if (as[StrikeKey] != nil) {
				CGContextSetRGBFillColor(context, 0.1, 0.1, 0.1, 1.0);
				CGContextFillRect(context, CGRectMake(box.origin.x, origin.y + at.y + ascent * 0.3, width, 0.7));
			}
			if (as[LinkKey] != nil)
				CGPDFContextSetURLForRect(context, (__bridge CFURLRef)as[LinkKey], box);
		}
	}
	free(origins);
}

/* The PDF of the blocks, in *out (to be freed) and *out_length; 0 if it was made. */
int bonxie_pdf_render(const char *data, size_t length, const char *title, double width, double height,
		      unsigned char **out, size_t *out_length)
{
	@autoreleasepool {
		NSString *whole = [[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding];
		if (whole == nil)
			return 1;
		NSAttributedString *text = make_text(whole);
		CFMutableDataRef bytes = CFDataCreateMutable(NULL, 0);
		CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData(bytes);
		CGRect media = CGRectMake(0, 0, width, height);
		NSString *name = [NSString stringWithUTF8String:title];
		NSDictionary *info = @{
			(__bridge id)kCGPDFContextTitle : name ?: @"",
			(__bridge id)kCGPDFContextCreator : @"Bonxie",
		};
		CGContextRef context = CGPDFContextCreate(consumer, &media, (__bridge CFDictionaryRef)info);
		CGDataConsumerRelease(consumer);
		if (context == NULL) {
			CFRelease(bytes);
			return 2;
		}
		CTFramesetterRef setter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
		CGRect room = CGRectInset(media, Margin, Margin);
		CGPathRef path = CGPathCreateWithRect(room, NULL);
		CFIndex start = 0, total = (CFIndex)text.length;
		do {
			CGPDFContextBeginPage(context, NULL);
			CTFrameRef frame = CTFramesetterCreateFrame(setter, CFRangeMake(start, 0), path, NULL);
			CFRange shown = CTFrameGetVisibleStringRange(frame);
			CTFrameDraw(frame, context);
			mark_page(context, frame, room);
			CGPDFContextEndPage(context);
			CFRelease(frame);
			start += shown.length > 0 ? shown.length : 1; /* a character too big for a page is skipped */
		} while (start < total);
		CGPathRelease(path);
		CFRelease(setter);
		CGPDFContextClose(context);
		CGContextRelease(context);
		*out_length = (size_t)CFDataGetLength(bytes);
		*out = malloc(*out_length);
		if (*out == NULL) {
			CFRelease(bytes);
			return 3;
		}
		memcpy(*out, CFDataGetBytePtr(bytes), *out_length);
		CFRelease(bytes);
	}
	return 0;
}
