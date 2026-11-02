// Milestone definitions and celebration lines, mirroring the old
// Resonant-AI `Milestones` object (titles and lines verbatim).
import 'progress.dart';

/// One milestone: an id, a display title, and a predicate over stats.
class Milestone {
  const Milestone(this.id, this.title, this.reachedBy);
  final String id;
  final String title;
  final bool Function(ProfileStats s) reachedBy;
}

/// All 14 milestones in old-app order: the firsts, then streaks,
/// then the bigger counts.
final List<Milestone> allMilestones = <Milestone>[
  Milestone('lessons_1', 'First lesson finished', (ProfileStats s) => s.lessonsDone >= 1),
  Milestone('quizzes_1', 'First quiz finished', (ProfileStats s) => s.quizzesDone >= 1),
  Milestone('material_1', 'First material of your own', (ProfileStats s) => s.materials >= 1),
  _streak(3),
  _streak(7),
  _streak(14),
  _streak(30),
  Milestone('lessons_5', '5 lessons finished', (ProfileStats s) => s.lessonsDone >= 5),
  Milestone('lessons_10', '10 lessons finished', (ProfileStats s) => s.lessonsDone >= 10),
  Milestone('lessons_all', 'Every lesson finished',
      (ProfileStats s) => s.lessonsTotal > 0 && s.lessonsDone >= s.lessonsTotal),
  Milestone('quizzes_5', '5 quizzes finished', (ProfileStats s) => s.quizzesDone >= 5),
  Milestone('quizzes_all', 'Every quiz finished',
      (ProfileStats s) => s.quizzesTotal > 0 && s.quizzesDone >= s.quizzesTotal),
  Milestone('listen_1h', '1 hour of listening', (ProfileStats s) => s.listeningSeconds >= 3600),
  Milestone('listen_10h', '10 hours of listening', (ProfileStats s) => s.listeningSeconds >= 36000),
];

Milestone _streak(int days) => Milestone('streak_$days', '$days day streak',
    (ProfileStats s) => (s.streak > s.longestStreak ? s.streak : s.longestStreak) >= days);

/// Reached right now by current stats.
List<Milestone> reachedMilestonesNow(ProfileStats s) =>
    allMilestones.where((Milestone m) => m.reachedBy(s)).toList();

/// Reached now or told about before. A milestone never un-reaches,
/// even if a streak breaks.
List<Milestone> reachedMilestones(ProfileStats s, Set<String> seen) =>
    allMilestones
        .where((Milestone m) => seen.contains(m.id) || m.reachedBy(s))
        .toList();

/// Reached now but never told about: these get celebrated.
List<Milestone> freshMilestones(ProfileStats s, Set<String> seen) =>
    reachedMilestonesNow(s).where((Milestone m) => !seen.contains(m.id)).toList();

/// The first milestone still ahead, or null when there is none.
Milestone? nextMilestone(List<Milestone> reached) {
  final Set<String> ids = reached.map((Milestone m) => m.id).toSet();
  for (final Milestone m in allMilestones) {
    if (!ids.contains(m.id)) return m;
  }
  return null;
}

/// The line shown for the row. Plain numbers, not counted up.
String milestoneRowLine(List<Milestone> reached, List<Milestone> fresh) {
  final String base = 'Milestones: ${reached.length} of ${allMilestones.length}';
  return fresh.isEmpty ? base : '$base, ${fresh.length} new';
}

/// What is said when the row is opened.
String milestoneSpoken(List<Milestone> reached) {
  final List<String> parts = <String>[
    'You have reached ${reached.length} of ${allMilestones.length} milestones.'
  ];
  if (reached.isNotEmpty && reached.length <= 5) {
    parts.add('Reached: ${reached.map((Milestone m) => m.title).join(', ')}.');
  }
  final Milestone? next = nextMilestone(reached);
  parts.add(next == null
      ? 'You have reached every milestone.'
      : 'Next goal: ${next.title}.');
  return parts.join(' ');
}

/// What is said once when new ones are reached. Never a long list.
String milestoneAnnouncement(List<Milestone> fresh) {
  switch (fresh.length) {
    case 0:
      return '';
    case 1:
      return 'New milestone: ${fresh[0].title}.';
    case 2:
    case 3:
      final String head =
          fresh.sublist(0, fresh.length - 1).map((Milestone m) => m.title).join(', ');
      return 'New milestones: $head and ${fresh.last.title}.';
    default:
      return 'You have reached ${fresh.length} new milestones, including ${fresh.last.title}.';
  }
}
