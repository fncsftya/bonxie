#ifndef BONXIE_HARPER_H
#define BONXIE_HARPER_H
#include <stdint.h>

#define BH_MAX_TEXT 65536
#define BH_MAX_LINTS 128
#define BH_MAX_SUGGESTIONS 4
#define BH_MAX_MESSAGE 512
#define BH_MAX_REPLACEMENT 256

/* All text is UTF-8, length delimited, without a terminating NUL.
 * Spans are zero based byte offsets [start, end) into the submitted text.
 * An insertion has start == end. A removal has replacement_length == 0.
 * Oversized replacements are omitted, never shortened into an unsafe edit.
 */
typedef struct {
    uint32_t start, end, replacement_length;
    uint8_t replacement[BH_MAX_REPLACEMENT];
} bh_suggestion;

/* Kind values follow this ABI's order, independently of Rust enum layout. */
typedef enum {
    BH_AGREEMENT, BH_BOUNDARY_ERROR, BH_CAPITALIZATION, BH_EGGCORN,
    BH_ENHANCEMENT, BH_FORMATTING, BH_GRAMMAR, BH_MALAPROPISM,
    BH_MISCELLANEOUS, BH_NONSTANDARD, BH_PUNCTUATION, BH_READABILITY,
    BH_REDUNDANCY, BH_REGIONALISM, BH_REPETITION, BH_SPELLING, BH_STYLE,
    BH_TYPO, BH_USAGE, BH_WORD_CHOICE, BH_WORD_ORDER
} bh_kind;

typedef struct {
    uint32_t start, end, kind, priority, message_length, message_truncated;
    uint8_t message[BH_MAX_MESSAGE];
    uint32_t suggestion_count, suggestions_truncated;
    bh_suggestion suggestions[BH_MAX_SUGGESTIONS];
} bh_lint;

typedef struct {
    uint32_t count, truncated;
    bh_lint lints[BH_MAX_LINTS];
} bh_result;

enum { BH_OK, BH_INVALID_UTF8, BH_INVALID_ARGUMENT, BH_PANIC };
enum { BH_AMERICAN, BH_CANADIAN, BH_AUSTRALIAN, BH_BRITISH, BH_INDIAN };
enum { BH_PLAIN_TEXT, BH_MARKDOWN };

#define BH_MAX_WORD 64
#define BH_MAX_SYNONYMS 32

/* Synonyms of one word, the most used first: words[i] holds lengths[i] bytes of UTF-8, none
 * terminated. A word is given only words; a phrase (words with spaces), phrases and words. The capitals are those of
 * the text asked for. A phrase the thesaurus lacks is looked up without the words in front of it that only
 * strengthen (very, quite, ...), so "very easy" gives what "easy" does.
 */
typedef struct {
    uint32_t count, truncated;
    uint32_t lengths[BH_MAX_SYNONYMS];
    uint8_t words[BH_MAX_SYNONYMS][BH_MAX_WORD];
} bh_synonyms;

/* Synchronous: the Ada binding calls this exclusively inside its Checker task.
 * text must address length readable bytes (NULL is allowed only for length 0).
 * result must address an aligned, writable bh_result, disjoint from text.
 * No pointers are retained. Output is empty on failure. Each call owns its
 * linter; the immutable built-in dictionary is shared. No runtime or worker
 * threads are started by this wrapper. Allocation inside Harper is required.
 */
#ifdef __cplusplus
extern "C" {
#endif
uint32_t bonxie_harper_check(const uint8_t *text, uint32_t length,
                            uint32_t dialect, uint32_t format, bh_result *result);

/* Look up the word or phrase of length bytes (1 to BH_MAX_WORD) in the thesaurus: the first call reads it.
 * The statuses are those of bonxie_harper_check; a word it lacks is BH_OK with count 0.
 */
uint32_t bonxie_harper_synonyms(const uint8_t *text, uint32_t length, bh_synonyms *result);
#ifdef __cplusplus
}
#endif
#endif
