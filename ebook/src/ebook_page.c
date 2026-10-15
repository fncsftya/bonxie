/* A page of a PDF as what is drawn on it: filled shapes as triangles,
 * strokes as lines, text as characters in fonts CoreText has, pictures as
 * pixels, all in points from the page's top left (Pomarine.Pages), instead
 * of the page as one picture.
 *
 * PDFium is walked for the page's objects, in the order they are drawn.
 * A page that has what this cannot draw as it is (rotated, shaded) is said
 * not to be built, and drawn as a picture instead (ebook_pdf.c).
 *
 * The structures are those of Pomarine.Pages, which the page is copied
 * into: the same layout.
 */
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>
#include <fpdfview.h>
#include <fpdf_edit.h>
#include <fpdf_text.h>
#include <fpdf_transformpage.h>
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <fpdf_edit.h>

/* ---- the layout of Pomarine.Pages ---- */

typedef struct { uint8_t r, g, b, a; } pg_rgba;
typedef struct { float x, y; } pg_point;
typedef struct { float left, top, right, bottom; } pg_rect;
enum { KIND_FILL, KIND_STROKE, KIND_TEXT, KIND_PICTURE };
typedef struct {
	int kind;
	int clip;
	int first;
	int count;
	pg_rgba color;
	float width;
	int face;
	pg_rect box;
} pg_op;
typedef struct { uint32_t code; float x, y, size; } pg_char;
#define FACE_LENGTH 64
#define MAX_FACES 64
typedef struct { char name[FACE_LENGTH]; int last; } pg_face;
typedef struct { int width, height, first; } pg_image;

/* As Vision.Word, and the same bounds as Pomarine.Words. */
typedef struct { int line, first, last; float left, top, width, height; } pg_word;

#define MAX_IMAGES 64
#define MAX_IMAGE_SIDE 2048

/* ---- growing arrays ---- */

typedef struct { void *data; int count, cap; size_t size; } vec;

static int vec_reserve(vec *v, int more)
{
	if (v->count + more > v->cap) {
		int cap = v->cap ? v->cap : 256;
		void *grown;
		while (cap < v->count + more) cap *= 2;
		grown = realloc(v->data, (size_t) cap * v->size);
		if (!grown) return 0;
		v->data = grown;
		v->cap = cap;
	}
	return 1;
}

static void *vec_push(vec *v)
{
	if (!vec_reserve(v, 1)) return NULL;
	return (char *) v->data + (size_t) v->count++ * v->size;
}

/* ---- the builder ---- */

typedef struct { double a, b, c, d, e, f; } mat;

typedef struct eb_page {
	float width, height;
	float left, top;           /* the page's box, in PDF space: top is its upper edge */
	vec ops, points, chars, faces, clips, images, pixels;
	vec words;                 /* pg_word */
	vec letters;               /* the words' text, bytes */
	int unsupported;           /* 1 if something cannot be drawn as it is */
	const char *why;
	/* While building */
	FPDF_DOCUMENT doc;
	FPDF_PAGE page;
	FPDF_TEXTPAGE text;
	vec by_object;             /* (object, char index) of each char, sorted */
	vec embedded;              /* the fonts of the document, loaded */
	pg_rect clip_now;          /* the clip of the last op, to compare */
	int clip_index;
} eb_page;

typedef struct { void *object; int index; } owner;

static int owner_order(const void *p, const void *q)
{
	const owner *a = p, *b = q;
	if (a->object != b->object) return a->object < b->object ? -1 : 1;
	return a->index - b->index;
}

static mat mat_identity(void)
{
	mat m = {1, 0, 0, 1, 0, 0};
	return m;
}

/* m1 first, then m2. */
static mat mat_then(mat m1, mat m2)
{
	mat r;
	r.a = m1.a * m2.a + m1.b * m2.c;
	r.b = m1.a * m2.b + m1.b * m2.d;
	r.c = m1.c * m2.a + m1.d * m2.c;
	r.d = m1.c * m2.b + m1.d * m2.d;
	r.e = m1.e * m2.a + m1.f * m2.c + m2.e;
	r.f = m1.e * m2.b + m1.f * m2.d + m2.f;
	return r;
}

static void to_page(const mat *m, double x, double y, double *ox, double *oy)
{
	*ox = m->a * x + m->c * y + m->e;
	*oy = m->b * x + m->d * y + m->f;
}

/* From PDF space (y up) to the page's top left, y down. */
static pg_point device(const eb_page *pg, double x, double y)
{
	pg_point p;
	p.x = (float) (x - pg->left);
	p.y = (float) (pg->top - y);
	return p;
}

static void rect_grow(pg_rect *r, int *empty, float x, float y)
{
	if (*empty) {
		r->left = r->right = x;
		r->top = r->bottom = y;
		*empty = 0;
		return;
	}
	if (x < r->left) r->left = x;
	if (x > r->right) r->right = x;
	if (y < r->top) r->top = y;
	if (y > r->bottom) r->bottom = y;
}

/* ---- faces ---- */

static int starts_with(const char *s, const char *prefix)
{
	return strncmp(s, prefix, strlen(prefix)) == 0;
}

static int contains_nocase(const char *s, const char *what)
{
	size_t n = strlen(what);
	for (; *s; s++) {
		if (strncasecmp(s, what, n) == 0) return 1;
	}
	return 0;
}

