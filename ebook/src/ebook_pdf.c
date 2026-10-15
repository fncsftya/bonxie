/* Pages of PDFs, rendered with PDFium.
 *
 * A page is drawn by PDFium straight into a bitmap of the size wanted, and
 * the bitmap is written as a PNG file with ImageIO (part of macOS).
 *
 * PDFium may not be called from two threads at once, and is started once:
 * every call takes the one lock. The last document opened is kept open (a
 * page view makes the pages it shows one by one), until another is wanted
 * or the file changes; PDFium reads only what a page needs.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <fpdfview.h>
#include <fpdf_doc.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static int started = 0;

static void put_message(char *dest, int cap, const char *text)
{
	if (cap > 0) {
		snprintf(dest, (size_t) cap, "%s", text);
	}
}

static const char *load_failure(unsigned long error)
{
	switch (error) {
	case FPDF_ERR_FILE:     return "the file cannot be opened";
	case FPDF_ERR_FORMAT:   return "the file is not a PDF, or is damaged";
	case FPDF_ERR_PASSWORD: return "the document needs a password";
	case FPDF_ERR_SECURITY: return "the document's security is not supported";
	case FPDF_ERR_PAGE:     return "there is no such page";
	default:                return "the document cannot be read";
	}
}

void eb_lock(void)
{
	pthread_mutex_lock(&lock);
}

void eb_unlock(void)
{
	pthread_mutex_unlock(&lock);
}

static FPDF_DOCUMENT kept_doc = NULL;
static char kept_path[1024];
static struct timespec kept_time;
static off_t kept_size;

/* Open the document, with the lock held: it is not to be closed. NULL, and
 * the reason, if not. */
FPDF_DOCUMENT eb_open_locked(const char *path, char *message, int message_cap)
{
	struct stat info;
	int have = stat(path, &info) == 0;
	if (!started) {
		FPDF_InitLibrary();
		started = 1;
	}
	if (kept_doc && have && strcmp(kept_path, path) == 0 && info.st_size == kept_size
	    && info.st_mtimespec.tv_sec == kept_time.tv_sec
	    && info.st_mtimespec.tv_nsec == kept_time.tv_nsec) {
		return kept_doc;
	}
	if (kept_doc) {
		FPDF_CloseDocument(kept_doc);
		kept_doc = NULL;
	}
	kept_doc = FPDF_LoadDocument(path, NULL);
	if (!kept_doc) {
		put_message(message, message_cap, load_failure(FPDF_GetLastError()));
		return NULL;
	}
	snprintf(kept_path, sizeof kept_path, "%s", path);
	kept_size = have ? info.st_size : 0;
	kept_time = have ? info.st_mtimespec : (struct timespec) {0, 0};
	return kept_doc;
}

/* The sizes, in points, of the first count pages: width, height of each. */
int eb_document_sizes(const char *path, int count, float *sizes, char *message, int message_cap)
{
	FPDF_DOCUMENT doc;
	int ok = 0, i;

	pthread_mutex_lock(&lock);
	doc = eb_open_locked(path, message, message_cap);
	if (doc) {
		ok = count <= FPDF_GetPageCount(doc);
		for (i = 0; ok && i < count; i++) {
			FS_SIZEF size;
			if (!FPDF_GetPageSizeByIndexF(doc, i, &size) || size.width <= 0 || size.height <= 0) {
				size.width = 612;
				size.height = 792;
			}
			sizes[2 * i] = size.width;
			sizes[2 * i + 1] = size.height;
		}
		if (!ok) put_message(message, message_cap, "the document has fewer pages");
	}
	pthread_mutex_unlock(&lock);
	return ok;
}

/* A UTF-16LE string of PDFium (with its terminating zero, bytes bytes long)
 * as UTF-8, cut short if it does not fit. */
static void utf16_to_utf8(const uint8_t *in, unsigned long bytes, char *out, int cap)
{
	int n = 0;
	unsigned long i = 0;
	if (cap <= 0) {
		return;
	}
	while (i + 1 < bytes) {
		uint32_t c = (uint32_t) in[i] | ((uint32_t) in[i + 1] << 8);
		char enc[4];
		int len;
		i += 2;
		if (c == 0) {
			break;
		}
		if (c >= 0xD800 && c < 0xDC00 && i + 1 < bytes) {
			uint32_t d = (uint32_t) in[i] | ((uint32_t) in[i + 1] << 8);
			if (d >= 0xDC00 && d < 0xE000) {
				c = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
				i += 2;
			}
		}
		if (c < 0x80) {
			enc[0] = (char) c;
			len = 1;
		} else if (c < 0x800) {
			enc[0] = (char) (0xC0 | (c >> 6));
			enc[1] = (char) (0x80 | (c & 0x3F));
			len = 2;
		} else if (c < 0x10000) {
			enc[0] = (char) (0xE0 | (c >> 12));
			enc[1] = (char) (0x80 | ((c >> 6) & 0x3F));
			enc[2] = (char) (0x80 | (c & 0x3F));
			len = 3;
		} else {
			enc[0] = (char) (0xF0 | (c >> 18));
			enc[1] = (char) (0x80 | ((c >> 12) & 0x3F));
			enc[2] = (char) (0x80 | ((c >> 6) & 0x3F));
			enc[3] = (char) (0x80 | (c & 0x3F));
			len = 4;
		}
		if (n + len >= cap) {
			break;
		}
		memcpy(out + n, enc, (size_t) len);
		n += len;
	}
	out[n] = '\0';
}

