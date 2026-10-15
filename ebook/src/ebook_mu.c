/* Pages of PDFs and e-books, rendered with MuPDF.
 *
 * After SDLBook's open_pdf and render_pdf_page (vendor/SDLBook/sdlbook.c,
 * GPL-3.0): open the document, load the page, scale it by a matrix and
 * draw it to a pixmap. Here the pixmap is written as a PNG file instead
 * of being copied into an SDL surface, and MuPDF's current API is used.
 *
 * Each call opens the document and drops it again: nothing is kept between
 * calls, so that any thread may call, and a reflowable book has the same
 * pages every time (see layout).
 */
#include <mupdf/fitz.h>
#include <stdio.h>
#include <string.h>

/* A reflowable book (EPUB, FB2, ...) is laid out on pages this big, in
 * points, with text this big: its page count depends on these. */
#define LAYOUT_W 540.0f
#define LAYOUT_H 720.0f
#define LAYOUT_EM 12.0f

static void put_message(char *dest, int cap, const char *text)
{
	if (cap > 0) {
		snprintf(dest, (size_t) cap, "%s", text);
	}
}

static fz_document *open_document(fz_context *ctx, const char *path)
{
	fz_document *doc = fz_open_document(ctx, path);
	if (fz_is_document_reflowable(ctx, doc)) {
		fz_layout_document(ctx, doc, LAYOUT_W, LAYOUT_H, LAYOUT_EM);
	}
	return doc;
}

static void quiet(void *user, const char *text)
{
	(void) user;
	(void) text;
}

static fz_context *new_context(char *message, int message_cap)
{
	fz_context *ctx = fz_new_context(NULL, NULL, FZ_STORE_DEFAULT);
	if (!ctx) {
		put_message(message, message_cap, "cannot start MuPDF");
		return NULL;
	}
	/* What goes wrong is said in the message, not on stderr. */
	fz_set_error_callback(ctx, quiet, NULL);
	fz_set_warning_callback(ctx, quiet, NULL);
	fz_try(ctx) {
		fz_register_document_handlers(ctx);
	}
	fz_catch(ctx) {
		put_message(message, message_cap, fz_caught_message(ctx));
		fz_drop_context(ctx);
		return NULL;
	}
	return ctx;
}

int eb_info(const char *path, int *pages, char *title, int title_cap,
            char *message, int message_cap)
{
	fz_context *ctx = new_context(message, message_cap);
	fz_document *doc = NULL;
	int ok = 0;

	if (!ctx) {
		return 0;
	}
	*pages = 0;
	if (title_cap > 0) {
		title[0] = '\0';
	}
	fz_var(doc);
	fz_try(ctx) {
		doc = open_document(ctx, path);
		if (fz_needs_password(ctx, doc)) {
			fz_throw(ctx, FZ_ERROR_GENERIC, "the document needs a password");
		}
		*pages = fz_count_pages(ctx, doc);
		if (title_cap > 0) {
			fz_lookup_metadata(ctx, doc, FZ_META_INFO_TITLE, title, title_cap);
		}
		ok = *pages > 0;
		if (!ok) {
			fz_throw(ctx, FZ_ERROR_GENERIC, "the document has no pages");
		}
	}
	fz_always(ctx) {
		fz_drop_document(ctx, doc);
	}
	fz_catch(ctx) {
		put_message(message, message_cap, fz_caught_message(ctx));
		ok = 0;
	}
	fz_drop_context(ctx);
	return ok;
}

int eb_render(const char *path, int page, const char *png, int width,
              int tallest, int *height, char *message, int message_cap)
{
	fz_context *ctx = new_context(message, message_cap);
	fz_document *doc = NULL;
	fz_page *pg = NULL;
	fz_pixmap *pix = NULL;
	int ok = 0;

	if (!ctx) {
		return 0;
	}
	*height = 0;
	fz_var(doc);
	fz_var(pg);
	fz_var(pix);
	fz_try(ctx) {
		fz_rect bounds;
		float scale;
		doc = open_document(ctx, path);
		if (page < 1 || page > fz_count_pages(ctx, doc)) {
			fz_throw(ctx, FZ_ERROR_GENERIC, "there is no such page");
		}
		pg = fz_load_page(ctx, doc, page - 1);
		bounds = fz_bound_page(ctx, pg);
		if (bounds.x1 <= bounds.x0 || bounds.y1 <= bounds.y0) {
			fz_throw(ctx, FZ_ERROR_GENERIC, "the page is empty");
		}
		scale = (float) width / (bounds.x1 - bounds.x0);
		if ((bounds.y1 - bounds.y0) * scale > (float) tallest) {
			scale = (float) tallest / (bounds.y1 - bounds.y0);
		}
		pix = fz_new_pixmap_from_page(ctx, pg, fz_scale(scale, scale),
		                              fz_device_rgb(ctx), 0);
		*height = pix->h;
		fz_save_pixmap_as_png(ctx, pix, png);
		ok = 1;
	}
	fz_always(ctx) {
		fz_drop_pixmap(ctx, pix);
		fz_drop_page(ctx, pg);
		fz_drop_document(ctx, doc);
	}
	fz_catch(ctx) {
		put_message(message, message_cap, fz_caught_message(ctx));
		ok = 0;
	}
	fz_drop_context(ctx);
	return ok;
}