/* Whether CoreText has a font by this name (not one it makes up). */
static int font_exists(const char *name)
{
	int found = 0;
	CFStringRef wanted = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
	CTFontRef font;
	if (!wanted) return 0;
	font = CTFontCreateWithName(wanted, 12.0, NULL);
	if (font) {
		CFStringRef ps = CTFontCopyPostScriptName(font);
		CFStringRef full = CTFontCopyFullName(font);
		if ((ps && CFStringCompare(ps, wanted, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
		    || (full && CFStringCompare(full, wanted, kCFCompareCaseInsensitive) == kCFCompareEqualTo)) {
			found = 1;
		}
		if (ps) CFRelease(ps);
		if (full) CFRelease(full);
		CFRelease(font);
	}
	CFRelease(wanted);
	return found;
}

/* The CoreText name of a font a PDF names: its own, if the system has it,
 * or one of the standard faces of its kind. */
static void resolve_face(const char *pdf_name, int flags, int weight, char *out, size_t cap)
{
	const char *name = pdf_name;
	const char *plus = strchr(pdf_name, '+');
	int bold, italic, fixed, serif;
	const char *family;
	char style[24];

	if (plus && plus - pdf_name == 6) name = plus + 1;   /* a subset's prefix */
	if (name[0] && font_exists(name)) {
		snprintf(out, cap, "%s", name);
		return;
	}
	bold = weight >= 600 || (flags & (1 << 18)) || contains_nocase(name, "bold")
	       || contains_nocase(name, "black") || contains_nocase(name, "heavy");
	italic = (flags & 64) || contains_nocase(name, "italic") || contains_nocase(name, "oblique");
	fixed = (flags & 1) || contains_nocase(name, "courier") || contains_nocase(name, "mono")
	        || contains_nocase(name, "consol");
	serif = (flags & 2) || contains_nocase(name, "times") || contains_nocase(name, "serif")
	        || contains_nocase(name, "roman") || contains_nocase(name, "georgia")
	        || contains_nocase(name, "garamond") || contains_nocase(name, "palatino")
	        || contains_nocase(name, "cambria") || starts_with(name, "CM");
	if (contains_nocase(name, "sans")) serif = 0;
	if (fixed) {
		family = "Courier";
		snprintf(style, sizeof style, "%s%s", bold ? "-Bold" : "", italic ? "Oblique" : "");
		if (bold && italic) snprintf(style, sizeof style, "-BoldOblique");
		else if (italic) snprintf(style, sizeof style, "-Oblique");
		else if (!bold) style[0] = '\0';
	} else if (serif) {
		family = "Times";
		snprintf(style, sizeof style, "%s", bold && italic ? "-BoldItalic" : bold ? "-Bold"
		         : italic ? "-Italic" : "-Roman");
	} else {
		family = "Helvetica";
		snprintf(style, sizeof style, "%s", bold && italic ? "-BoldOblique" : bold ? "-Bold"
		         : italic ? "-Oblique" : "");
	}
	snprintf(out, cap, "%s%s", family, style);
}

/* Which face of the page: made if it is not there; 0-based. */
static int face_of(eb_page *pg, const char *pdf_name, int flags, int weight)
{
	char resolved[FACE_LENGTH];
	pg_face *faces = pg->faces.data;
	pg_face *made;
	int i;

	resolve_face(pdf_name, flags, weight, resolved, sizeof resolved);
	for (i = 0; i < pg->faces.count; i++) {
		if (strcmp(faces[i].name, resolved) == 0) return i;
	}
	if (pg->faces.count >= MAX_FACES) return 0;
	made = vec_push(&pg->faces);
	if (!made) return 0;
	memset(made, 0, sizeof *made);
	snprintf(made->name, sizeof made->name, "%s", resolved);
	made->last = (int) strlen(made->name);
	return pg->faces.count - 1;
}

/* ---- clips ---- */

/* The clip an object is drawn within, as a rectangle (the bounds of its
 * clipping paths): 0 if it has none, or one as big as the page. */
static int clip_of(eb_page *pg, FPDF_PAGEOBJECT obj)
{
	FPDF_CLIPPATH clip = FPDFPageObj_GetClipPath(obj);
	pg_rect box;
	int empty = 1, paths, p, any = 0;
	pg_rect *table;
	int i;

	if (!clip) return 0;
	paths = FPDFClipPath_CountPaths(clip);
	for (p = 0; p < paths; p++) {
		int segments = FPDFClipPath_CountPathSegments(clip, p);
		pg_rect one;
		int one_empty = 1, s;
		for (s = 0; s < segments; s++) {
			FPDF_PATHSEGMENT seg = FPDFClipPath_GetPathSegment(clip, p, s);
			float x, y;
			if (seg && FPDFPathSegment_GetPoint(seg, &x, &y)) {
				pg_point d = device(pg, x, y);
				rect_grow(&one, &one_empty, d.x, d.y);
			}
		}
		if (one_empty) continue;
		any = 1;
		if (empty) {
			box = one;
			empty = 0;
		} else {
			if (one.left > box.left) box.left = one.left;
			if (one.top > box.top) box.top = one.top;
			if (one.right < box.right) box.right = one.right;
			if (one.bottom < box.bottom) box.bottom = one.bottom;
		}
	}
	if (!any) return 0;
	if (box.right < box.left) box.right = box.left;
	if (box.bottom < box.top) box.bottom = box.top;
	if (box.left <= 0.5f && box.top <= 0.5f && box.right >= pg->width - 0.5f
	    && box.bottom >= pg->height - 0.5f) {
		return 0;
	}
	table = pg->clips.data;
	for (i = 0; i < pg->clips.count; i++) {
		if (table[i].left == box.left && table[i].top == box.top
		    && table[i].right == box.right && table[i].bottom == box.bottom) {
			return i + 1;
		}
	}
	{
		pg_rect *made = vec_push(&pg->clips);
		if (!made) return 0;
		*made = box;
	}
	return pg->clips.count;
}

/* ---- shapes ---- */

typedef struct { double x0, y0, x1, y1; int dir; } edge;

static double edge_x(const edge *e, double y)
{
	return e->x0 + (e->x1 - e->x0) * (y - e->y0) / (e->y1 - e->y0);
}

static int edge_by_top(const void *p, const void *q)
{
	const edge *a = p, *b = q;
	return a->y0 < b->y0 ? -1 : a->y0 > b->y0;
}

static int double_order(const void *p, const void *q)
{
	double a = *(const double *) p, b = *(const double *) q;
	return a < b ? -1 : a > b;
}

#define MAX_TRIANGLES_PER_SHAPE 400000
#define EDGE_LIMIT 3000
#define CROSSING_LIMIT 300

typedef struct { double x; int dir; const edge *e; } crossing;

static int crossing_order(const void *p, const void *q)
{
	const crossing *a = p, *b = q;
	return a->x < b->x ? -1 : a->x > b->x;
}

static void push_triangle(vec *points, double ax, double ay, double bx, double by,
                          double cx, double cy)
{
	pg_point *t = vec_push(points);
	if (t) { t->x = (float) ax; t->y = (float) ay; }
	t = vec_push(points);
	if (t) { t->x = (float) bx; t->y = (float) by; }
	t = vec_push(points);
	if (t) { t->x = (float) cx; t->y = (float) cy; }
}

/* Fill the closed polygons (all of a shape's subpaths) as triangles: the
 * plane is cut into bands where no edge starts, ends or crosses, and the
 * inside of each, by the rule, is trapezoids. Returns the triangles made. */
static int tessellate(vec *points, const edge *edges, int n_edges, int winding)
{
	double *ys;
	int n_ys = 0, i, j, slab, made = 0;
	edge *sorted;
	int *active, n_active = 0, next = 0;
	crossing *cross;

	if (n_edges == 0) return 0;
	ys = malloc(sizeof(double) * ((size_t) 2 * n_edges + (size_t) n_edges * n_edges / 2 + 2));
	sorted = malloc(sizeof(edge) * (size_t) n_edges);
	active = malloc(sizeof(int) * (size_t) n_edges);
	cross = malloc(sizeof(crossing) * (size_t) n_edges);
	if (!ys || !sorted || !active || !cross) {
		free(ys); free(sorted); free(active); free(cross);
		return 0;
	}
	memcpy(sorted, edges, sizeof(edge) * (size_t) n_edges);
	qsort(sorted, (size_t) n_edges, sizeof(edge), edge_by_top);
	for (i = 0; i < n_edges; i++) {
		ys[n_ys++] = sorted[i].y0;
		ys[n_ys++] = sorted[i].y1;
	}
	if (n_edges <= CROSSING_LIMIT) {
		/* Where edges cross each other, the order of them changes. */
		for (i = 0; i < n_edges; i++) {
			for (j = i + 1; j < n_edges; j++) {
				const edge *a = &sorted[i], *b = &sorted[j];
				double lo = a->y0 > b->y0 ? a->y0 : b->y0;
				double hi = a->y1 < b->y1 ? a->y1 : b->y1;
				double da, db, t;
				if (hi <= lo) continue;
				da = edge_x(a, lo) - edge_x(b, lo);
				db = edge_x(a, hi) - edge_x(b, hi);
				if ((da < 0 && db > 0) || (da > 0 && db < 0)) {
					t = da / (da - db);
					ys[n_ys++] = lo + (hi - lo) * t;
				}
			}
		}
	}
	qsort(ys, (size_t) n_ys, sizeof(double), double_order);
	{
		/* Distinct. */
		int k = 0;
		for (i = 0; i < n_ys; i++) {
			if (k == 0 || ys[i] - ys[k - 1] > 1e-4) ys[k++] = ys[i];
		}
		n_ys = k;
	}
	for (slab = 0; slab + 1 < n_ys && made < MAX_TRIANGLES_PER_SHAPE; slab++) {
		double ya = ys[slab], yb = ys[slab + 1], ym = (ya + yb) / 2.0;
		int k, in = 0, w = 0, left_at = 0;
		int n_cross = 0;
		while (next < n_edges && sorted[next].y0 <= ya + 1e-6) {
			active[n_active++] = next++;
		}
		k = 0;
		for (i = 0; i < n_active; i++) {
			if (sorted[active[i]].y1 > ya + 1e-6) active[k++] = active[i];
		}
		n_active = k;
		for (i = 0; i < n_active; i++) {
			const edge *e = &sorted[active[i]];
			if (e->y1 >= yb - 1e-6) {
				cross[n_cross].x = edge_x(e, ym);
				cross[n_cross].dir = e->dir;
				cross[n_cross].e = e;
				n_cross++;
			}
		}
		qsort(cross, (size_t) n_cross, sizeof(crossing), crossing_order);
		for (i = 0; i < n_cross; i++) {
			int inside;
			w += cross[i].dir;
			inside = winding ? (w != 0) : (w & 1);
			if (inside && !in) {
				left_at = i;
				in = 1;
			} else if (!inside && in) {
				const edge *el = cross[left_at].e, *er = cross[i].e;
				double la = edge_x(el, ya), lb = edge_x(el, yb);
				double ra = edge_x(er, ya), rb = edge_x(er, yb);
				push_triangle(points, la, ya, ra, ya, lb, yb);
				push_triangle(points, ra, ya, rb, yb, lb, yb);
				made += 2;
				in = 0;
			}
		}
	}
	free(ys); free(sorted); free(active); free(cross);
	return made;
}

/* A subpath as it is flattened: points in the page's space. */
typedef struct { vec pts; vec starts; vec closed; } flat;

static void flat_free(flat *f)
{
	free(f->pts.data); free(f->starts.data); free(f->closed.data);
}

static int flat_point(flat *f, pg_point p)
{
	pg_point *q = vec_push(&f->pts);
	if (!q) return 0;
	*q = p;
	return 1;
}

static void flat_begin(flat *f)
{
	int *s = vec_push(&f->starts);
	int *c = vec_push(&f->closed);
	if (s) *s = f->pts.count;
	if (c) *c = 0;
}

static void cubic(eb_page *pg, flat *f, const mat *m, double x0, double y0,
                  double x1, double y1, double x2, double y2, double x3, double y3)
{
	double ax, ay, bx, by, cx, cy, dx, dy;
	double length;
	int n, i;
	to_page(m, x0, y0, &ax, &ay);
	to_page(m, x1, y1, &bx, &by);
	to_page(m, x2, y2, &cx, &cy);
	to_page(m, x3, y3, &dx, &dy);
	length = hypot(bx - ax, by - ay) + hypot(cx - bx, cy - by) + hypot(dx - cx, dy - cy);
	n = (int) (length / 1.5);
	if (n < 6) n = 6;
	if (n > 64) n = 64;
	for (i = 1; i <= n; i++) {
		double t = (double) i / n, u = 1.0 - t;
		double x = u * u * u * ax + 3 * u * u * t * bx + 3 * u * t * t * cx + t * t * t * dx;
		double y = u * u * u * ay + 3 * u * u * t * by + 3 * u * t * t * cy + t * t * t * dy;
		flat_point(f, device(pg, x, y));
	}
}

/* The path object's subpaths, flattened, into page points. */
static void flatten_path(eb_page *pg, FPDF_PAGEOBJECT path, const mat *m, flat *f)
{
	int count = FPDFPath_CountSegments(path), i;
	double cur_x = 0, cur_y = 0;
	int open = 0;

	for (i = 0; i < count; i++) {
		FPDF_PATHSEGMENT seg = FPDFPath_GetPathSegment(path, i);
		float x, y;
		int type;
		if (!seg || !FPDFPathSegment_GetPoint(seg, &x, &y)) continue;
		type = FPDFPathSegment_GetType(seg);
		if (type == FPDF_SEGMENT_MOVETO) {
			double px, py;
			flat_begin(f);
			to_page(m, x, y, &px, &py);
			flat_point(f, device(pg, px, py));
			cur_x = x; cur_y = y;
			open = 1;
		} else if (type == FPDF_SEGMENT_LINETO) {
			double px, py;
			if (!open) { flat_begin(f); open = 1; }
			to_page(m, x, y, &px, &py);
			flat_point(f, device(pg, px, py));
			cur_x = x; cur_y = y;
		} else if (type == FPDF_SEGMENT_BEZIERTO && i + 2 < count) {
			FPDF_PATHSEGMENT s2 = FPDFPath_GetPathSegment(path, i + 1);
			FPDF_PATHSEGMENT s3 = FPDFPath_GetPathSegment(path, i + 2);
			float x2, y2, x3, y3;
			if (s2 && s3 && FPDFPathSegment_GetPoint(s2, &x2, &y2)
			    && FPDFPathSegment_GetPoint(s3, &x3, &y3)) {
				if (!open) { flat_begin(f); open = 1; }
				cubic(pg, f, m, cur_x, cur_y, x, y, x2, y2, x3, y3);
				cur_x = x3; cur_y = y3;
				seg = s3;
			}
			i += 2;
		}
		if (seg && FPDFPathSegment_GetClose(seg) && f->closed.count > 0) {
			((int *) f->closed.data)[f->closed.count - 1] = 1;
			open = 0;
		}
	}
}

static pg_op *new_op(eb_page *pg, int kind, int clip, pg_rgba color)
{
	pg_op *op = vec_push(&pg->ops);
	if (!op) return NULL;
	memset(op, 0, sizeof *op);
	op->kind = kind;
	op->clip = clip;
	op->color = color;
	return op;
}

static pg_rgba color_of(unsigned r, unsigned g, unsigned b, unsigned a)
{
	pg_rgba c;
	c.r = (uint8_t) r; c.g = (uint8_t) g; c.b = (uint8_t) b; c.a = (uint8_t) a;
	return c;
}

#define MAX_DASHES 16

typedef struct {
	float lengths[MAX_DASHES];
	int count;           /* 0: solid */
	int at;              /* which length is being walked */
	double left;         /* how much of it is left */
	int on;
} dasher;

static void dasher_start(dasher *d, FPDF_PAGEOBJECT obj, double scale)
{
	float raw[MAX_DASHES];
	int n = FPDFPageObj_GetDashCount(obj), i;
	float phase = 0;
	double total = 0, skip;

	d->count = 0;
	if (n <= 0 || n > MAX_DASHES || !FPDFPageObj_GetDashArray(obj, raw, (size_t) n)) return;
	for (i = 0; i < n; i++) {
		d->lengths[i] = (float) (raw[i] * scale);
		total += d->lengths[i];
	}
	if (total <= 0.01) return;
	if (n & 1) {
		/* An odd array repeats, on then off. */
		if (2 * n <= MAX_DASHES) {
			for (i = 0; i < n; i++) d->lengths[n + i] = d->lengths[i];
			n *= 2;
			total *= 2;
		} else {
			return;
		}
	}
	d->count = n;
	FPDFPageObj_GetDashPhase(obj, &phase);
	skip = fmod(phase * scale, total);
	d->at = 0;
	d->on = 1;
	d->left = d->lengths[0];
	while (skip > 0) {
		if (skip < d->left) {
			d->left -= skip;
			break;
		}
		skip -= d->left;
		d->at = (d->at + 1) % d->count;
		d->on = !d->on;
		d->left = d->lengths[d->at];
	}
}

/* The line from p to q as the dashes it is, or all of it if solid. */
static int emit_line(vec *points, dasher *d, pg_point p, pg_point q)
{
	int lines = 0;
	double length = hypot(q.x - p.x, q.y - p.y), done = 0;
	pg_point *out;

	if (d->count == 0) {
		out = vec_push(points); if (out) *out = p;
		out = vec_push(points); if (out) *out = q;
		return 1;
	}
	while (done < length) {
		double take = d->left < length - done ? d->left : length - done;
		if (d->on && take > 0) {
			pg_point a, b;
			a.x = (float) (p.x + (q.x - p.x) * done / length);
			a.y = (float) (p.y + (q.y - p.y) * done / length);
			b.x = (float) (p.x + (q.x - p.x) * (done + take) / length);
			b.y = (float) (p.y + (q.y - p.y) * (done + take) / length);
			out = vec_push(points); if (out) *out = a;
			out = vec_push(points); if (out) *out = b;
			lines++;
		}
		done += take;
		d->left -= take;
		if (d->left <= 1e-9) {
			d->at = (d->at + 1) % d->count;
			d->on = !d->on;
			d->left = d->lengths[d->at];
			if (d->left <= 0) d->left = 1e-3;
		}
	}
	return lines;
}

static void add_path(eb_page *pg, FPDF_PAGEOBJECT obj, const mat *chain)
{
	FS_MATRIX fm;
	mat m;
	int fillmode = 0;
	FPDF_BOOL stroke = 0;
	flat f;
	int clip, s;
	pg_rect box;
	int empty = 1;
	pg_point *pts;
	int *starts, *closed;

	if (!FPDFPath_GetDrawMode(obj, &fillmode, &stroke)) return;
	if (fillmode == FPDF_FILLMODE_NONE && !stroke) return;
	if (!FPDFPageObj_GetMatrix(obj, &fm)) return;
	m.a = fm.a; m.b = fm.b; m.c = fm.c; m.d = fm.d; m.e = fm.e; m.f = fm.f;
	m = mat_then(m, *chain);
	memset(&f, 0, sizeof f);
	f.pts.size = sizeof(pg_point);
	f.starts.size = sizeof(int);
	f.closed.size = sizeof(int);
	flatten_path(pg, obj, &m, &f);
	pts = f.pts.data; starts = f.starts.data; closed = f.closed.data;
	if (f.pts.count == 0) { flat_free(&f); return; }
	for (s = 0; s < f.pts.count; s++) rect_grow(&box, &empty, pts[s].x, pts[s].y);
	clip = clip_of(pg, obj);

	if (fillmode != FPDF_FILLMODE_NONE) {
		unsigned r, g, b, a;
		if (FPDFPageObj_GetFillColor(obj, &r, &g, &b, &a) && a > 0) {
			vec edges;
			edge *e;
			int sub, made;
			int first = pg->points.count;
			memset(&edges, 0, sizeof edges);
			edges.size = sizeof(edge);
			for (sub = 0; sub < f.starts.count; sub++) {
				int from = starts[sub];
				int to = sub + 1 < f.starts.count ? starts[sub + 1] : f.pts.count;
				int k;
				for (k = from; k < to; k++) {
					pg_point p = pts[k];
					pg_point q = (k + 1 < to) ? pts[k + 1] : pts[from];
					if (p.y == q.y) continue;
					e = vec_push(&edges);
					if (!e) break;
					if (p.y < q.y) {
						e->x0 = p.x; e->y0 = p.y; e->x1 = q.x; e->y1 = q.y; e->dir = 1;
					} else {
						e->x0 = q.x; e->y0 = q.y; e->x1 = p.x; e->y1 = p.y; e->dir = -1;
					}
				}
			}
			made = tessellate(&pg->points, edges.data, edges.count,
			                  fillmode == FPDF_FILLMODE_WINDING);
			if (made > 0) {
				pg_op *op = new_op(pg, KIND_FILL, clip, color_of(r, g, b, a));
				if (op) {
					op->first = first + 1;
					op->count = made;
					op->box = box;
				}
				/* The edges, drawn smoothed over the fill's own, which
				 * are not (a width of -1). Not of a huge shape. */
				if (edges.count <= EDGE_LIMIT) {
					int outline = pg->points.count, lines = 0;
					for (sub = 0; sub < f.starts.count; sub++) {
						int from = starts[sub];
						int to = sub + 1 < f.starts.count ? starts[sub + 1] : f.pts.count;
						int k;
						for (k = from; k < to; k++) {
							pg_point *out;
							if (pts[k].y == ((k + 1 < to) ? pts[k + 1] : pts[from]).y
							    && pts[k].x == ((k + 1 < to) ? pts[k + 1] : pts[from]).x) {
								continue;
							}
							out = vec_push(&pg->points); if (out) *out = pts[k];
							out = vec_push(&pg->points);
							if (out) *out = (k + 1 < to) ? pts[k + 1] : pts[from];
							lines++;
						}
					}
					op = lines > 0 ? new_op(pg, KIND_STROKE, clip, color_of(r, g, b, a)) : NULL;
					if (op) {
						op->first = outline + 1;
						op->count = lines;
						op->width = -1.0f;
						op->box = box;
					}
				}
			}
			free(edges.data);
		}
	}
	if (stroke) {
		unsigned r, g, b, a;
		float width = 1.0f;
		if (FPDFPageObj_GetStrokeColor(obj, &r, &g, &b, &a) && a > 0) {
			double scale = sqrt(fabs(m.a * m.d - m.b * m.c));
			int first = pg->points.count, lines = 0, sub;
			FPDFPageObj_GetStrokeWidth(obj, &width);
			/* The width is in the path's own space. */
			{
				FS_MATRIX own;
				double os = 1.0;
				if (FPDFPageObj_GetMatrix(obj, &own)) {
					os = sqrt(fabs((double) own.a * own.d - (double) own.b * own.c));
				}
				if (os > 0.0) scale = scale / os;
			}
			dasher dash;
			dasher_start(&dash, obj, scale);
			for (sub = 0; sub < f.starts.count; sub++) {
				int from = starts[sub];
				int to = sub + 1 < f.starts.count ? starts[sub + 1] : f.pts.count;
				int k;
				int stop = closed[sub] ? to : to - 1;
				for (k = from; k < stop; k++) {
					pg_point p = pts[k];
					pg_point q = (k + 1 < to) ? pts[k + 1] : pts[from];
					lines += emit_line(&pg->points, &dash, p, q);
				}
			}
			if (lines > 0) {
				pg_op *op = new_op(pg, KIND_STROKE, clip, color_of(r, g, b, a));
				if (op) {
					op->first = first + 1;
					op->count = lines;
					op->width = (float) (width * scale);
					op->box = box;
				}
			}
		}
	}
	flat_free(&f);
}

/* ---- embedded fonts ---- */

/* A font a PDF carries (TrueType or OpenType) is written to a file, once,
 * and made known to CoreText for this process; the PDF's text is then set
 * in it, a character at a time where it has the character. */
typedef struct {
	void *font;                 /* the PDF's font */
	char name[FACE_LENGTH];     /* CoreText's name for it, "" if it cannot be used */
	CTFontRef ct;
} embedded;

typedef struct { uint64_t hash; char name[FACE_LENGTH]; } registered;
static registered known[256];
static int known_count;

static uint64_t fnv(const uint8_t *data, size_t n)
{
	uint64_t h = 1469598103934665603ULL;
	size_t i;
	for (i = 0; i < n; i++) {
		h ^= data[i];
		h *= 1099511628211ULL;
	}
	return h;
}

static void embedded_load(embedded *e, FPDF_FONT font)
{
	size_t length = 0;
	uint8_t *data;
	const char *ext;
	char path[1024];
	uint64_t hash;
	CFURLRef url;
	CFArrayRef descriptors;

	e->name[0] = '\0';
	e->ct = NULL;
	if (!FPDFFont_GetIsEmbedded(font)) return;
	if (!FPDFFont_GetFontData(font, NULL, 0, &length) || length < 16 || length > 64u * 1024 * 1024) return;
	data = malloc(length);
	if (!data) return;
	if (!FPDFFont_GetFontData(font, data, length, &length)) { free(data); return; }
	if (data[0] == 'O' && data[1] == 'T' && data[2] == 'T' && data[3] == 'O') ext = "otf";
	else if ((data[0] == 0 && data[1] == 1 && data[2] == 0 && data[3] == 0)
	         || memcmp(data, "true", 4) == 0 || memcmp(data, "ttcf", 4) == 0) ext = "ttf";
	else { free(data); return; }   /* Type 1 and the like: not read by CoreText */
	hash = fnv(data, length);
	{
		const char *tmp = getenv("TMPDIR");
		char dir[900];
		FILE *f;
		snprintf(dir, sizeof dir, "%s%sbonxie-fonts", tmp ? tmp : "/tmp",
		         (tmp && tmp[strlen(tmp) - 1] == '/') ? "" : "/");
		mkdir(dir, 0700);
		snprintf(path, sizeof path, "%s/%016llx.%s", dir, (unsigned long long) hash, ext);
		f = fopen(path, "rb");
		if (f) {
			fclose(f);
		} else {
			f = fopen(path, "wb");
			if (!f) { free(data); return; }
			fwrite(data, 1, length, f);
			fclose(f);
		}
	}
	free(data);
	url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *) path, (CFIndex) strlen(path), false);
	if (!url) return;
	CTFontManagerRegisterFontsForURL(url, kCTFontManagerScopeProcess, NULL);
	descriptors = CTFontManagerCreateFontDescriptorsFromURL(url);
	if (descriptors && CFArrayGetCount(descriptors) > 0) {
		CTFontDescriptorRef d = CFArrayGetValueAtIndex(descriptors, 0);
		CFStringRef name = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute);
		char text[FACE_LENGTH];
		if (name && CFStringGetCString(name, text, sizeof text, kCFStringEncodingUTF8)) {
			int i, clash = 0, seen = 0;
			for (i = 0; i < known_count; i++) {
				if (strcmp(known[i].name, text) == 0) {
					seen = 1;
					/* The name is another font's: CoreText would give that. */
					if (known[i].hash != hash) clash = 1;
				}
			}
			if (!seen && known_count < 256) {
				known[known_count].hash = hash;
				snprintf(known[known_count].name, FACE_LENGTH, "%s", text);
				known_count++;
			}
			if (!clash) {
				e->ct = CTFontCreateWithFontDescriptor(d, 12.0, NULL);
				if (e->ct) snprintf(e->name, FACE_LENGTH, "%s", text);
			}
		}
		if (name) CFRelease(name);
	}
	if (descriptors) CFRelease(descriptors);
	CFRelease(url);
}

