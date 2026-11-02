/// Turns model answers into whole, speakable sentences, ported from
/// Resonant's SentenceChunker.
///
/// A boundary is sentence-ending punctuation (or a line break) FOLLOWED BY
/// whitespace. Requiring the whitespace is what keeps "3.5" and "U.S.A"
/// from being cut early; the last sentence, which has no trailing
/// whitespace, is released at the end.
library;

/// Split [text] into cleaned sentences. Empty pieces are dropped, so an
/// empty answer splits to nothing.
List<String> splitSentences(String text) {
  final chunker = _Chunker();
  final out = chunker.feed(text);
  final rest = chunker.flush();
  if (rest != null) out.add(rest);
  return out;
}

class _Chunker {
  String _buf = '';

  List<String> feed(String delta) {
    _buf += delta;
    final out = <String>[];
    while (true) {
      final end = _findBoundary();
      if (end == null) break;
      final sentence = _clean(_buf.substring(0, end));
      _buf = _buf.substring(end);
      if (sentence.isNotEmpty) out.add(sentence);
    }
    return out;
  }

  String? flush() {
    final rest = _clean(_buf);
    _buf = '';
    return rest.isEmpty ? null : rest;
  }

  /// Index just past the first real sentence boundary, or null.
  int? _findBoundary() {
    var i = 0;
    while (i < _buf.length) {
      final c = _buf[i];
      final terminator = c == '.' || c == '!' || c == '?';
      if (terminator || c == '\n') {
        // A closing quote or bracket belongs to the sentence it closes:
        // `said "no." Then`.
        var end = i + 1;
        if (terminator) {
          while (end < _buf.length && _closers.contains(_buf[end])) {
            end++;
          }
        }
        // Need to SEE the whitespace after it.
        if (end < _buf.length && (c == '\n' || _isSpace(_buf[end]))) {
          if (!_falseBoundary(_buf.substring(0, i + 1), c)) return end;
        }
      }
      i++;
    }
    return null;
  }

  /// "1." (a list number) and "Dr." / "e.g." are not the end of a sentence.
  bool _falseBoundary(String candidate, String terminator) {
    if (terminator != '.') return false;
    final trimmed = candidate.trim();
    if (RegExp(r'^\d+\.$').hasMatch(trimmed)) return true;
    final words = trimmed
        .substring(0, trimmed.length - 1)
        .split(RegExp(r'[ \n]'));
    return _abbreviations.contains(words.last.toLowerCase());
  }
}

const _closers = '"\')]\u201d\u2019';

const _abbreviations = {
  'mr',
  'mrs',
  'ms',
  'dr',
  'prof',
  'st',
  'vs',
  'etc',
  'e.g',
  'i.e',
};

bool _isSpace(String c) => RegExp(r'\s').hasMatch(c);

/// Cleanup for text that will be read aloud, not displayed: strips
/// markdown the model wasn't supposed to emit, and collapses whitespace.
String _clean(String text) => text
    .replaceAll(RegExp(r'[*_`#~]+'), '')
    .replaceAll(RegExp(r'^\s*[-•]\s+'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
