import 'region.dart';

/// Fuzzy "where is X" matching. Speech-to-text slips ("artheria" for "artery")
/// must still find the part, close runners-up ask "did you mean A or B?",
/// and weak matches say the part could not be found.
///
/// Pure Dart, no model calls: it runs on the phone when the student asks.
sealed class GuideMatch {
  const GuideMatch();
}

/// This was not a guide request at all (a normal tutor question).
final class GuideNotRequested extends GuideMatch {
  const GuideNotRequested();
}

/// One part clearly won.
final class GuideFound extends GuideMatch {
  const GuideFound(this.region, this.score);
  final Region region;
  final double score;
}

/// Two parts scored within [guideAmbiguityMargin]: ask which one.
final class GuideAmbiguous extends GuideMatch {
  const GuideAmbiguous(this.first, this.second);
  final Region first;
  final Region second;
}

/// A guide request, but nothing scored above [guideMatchThreshold].
final class GuideNotFound extends GuideMatch {
  const GuideNotFound();
}

/// Minimum score to accept a match. "artheria" scores about 0.63 against
/// "artery", so the threshold sits just below that.
const double guideMatchThreshold = 0.6;

/// When the top two scores are this close (and both pass the threshold),
/// ask instead of guessing.
const double guideAmbiguityMargin = 0.08;

const _stopwords = {
  'where',
  'whereas',
  'is',
  'are',
  'was',
  'the',
  'a',
  'an',
  'find',
  'finds',
  'found',
  'guide',
  'me',
  'my',
  'to',
  'there',
  'here',
  'it',
  'that',
  'this',
  'of',
  'for',
  'please',
  'show',
  'take',
  'locate',
  'point',
  's',
};

List<String> _words(String text, {required bool dropStopwords}) {
  final out = <String>[];
  for (final m in RegExp(r'[a-z]+').allMatches(text.toLowerCase())) {
    final w = m.group(0)!;
    if (w.length < 2) continue;
    if (dropStopwords && _stopwords.contains(w)) continue;
    out.add(w);
  }
  return out;
}

/// Edit distance between two short words (two rows, no allocations per cell).
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var best = prev[j] + 1; // deletion
      final ins = curr[j - 1] + 1; // insertion
      if (ins < best) best = ins;
      final sub = prev[j - 1] + cost; // substitution
      if (sub < best) best = sub;
      curr[j] = best;
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// 1.0 for identical words, fading to 0.0 as the spelling drifts.
double wordSimilarity(String a, String b) {
  if (a == b) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 1;
  return 1 - levenshtein(a, b) / longest;
}

/// Each label word takes its best match among the heard words; the score rewards
/// a strong word match (so "lung" finds "left lung" and slips still land)
/// plus a bonus when every word matches (so "left lung" beats "right lung").
double _regionScore(List<String> labelWords, List<String> heardWords) {
  if (labelWords.isEmpty || heardWords.isEmpty) return 0;
  var maxBest = 0.0;
  var sum = 0.0;
  for (final lw in labelWords) {
    var best = 0.0;
    for (final hw in heardWords) {
      final s = wordSimilarity(lw, hw);
      if (s > best) best = s;
    }
    if (best > maxBest) maxBest = best;
    sum += best;
  }
  return 0.7 * maxBest + 0.3 * (sum / labelWords.length);
}

/// The part named in a "find / where is" request, fuzzily matched.
GuideMatch matchGuideTarget(List<Region> regions, String heard) {
  final text = ' ${heard.toLowerCase().replaceAll(RegExp("[^a-z' ]"), ' ')} ';
  final wantsGuide =
      text.contains(' find ') ||
      text.contains(' where is ') ||
      text.contains(" where's ") ||
      text.contains(' guide me ');
  if (!wantsGuide) return const GuideNotRequested();
  if (regions.isEmpty) return const GuideNotFound();
  final heardWords = _words(heard, dropStopwords: true);
  if (heardWords.isEmpty) return const GuideNotFound();
  final scored = [
    for (final r in regions)
      (r, _regionScore(_words(r.label, dropStopwords: false), heardWords)),
  ]..sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    final byOrder = a.$1.order.compareTo(b.$1.order);
    if (byOrder != 0) return byOrder;
    return a.$1.left.compareTo(b.$1.left);
  });
  final best = scored.first;
  if (best.$2 < guideMatchThreshold) return const GuideNotFound();
  if (scored.length > 1) {
    final runnerUp = scored[1];
    if (runnerUp.$2 >= guideMatchThreshold &&
        (best.$2 - runnerUp.$2).abs() <= guideAmbiguityMargin) {
      return GuideAmbiguous(best.$1, runnerUp.$1);
    }
  }
  return GuideFound(best.$1, best.$2);
}