static embedded *embedded_for(eb_page *pg, FPDF_FONT font)
{
	embedded *list = pg->embedded.data;
	embedded *made;
	int i;
	for (i = 0; i < pg->embedded.count; i++) {
		if (list[i].font == (void *) font) return &list[i];
	}
	made = vec_push(&pg->embedded);
	if (!made) return NULL;
	made->font = font;
	embedded_load(made, font);
	return made;
}

/* Whether the font has the character (in the basic plane). */
static int embedded_has(const embedded *e, uint32_t code)
{
	UniChar ch = (UniChar) code;
	CGGlyph glyph = 0;
	if (!e || !e->ct || code > 0xFFFF) return 0;
	return CTFontGetGlyphsForCharacters(e->ct, &ch, &glyph, 1) && glyph != 0;
}

/* The face of the page for a name CoreText has: made if it is not there. */
static int face_named(eb_page *pg, const char *name)
{
	pg_face *faces = pg->faces.data;
	pg_face *made;
	int i;
	for (i = 0; i < pg->faces.count; i++) {
		if (strcmp(faces[i].name, name) == 0) return i;
	}
	if (pg->faces.count >= MAX_FACES) return 0;
	made = vec_push(&pg->faces);
	if (!made) return 0;
	memset(made, 0, sizeof *made);
	snprintf(made->name, sizeof made->name, "%s", name);
	made->last = (int) strlen(made->name);
	return pg->faces.count - 1;
}

