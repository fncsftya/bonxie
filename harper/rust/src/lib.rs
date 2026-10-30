use harper_core::{
    Dialect, Document,
    linting::{LintGroup, LintKind, Linter, Suggestion},
    spell::{Dictionary, FstDictionary},
};
use std::panic::{AssertUnwindSafe, catch_unwind};

const MAX_TEXT: usize = 65536;
const MAX_LINTS: usize = 128;
const MAX_SUGGESTIONS: usize = 4;
const MAX_MESSAGE: usize = 512;
const MAX_REPLACEMENT: usize = 256;
const MAX_WORD: usize = 64;
const MAX_SYNONYMS: usize = 32;

#[repr(C)]
pub struct Edit {
    start: u32,
    end: u32,
    replacement_length: u32,
    replacement: [u8; MAX_REPLACEMENT],
}

#[repr(C)]
pub struct Diagnostic {
    start: u32,
    end: u32,
    kind: u32,
    priority: u32,
    message_length: u32,
    message_truncated: u32,
    message: [u8; MAX_MESSAGE],
    suggestion_count: u32,
    suggestions_truncated: u32,
    suggestions: [Edit; MAX_SUGGESTIONS],
}

#[repr(C)]
pub struct CheckResult {
    count: u32,
    truncated: u32,
    lints: [Diagnostic; MAX_LINTS],
}

// Explicit mapping: upstream's enum discriminants are not part of our ABI.
fn kind(value: LintKind) -> u32 {
    match value {
        LintKind::Agreement => 0,
        LintKind::BoundaryError => 1,
        LintKind::Capitalization => 2,
        LintKind::Eggcorn => 3,
        LintKind::Enhancement => 4,
        LintKind::Formatting => 5,
        LintKind::Grammar => 6,
        LintKind::Malapropism => 7,
        LintKind::Miscellaneous => 8,
        LintKind::Nonstandard => 9,
        LintKind::Punctuation => 10,
        LintKind::Readability => 11,
        LintKind::Redundancy => 12,
        LintKind::Regionalism => 13,
        LintKind::Repetition => 14,
        LintKind::Spelling => 15,
        LintKind::Style => 16,
        LintKind::Typo => 17,
        LintKind::Usage => 18,
        LintKind::WordChoice => 19,
        LintKind::WordOrder => 20,
    }
}

fn check(text: &str, dialect: Dialect, markdown: bool, result: &mut CheckResult) {
    let dictionary = FstDictionary::curated();
    let document = if markdown {
        Document::new_markdown_default(text, dictionary.as_ref())
    } else {
        Document::new_plain_english(text, dictionary.as_ref())
    };
    let mut linter = LintGroup::new_curated(dictionary, dialect);
    let mut lints = linter.lint(&document);
    // Stable presentation despite Harper's internal hash map iteration order.
    lints.sort_by(|a, b| {
        (
            a.span.start,
            a.span.end,
            a.priority,
            kind(a.lint_kind),
            &a.message,
        )
            .cmp(&(
                b.span.start,
                b.span.end,
                b.priority,
                kind(b.lint_kind),
                &b.message,
            ))
    });
    let offsets: Vec<usize> = text
        .char_indices()
        .map(|(i, _)| i)
        .chain([text.len()])
        .collect();
    result.truncated = u32::from(lints.len() > MAX_LINTS);
    for (lint, out) in lints.iter().zip(result.lints.iter_mut()) {
        assert!(lint.span.start <= lint.span.end && lint.span.end < offsets.len());
        out.start = offsets[lint.span.start] as u32;
        out.end = offsets[lint.span.end] as u32;
        out.kind = kind(lint.lint_kind);
        out.priority = u32::from(lint.priority);
        let mut length = lint.message.len().min(MAX_MESSAGE);
        while !lint.message.is_char_boundary(length) {
            length -= 1;
        }
        out.message[..length].copy_from_slice(&lint.message.as_bytes()[..length]);
        out.message_length = length as u32;
        out.message_truncated = u32::from(length < lint.message.len());
        for suggestion in &lint.suggestions {
            let (start, end, replacement) = match suggestion {
                Suggestion::ReplaceWith(chars) => {
                    (out.start, out.end, chars.iter().collect::<String>())
                }
                Suggestion::InsertAfter(chars) => {
                    (out.end, out.end, chars.iter().collect::<String>())
                }
                Suggestion::Remove => (out.start, out.end, String::new()),
            };
            if replacement.len() > MAX_REPLACEMENT
                || out.suggestion_count as usize == MAX_SUGGESTIONS
            {
                out.suggestions_truncated = 1;
                continue;
            }
            let edit = &mut out.suggestions[out.suggestion_count as usize];
            edit.start = start;
            edit.end = end;
            edit.replacement_length = replacement.len() as u32;
            edit.replacement[..replacement.len()].copy_from_slice(replacement.as_bytes());
            out.suggestion_count += 1;
        }
        result.count += 1;
    }
}

/// Check text, returning 0 on success, 1 for invalid UTF-8, 2 for invalid
/// arguments, or 3 for a caught panic. See include/bonxie_harper.h.
///
/// # Safety
/// Pointers must satisfy the readable/writable, alignment and nonaliasing
/// requirements documented in the C header.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bonxie_harper_check(
    text: *const u8,
    length: u32,
    dialect: u32,
    format: u32,
    result: *mut CheckResult,
) -> u32 {
    if result.is_null() {
        return 2;
    }
    // Initialize directly in caller storage, avoiding a large stack temporary.
    unsafe { result.write_bytes(0, 1) };
    if length as usize > MAX_TEXT || (text.is_null() && length != 0) || format > 1 {
        return 2;
    }
    let dialect = match dialect {
        0 => Dialect::American,
        1 => Dialect::Canadian,
        2 => Dialect::Australian,
        3 => Dialect::British,
        4 => Dialect::Indian,
        _ => return 2,
    };
    let bytes = if length == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(text, length as usize) }
    };
    let Ok(text) = std::str::from_utf8(bytes) else {
        return 1;
    };
    match catch_unwind(AssertUnwindSafe(|| {
        check(text, dialect, format == 1, unsafe { &mut *result })
    })) {
        Ok(()) => 0,
        Err(_) => {
            unsafe { result.write_bytes(0, 1) };
            3
        }
    }
}