int eb_info(const char *path, int *pages, char *title, int title_cap,
            char *message, int message_cap)
{
	FPDF_DOCUMENT doc;
	int ok = 0;

	*pages = 0;
	if (title_cap > 0) {
		title[0] = '\0';
	}
	pthread_mutex_lock(&lock);
	doc = eb_open_locked(path, message, message_cap);
	if (doc) {
		*pages = FPDF_GetPageCount(doc);
		if (*pages > 0) {
			uint8_t raw[2 * 512];
			unsigned long got = FPDF_GetMetaText(doc, "Title", raw, sizeof raw);
			if (got > 2) {
				utf16_to_utf8(raw, got < sizeof raw ? got : sizeof raw, title, title_cap);
			}
			ok = 1;
		} else {
			put_message(message, message_cap, "the document has no pages");
		}
	}
	pthread_mutex_unlock(&lock);
	return ok;
}

/* Write the bitmap (BGRx, as PDFium makes it) as a PNG file. */
static int write_png(const char *png, const void *pixels, int w, int h, int stride)
{
	int ok = 0;
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CFDataRef data = CFDataCreate(NULL, pixels, (CFIndex) stride * h);
	CGDataProviderRef provider = data ? CGDataProviderCreateWithCFData(data) : NULL;
	CGImageRef image = provider
		? CGImageCreate((size_t) w, (size_t) h, 8, 32, (size_t) stride, space,
		                kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
		                provider, NULL, false, kCGRenderingIntentDefault)
		: NULL;
	CFURLRef url = CFURLCreateFromFileSystemRepresentation(
		NULL, (const UInt8 *) png, (CFIndex) strlen(png), false);
	CGImageDestinationRef dest = (image && url)
		? CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL)
		: NULL;

	if (dest) {
		CGImageDestinationAddImage(dest, image, NULL);
		ok = CGImageDestinationFinalize(dest);
		CFRelease(dest);
	}
	if (url) CFRelease(url);
	if (image) CGImageRelease(image);
	if (provider) CGDataProviderRelease(provider);
	if (data) CFRelease(data);
	CGColorSpaceRelease(space);
	return ok;
}

int eb_render(const char *path, int page, const char *png, int width,
              int tallest, int *height, char *message, int message_cap)
{
	FPDF_DOCUMENT doc;
	int ok = 0;

	*height = 0;
	pthread_mutex_lock(&lock);
	doc = eb_open_locked(path, message, message_cap);
	if (doc) {
		if (page < 1 || page > FPDF_GetPageCount(doc)) {
			put_message(message, message_cap, "there is no such page");
		} else {
			FPDF_PAGE pg = FPDF_LoadPage(doc, page - 1);
			float pw = pg ? FPDF_GetPageWidthF(pg) : 0.0f;
			float ph = pg ? FPDF_GetPageHeightF(pg) : 0.0f;
			if (!pg) {
				put_message(message, message_cap, "the page cannot be read");
			} else if (pw <= 0.0f || ph <= 0.0f) {
				put_message(message, message_cap, "the page is empty");
			} else {
				float scale = (float) width / pw;
				int w, h;
				FPDF_BITMAP bitmap;
				if (ph * scale > (float) tallest) {
					scale = (float) tallest / ph;
				}
				w = (int) (pw * scale + 0.5f);
				h = (int) (ph * scale + 0.5f);
				if (w < 1) w = 1;
				if (h < 1) h = 1;
				bitmap = FPDFBitmap_Create(w, h, 0);
				if (!bitmap) {
					put_message(message, message_cap, "there is no memory for the page");
				} else {
					FPDFBitmap_FillRect(bitmap, 0, 0, w, h, 0xFFFFFFFF);
					FPDF_RenderPageBitmap(bitmap, pg, 0, 0, w, h, 0, FPDF_ANNOT);
					if (write_png(png, FPDFBitmap_GetBuffer(bitmap), w, h,
					              FPDFBitmap_GetStride(bitmap))) {
						*height = h;
						ok = 1;
					} else {
						put_message(message, message_cap, "the picture cannot be written");
					}
					FPDFBitmap_Destroy(bitmap);
				}
			}
			if (pg) {
				FPDF_ClosePage(pg);
			}
		}
	}
	pthread_mutex_unlock(&lock);
	return ok;
}