/* ---- text ---- */

/* The characters from first_char on, set in the face, as an operation. */
static void text_run(eb_page *pg, int first_char, int face, int clip, pg_rgba color,
                     const pg_rect *box)
{
	pg_op *op;
	if (pg->chars.count <= first_char) return;
	op = new_op(pg, KIND_TEXT, clip, color);
	if (op) {
		op->first = first_char + 1;
		op->count = pg->chars.count - first_char;
		op->face = face + 1;
		op->box = *box;
	}
}

static void add_text(eb_page *pg, FPDF_PAGEOBJECT obj)
{
	owner *by = pg->by_object.data;
	int lo = 0, hi = pg->by_object.count, i;
	int mode;
	int run_start = pg->chars.count, run_face = -1;
	pg_rect box;
	int empty = 1;
	char name[128];
	int flags = 0, weight = 400, system_face = -1;
	embedded *own = NULL;
	int own_face = -1;
	unsigned r = 0, g = 0, b = 0, a = 255;
	pg_rgba color;
	int clip, started = 0;

	memset(&box, 0, sizeof box);
	while (lo < hi) {
		int mid = (lo + hi) / 2;
		if (by[mid].object < (void *) obj) lo = mid + 1; else hi = mid;
	}
	mode = FPDFTextObj_GetTextRenderMode(obj);
	if (mode == FPDF_TEXTRENDERMODE_INVISIBLE) return;
	clip = clip_of(pg, obj);
	for (i = lo; i < pg->by_object.count && by[i].object == (void *) obj; i++) {
		int at = by[i].index;
		unsigned code = FPDFText_GetUnicode(pg->text, at);
		double x, y, size;
		pg_char *c;
		pg_point origin;
		int face;
		if (code <= 32 || FPDFText_IsGenerated(pg->text, at)) continue;
		if (!started) {
			unsigned long got = FPDFText_GetFontInfo(pg->text, at, name, sizeof name, &flags);
			FPDF_FONT font = FPDFTextObj_GetFont(obj);
			if (got == 0) name[0] = '\0';
			weight = FPDFText_GetFontWeight(pg->text, at);
			system_face = face_of(pg, name, flags, weight);
			own = font ? embedded_for(pg, font) : NULL;
			if (own && own->name[0]) own_face = face_named(pg, own->name);
			if (!FPDFText_GetFillColor(pg->text, at, &r, &g, &b, &a)) {
				r = g = b = 0; a = 255;
			}
			if (mode == FPDF_TEXTRENDERMODE_STROKE) {
				FPDFText_GetStrokeColor(pg->text, at, &r, &g, &b, &a);
			}
			color = color_of(r, g, b, a ? a : 255);
			started = 1;
		}
		if (!FPDFText_GetCharOrigin(pg->text, at, &x, &y)) continue;
		{
			float angle = FPDFText_GetCharAngle(pg->text, at);
			if (angle > 0.01f && angle < 6.27f) {
				pg->unsupported = 1;
				pg->why = "the page has rotated text";
			}
		}
		size = FPDFText_GetFontSize(pg->text, at);
		{
			/* The size is of the font; the text matrix scales it. */
			FS_MATRIX cm;
			if (FPDFText_GetMatrix(pg->text, at, &cm)) {
				double scale = sqrt(fabs((double) cm.a * cm.d - (double) cm.b * cm.c));
				if (scale > 0.0) size *= scale;
			}
		}
		if (size <= 0) continue;
		/* The PDF's own font where it has the character, else one like it. */
		face = (own_face >= 0 && embedded_has(own, code)) ? own_face : system_face;
		if (run_face >= 0 && face != run_face) {
			text_run(pg, run_start, run_face, clip, color, &box);
			run_start = pg->chars.count;
			empty = 1;
		}
		run_face = face;
		c = vec_push(&pg->chars);
		if (!c) break;
		origin = device(pg, x, y);
		c->code = code;
		c->x = origin.x;
		c->y = origin.y;
		c->size = (float) size;
		rect_grow(&box, &empty, origin.x, origin.y - (float) size);
		rect_grow(&box, &empty, origin.x + (float) size, origin.y + (float) size * 0.3f);
	}
	if (started && run_face >= 0) text_run(pg, run_start, run_face, clip, color, &box);
}