#[repr(C)]
pub struct SynonymResult {
    count: u32,
    truncated: u32,
    lengths: [u32; MAX_SYNONYMS],
    words: [[u8; MAX_WORD]; MAX_SYNONYMS],
}

// What a lookup is keyed by, and the shape a synonym takes from the word it stands for.
fn is_word(text: &str) -> bool {
    !text.is_empty()
        && text
            .chars()
            .all(|c| c.is_alphabetic() || matches!(c, '\'' | '\u{2019}' | '-'))
}

// Words that only strengthen or soften the one after them: "very easy" is looked up as "easy".
const INTENSIFIERS: &[&str] = &[
    "very", "really", "quite", "rather", "extremely", "incredibly", "totally", "utterly",
    "truly", "terribly", "awfully", "fairly", "pretty", "so", "too", "highly", "especially",
    "exceedingly", "remarkably", "particularly", "absolutely", "completely", "entirely",
    "somewhat", "slightly", "a bit", "a little", "super", "mighty", "damn", "bloody",
];

fn recase(synonym: &str, word: &str) -> String {
    let mut letters = word.chars().filter(|c| c.is_alphabetic());
    let (first, second) = (letters.next(), letters.next());
    let upper = |c: Option<char>| c.is_some_and(char::is_uppercase);
    // All capitals only for a word of its own: "I" or "A" at the start of a phrase is not shouting.
    if upper(first) && upper(second) {
        synonym.to_uppercase()
    } else if upper(first) {
        let mut chars = synonym.chars();
        chars
            .next()
            .map(|c| c.to_uppercase().chain(chars).collect())
            .unwrap_or_default()
    } else {
        synonym.to_owned()
    }
}

// The key the thesaurus has for a phrase: the phrase itself, or what is left when the words that
// only strengthen are taken off its front.
fn key_for(lower: &str) -> Option<(String, Vec<&'static str>)> {
    let thesaurus = harper_thesaurus::thesaurus();
    let mut rest = lower;
    loop {
        if let Some(found) = thesaurus.get_synonyms_freq_sorted(rest) {
            return Some((rest.to_owned(), found));
        }
        let stripped = INTENSIFIERS.iter().find_map(|word| {
            rest.strip_prefix(word)
                .and_then(|tail| tail.strip_prefix(' '))
        });
        rest = stripped?.trim_start();
    }
}

fn synonyms(word: &str, result: &mut SynonymResult) {
    let lower = word.to_lowercase();
    let Some((key, mut found)) = key_for(&lower) else {
        return;
    };
    // A phrase is offered phrases; a word only words. None is the key or the whole phrase again. The
    // sort is stable, so the most used come first among those as near the word in kind (noun,
    // verb...) as each other.
    let phrase = lower.contains(' ');
    found.retain(|s| {
        *s != key
            && *s != lower
            && s.len() <= MAX_WORD
            && s.split(' ').all(is_word)
            && (phrase || !s.contains(' '))
    });
    let dictionary = FstDictionary::curated();
    if let Some(own) = dictionary.get_word_metadata_str(&key) {
        found.sort_by_key(|s| {
            dictionary
                .get_word_metadata_str(s)
                .map_or(u32::MAX, |meta| own.difference(&meta))
        });
    }
    result.truncated = u32::from(found.len() > MAX_SYNONYMS);
    for (synonym, index) in found.iter().zip(0..MAX_SYNONYMS) {
        let text = recase(synonym, word);
        if text.len() > MAX_WORD {
            continue;
        }
        result.words[index][..text.len()].copy_from_slice(text.as_bytes());
        result.lengths[index] = text.len() as u32;
        result.count += 1;
    }
    // Skipped (oversized) entries leave holes: close them up.
    let mut kept = 0;
    for index in 0..MAX_SYNONYMS {
        if result.lengths[index] > 0 {
            result.lengths.swap(kept, index);
            result.words.swap(kept, index);
            kept += 1;
        }
    }
}

/// Synonyms of a word or a short phrase, the most used first (see key_for). Returns 0 on success (a word the thesaurus lacks
/// has none), 1 for invalid UTF-8, 2 for invalid arguments, or 3 for a caught panic. See
/// include/bonxie_harper.h.
///
/// # Safety
/// Pointers must satisfy the readable/writable, alignment and nonaliasing
/// requirements documented in the C header.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn bonxie_harper_synonyms(
    text: *const u8,
    length: u32,
    result: *mut SynonymResult,
) -> u32 {
    if result.is_null() {
        return 2;
    }
    unsafe { result.write_bytes(0, 1) };
    if length == 0 || length as usize > MAX_WORD || text.is_null() {
        return 2;
    }
    let bytes = unsafe { std::slice::from_raw_parts(text, length as usize) };
    let Ok(word) = std::str::from_utf8(bytes) else {
        return 1;
    };
    match catch_unwind(AssertUnwindSafe(|| synonyms(word, unsafe { &mut *result }))) {
        Ok(()) => 0,
        Err(_) => {
            unsafe { result.write_bytes(0, 1) };
            3
        }
    }
}