/* ---- pictures ---- */

static void add_image(eb_page *pg, FPDF_PAGEOBJECT obj, const mat *chain)
{
	FS_MATRIX fm;
	mat m;
	FPDF_BITMAP bitmap;
	int w, h, sw, sh, step_x, step_y, x, y, clip;
	const uint8_t *src;
	int stride, format;
	pg_image *image;
	uint8_t *dest;
	double cx[4], cy[4];
	pg_rect box;
	int empty = 1, k;
	pg_op *op;

	if (pg->images.count >= MAX_IMAGES) return;
	if (!FPDFPageObj_GetMatrix(obj, &fm)) return;
	m.a = fm.a; m.b = fm.b; m.c = fm.c; m.d = fm.d; m.e = fm.e; m.f = fm.f;
	m = mat_then(m, *chain);
	to_page(&m, 0, 0, &cx[0], &cy[0]);
	to_page(&m, 1, 0, &cx[1], &cy[1]);
	to_page(&m, 0, 1, &cx[2], &cy[2]);
	to_page(&m, 1, 1, &cx[3], &cy[3]);
	for (k = 0; k < 4; k++) {
		pg_point d = device(pg, cx[k], cy[k]);
		rect_grow(&box, &empty, d.x, d.y);
	}
	bitmap = FPDFImageObj_GetRenderedBitmap(pg->doc, pg->page, obj);
	if (!bitmap) return;
	w = FPDFBitmap_GetWidth(bitmap);
	h = FPDFBitmap_GetHeight(bitmap);
	format = FPDFBitmap_GetFormat(bitmap);
	stride = FPDFBitmap_GetStride(bitmap);
	src = FPDFBitmap_GetBuffer(bitmap);
	if (w <= 0 || h <= 0 || !src || (format != FPDFBitmap_BGRA && format != FPDFBitmap_BGRx)) {
		FPDFBitmap_Destroy(bitmap);
		return;
	}
	/* Smaller, if it is huge: every n-th pixel. */
	step_x = (w + MAX_IMAGE_SIDE - 1) / MAX_IMAGE_SIDE;
	step_y = (h + MAX_IMAGE_SIDE - 1) / MAX_IMAGE_SIDE;
	sw = w / step_x;
	sh = h / step_y;
	if (sw < 1 || sh < 1) { FPDFBitmap_Destroy(bitmap); return; }
	image = vec_push(&pg->images);
	if (!image) { FPDFBitmap_Destroy(bitmap); return; }
	image->width = sw;
	image->height = sh;
	image->first = pg->pixels.count + 1;
	if (!vec_reserve(&pg->pixels, 4 * sw * sh)) {
		pg->images.count--;
		FPDFBitmap_Destroy(bitmap);
		return;
	}
	dest = (uint8_t *) pg->pixels.data + pg->pixels.count;
	for (y = 0; y < sh; y++) {
		const uint8_t *row = src + (size_t) (y * step_y) * stride;
		for (x = 0; x < sw; x++) {
			const uint8_t *p = row + (size_t) (x * step_x) * 4;
			unsigned a = format == FPDFBitmap_BGRA ? p[3] : 255;
			/* Straight colour to premultiplied (PDFium's is straight). */
			*dest++ = (uint8_t) ((p[2] * a + 127) / 255);
			*dest++ = (uint8_t) ((p[1] * a + 127) / 255);
			*dest++ = (uint8_t) ((p[0] * a + 127) / 255);
			*dest++ = (uint8_t) a;
		}
	}
	pg->pixels.count += 4 * sw * sh;
	FPDFBitmap_Destroy(bitmap);
	clip = clip_of(pg, obj);
	op = new_op(pg, KIND_PICTURE, clip, color_of(255, 255, 255, 255));
	if (op) {
		op->first = pg->images.count;
		op->count = 1;
		op->box = box;
	}
}

/* ---- the objects, in order ---- */

static void add_objects(eb_page *pg, FPDF_PAGEOBJECT form, int count, const mat *chain, int depth)
{
	int i;
	for (i = 0; i < count; i++) {
		FPDF_PAGEOBJECT obj = form ? FPDFFormObj_GetObject(form, (unsigned long) i)
		                           : FPDFPage_GetObject(pg->page, i);
		if (!obj) continue;
		switch (FPDFPageObj_GetType(obj)) {
		case FPDF_PAGEOBJ_PATH:
			add_path(pg, obj, chain);
			break;
		case FPDF_PAGEOBJ_TEXT:
			add_text(pg, obj);
			break;
		case FPDF_PAGEOBJ_IMAGE:
			add_image(pg, obj, chain);
			break;
		case FPDF_PAGEOBJ_FORM:
			if (depth < 8) {
				FS_MATRIX fm;
				mat inner = *chain;
				if (FPDFPageObj_GetMatrix(obj, &fm)) {
					mat own;
					own.a = fm.a; own.b = fm.b; own.c = fm.c;
					own.d = fm.d; own.e = fm.e; own.f = fm.f;
					inner = mat_then(own, *chain);
				}
				add_objects(pg, obj, FPDFFormObj_CountObjects(obj), &inner, depth + 1);
			}
			break;
		case FPDF_PAGEOBJ_SHADING:
			pg->unsupported = 1;
			pg->why = "the page has shading";
			break;
		default:
			break;
		}
	}
}

/* ---- words ---- */

static int utf8(uint32_t c, char *out)
{
	if (c < 0x80) { out[0] = (char) c; return 1; }
	if (c < 0x800) {
		out[0] = (char) (0xC0 | (c >> 6)); out[1] = (char) (0x80 | (c & 0x3F)); return 2;
	}
	if (c < 0x10000) {
		out[0] = (char) (0xE0 | (c >> 12)); out[1] = (char) (0x80 | ((c >> 6) & 0x3F));
		out[2] = (char) (0x80 | (c & 0x3F)); return 3;
	}
	out[0] = (char) (0xF0 | (c >> 18)); out[1] = (char) (0x80 | ((c >> 12) & 0x3F));
	out[2] = (char) (0x80 | ((c >> 6) & 0x3F)); out[3] = (char) (0x80 | (c & 0x3F));
	return 4;
}

/* The page's text in reading order as words, each with its box as a
 * fraction of the page, from the text page (not from the characters
 * drawn: invisible text, as of a scanned page that has been read, is
 * in them). */
static void end_word(eb_page *pg, pg_word *cur, int line, const pg_rect *box)
{
	pg_word *w = vec_push(&pg->words);
	if (!w) return;
	*w = *cur;
	w->line = line;
	w->last = pg->letters.count;
	w->left = box->left / pg->width;
	w->top = box->top / pg->height;
	w->width = (box->right - box->left) / pg->width;
	w->height = (box->bottom - box->top) / pg->height;
}

/* A drop cap is often drawn last (or first) in the content stream, so the
 * text page has it far from its place in the reading order. Move any
 * one-letter word much taller than the first word beside it to just
 * before that word, on its line. */
static void seat_drop_caps(eb_page *pg)
{
	pg_word *w = pg->words.data;
	int n = pg->words.count, c;

	for (c = 0; c < n; c++) {
		const pg_word cap = w[c];
		int target = -1, i, cap_line;

		if (cap.last - cap.first != 0) continue;
		for (i = 0; i < n; i++) {
			float mid = w[i].top + w[i].height / 2;
			if (i == c || w[i].left < cap.left + cap.width / 2 || w[i].height * 1.8f > cap.height) continue;
			if (mid < cap.top || mid > cap.top + cap.height) continue;
			if (target < 0 || w[i].top < w[target].top - 1e-4f
			    || (fabsf(w[i].top - w[target].top) <= 1e-4f && w[i].left < w[target].left)) {
				target = i;
			}
		}
		if (target < 0) continue;
		cap_line = w[target].line;
		if (target > c + 1) {
			memmove(&w[c], &w[c + 1], sizeof(pg_word) * (size_t) (target - c - 1));
			w[target - 1] = cap;
			w[target - 1].line = cap_line;
		} else if (target < c) {
			memmove(&w[target + 1], &w[target], sizeof(pg_word) * (size_t) (c - target));
			w[target] = cap;
			w[target].line = cap_line;
		} else {
			w[c].line = cap_line;
		}
	}
}

static void collect_words(eb_page *pg)
{
	int n = FPDFText_CountChars(pg->text), i;
	int line = 1, in_word = 0, have_last = 0, broke = 0;
	pg_word cur;
	float last_base = 0, last_height = 1;
	pg_rect box;
	int empty = 1;

	memset(&cur, 0, sizeof cur);
	memset(&box, 0, sizeof box);
	for (i = 0; i < n; i++) {
		unsigned code = FPDFText_GetUnicode(pg->text, i);
		FS_RECTF loose;
		double ox, oy;
		pg_point lt, rb;
		float base;
		int jumped;
		char enc[4];
		int len, k;

		if (code <= 32 || code == 0xA0) {
			if (in_word) {
				end_word(pg, &cur, line, &box);
				in_word = 0;
			}
			if (code == 10 || code == 13) broke = 1;
			continue;
		}
		if (!FPDFText_GetLooseCharBox(pg->text, i, &loose)
		    || !FPDFText_GetCharOrigin(pg->text, i, &ox, &oy)) {
			continue;
		}
		lt = device(pg, loose.left, loose.top);
		rb = device(pg, loose.right, loose.bottom);
		base = (float) (pg->top - oy);
		jumped = have_last && fabsf(base - last_base) > 0.6f * last_height;
		if (in_word && jumped) {
			end_word(pg, &cur, line, &box);
			in_word = 0;
		}
		if (!in_word) {
			if (jumped || (broke && have_last)) line++;
			broke = 0;
			memset(&cur, 0, sizeof cur);
			cur.first = pg->letters.count + 1;
			empty = 1;
			in_word = 1;
		}
		len = utf8(code, enc);
		for (k = 0; k < len; k++) {
			char *slot = vec_push(&pg->letters);
			if (slot) *slot = enc[k];
		}
		rect_grow(&box, &empty, lt.x, lt.y);
		rect_grow(&box, &empty, rb.x, rb.y);
		last_base = base;
		last_height = rb.y - lt.y > 1.0f ? rb.y - lt.y : 1.0f;
		have_last = 1;
	}
	if (in_word) end_word(pg, &cur, line, &box);
	seat_drop_caps(pg);
}

/* ---- a page as a picture ---- */

#define RASTER_WIDTH 2048
#define RASTER_TALLEST 8192

static void reset_drawing(eb_page *pg)
{
	pg->ops.count = pg->points.count = pg->chars.count = pg->faces.count = 0;
	pg->clips.count = pg->images.count = pg->pixels.count = 0;
}

/* The page drawn by PDFium into pixels, as the page's one picture. */
static int add_raster(eb_page *pg)
{
	float pw = FPDF_GetPageWidthF(pg->page), ph = FPDF_GetPageHeightF(pg->page);
	float scale;
	int w, h, x, y;
	FPDF_BITMAP bitmap;
	pg_image *image;
	pg_op *op;
	uint8_t *dest;
	const uint8_t *src;
	int stride;

	if (pw <= 0 || ph <= 0) return 0;
	scale = (float) RASTER_WIDTH / pw;
	if (ph * scale > RASTER_TALLEST) scale = (float) RASTER_TALLEST / ph;
	w = (int) (pw * scale + 0.5f);
	h = (int) (ph * scale + 0.5f);
	if (w < 1 || h < 1) return 0;
	bitmap = FPDFBitmap_Create(w, h, 0);
	if (!bitmap) return 0;
	FPDFBitmap_FillRect(bitmap, 0, 0, w, h, 0xFFFFFFFF);
	FPDF_RenderPageBitmap(bitmap, pg->page, 0, 0, w, h, 0, FPDF_ANNOT);
	image = vec_push(&pg->images);
	if (!image || !vec_reserve(&pg->pixels, 4 * w * h)) {
		FPDFBitmap_Destroy(bitmap);
		return 0;
	}
	image->width = w;
	image->height = h;
	image->first = pg->pixels.count + 1;
	dest = (uint8_t *) pg->pixels.data + pg->pixels.count;
	src = FPDFBitmap_GetBuffer(bitmap);
	stride = FPDFBitmap_GetStride(bitmap);
	for (y = 0; y < h; y++) {
		const uint8_t *row = src + (size_t) y * stride;
		for (x = 0; x < w; x++) {
			*dest++ = row[4 * x + 2];
			*dest++ = row[4 * x + 1];
			*dest++ = row[4 * x];
			*dest++ = 255;
		}
	}
	pg->pixels.count += 4 * w * h;
	FPDFBitmap_Destroy(bitmap);
	pg->width = pw;
	pg->height = ph;
	op = new_op(pg, KIND_PICTURE, 0, color_of(255, 255, 255, 255));
	if (!op) return 0;
	op->first = 1;
	op->count = 1;
	op->box.left = 0;
	op->box.top = 0;
	op->box.right = pw;
	op->box.bottom = ph;
	return 1;
}

/* ---- entry points ---- */

/* ebook_pdf.c's lock and way to open a document. */
extern void eb_lock(void);
extern void eb_unlock(void);
extern FPDF_DOCUMENT eb_open_locked(const char *path, char *message, int message_cap);

static void put_message(char *dest, int cap, const char *text)
{
	if (cap > 0) snprintf(dest, (size_t) cap, "%s", text);
}

static void init_vec(vec *v, size_t size)
{
	memset(v, 0, sizeof *v);
	v->size = size;
}

void eb_page_free(eb_page *pg)
{
	if (!pg) return;
	free(pg->ops.data); free(pg->points.data); free(pg->chars.data); free(pg->faces.data);
	free(pg->clips.data); free(pg->images.data); free(pg->pixels.data);
	free(pg->words.data); free(pg->letters.data); free(pg->by_object.data);
	if (pg->embedded.data) {
		embedded *list = pg->embedded.data;
		int i;
		for (i = 0; i < pg->embedded.count; i++) {
			if (list[i].ct) CFRelease(list[i].ct);
		}
	}
	free(pg->embedded.data);
	free(pg);
}

/* Build the page (counted from 1). NULL, and the reason, if it cannot be
 * built: the document or page cannot be read, or it has what is not drawn
 * this way (the message starts "raster:"). */
eb_page *eb_page_build(const char *path, int page_number, char *message, int message_cap)
{
	eb_page *pg = calloc(1, sizeof *pg);
	FS_RECTF box;
	mat identity = mat_identity();
	int n_chars, i;

	if (!pg) {
		put_message(message, message_cap, "there is no memory for the page");
		return NULL;
	}
	init_vec(&pg->ops, sizeof(pg_op));
	init_vec(&pg->points, sizeof(pg_point));
	init_vec(&pg->chars, sizeof(pg_char));
	init_vec(&pg->faces, sizeof(pg_face));
	init_vec(&pg->clips, sizeof(pg_rect));
	init_vec(&pg->images, sizeof(pg_image));
	init_vec(&pg->pixels, 1);
	init_vec(&pg->words, sizeof(pg_word));
	init_vec(&pg->letters, 1);
	init_vec(&pg->by_object, sizeof(owner));
	init_vec(&pg->embedded, sizeof(embedded));

	eb_lock();
	pg->doc = eb_open_locked(path, message, message_cap);
	if (!pg->doc) {
		eb_unlock();
		eb_page_free(pg);
		return NULL;
	}
	if (page_number < 1 || page_number > FPDF_GetPageCount(pg->doc)) {
		put_message(message, message_cap, "there is no such page");
		goto fail;
	}
	pg->page = FPDF_LoadPage(pg->doc, page_number - 1);
	if (!pg->page) {
		put_message(message, message_cap, "the page cannot be read");
		goto fail;
	}
	if (FPDFPage_GetRotation(pg->page) != 0) {
		/* A turned page is drawn as a picture, with no words. */
		if (!add_raster(pg)) {
			put_message(message, message_cap, "the page cannot be drawn");
			goto fail;
		}
		goto done;
	}
	if (!FPDF_GetPageBoundingBox(pg->page, &box) || box.right <= box.left || box.top <= box.bottom) {
		put_message(message, message_cap, "the page is empty");
		goto fail;
	}
	pg->left = box.left;
	pg->top = box.top;
	pg->width = box.right - box.left;
	pg->height = box.top - box.bottom;
	pg->text = FPDFText_LoadPage(pg->page);
	n_chars = pg->text ? FPDFText_CountChars(pg->text) : 0;
	for (i = 0; i < n_chars; i++) {
		void *obj = FPDFText_GetTextObject(pg->text, i);
		owner *o;
		if (!obj) continue;
		o = vec_push(&pg->by_object);
		if (o) { o->object = obj; o->index = i; }
	}
	qsort(pg->by_object.data, (size_t) pg->by_object.count, sizeof(owner), owner_order);
	add_objects(pg, NULL, FPDFPage_CountObjects(pg->page), &identity, 0);
	if (pg->unsupported) {
		/* What cannot be drawn as shapes: the page as one picture. Its
		 * words are still those of its text. */
		reset_drawing(pg);
		if (!add_raster(pg)) {
			put_message(message, message_cap, "the page cannot be drawn");
			goto fail;
		}
	}
	if (pg->text) collect_words(pg);
done:
	if (pg->text) FPDFText_ClosePage(pg->text);
	FPDF_ClosePage(pg->page);
	pg->text = NULL; pg->page = NULL; pg->doc = NULL;
	eb_unlock();
	return pg;

fail:
	if (pg->text) FPDFText_ClosePage(pg->text);
	if (pg->page) FPDF_ClosePage(pg->page);
	eb_unlock();
	eb_page_free(pg);
	return NULL;
}

void eb_page_sizes(const eb_page *pg, int *ops, int *points, int *chars, int *faces,
                   int *clips, int *images, int *bytes, float *width, float *height)
{
	*ops = pg->ops.count;
	*points = pg->points.count;
	*chars = pg->chars.count;
	*faces = pg->faces.count;
	*clips = pg->clips.count;
	*images = pg->images.count;
	*bytes = pg->pixels.count;
	*width = pg->width;
	*height = pg->height;
}

static void copy_vec(void *dest, const vec *v)
{
	if (dest && v->count > 0) memcpy(dest, v->data, (size_t) v->count * v->size);
}

void eb_page_fill(const eb_page *pg, void *ops, void *points, void *chars, void *faces,
                  void *clips, void *images, void *pixels)
{
	copy_vec(ops, &pg->ops);
	copy_vec(points, &pg->points);
	copy_vec(chars, &pg->chars);
	copy_vec(faces, &pg->faces);
	copy_vec(clips, &pg->clips);
	copy_vec(images, &pg->images);
	copy_vec(pixels, &pg->pixels);
}

/* The words, as Vision's are: truncated to the room there is. */
void eb_page_words(const eb_page *pg, pg_word *words, int max_words, char *text, int text_cap,
                   int *word_count, int *text_length, int *truncated)
{
	int n = pg->words.count, used = 0, i;
	const pg_word *src = pg->words.data;
	const char *letters = pg->letters.data;

	*truncated = 0;
	if (n > max_words) { n = max_words; *truncated = 1; }
	for (i = 0; i < n; i++) {
		int length = src[i].last - src[i].first + 1;
		if (used + length > text_cap) { *truncated = 1; n = i; break; }
		words[i] = src[i];
		words[i].first = used + 1;
		words[i].last = used + length;
		memcpy(text + used, letters + src[i].first - 1, (size_t) length);
		used += length;
	}
	*word_count = n;
	*text_length = used;
}
