// Quiz progress, activity, streaks, profile summary and braille avatar.
// Ports of the old Resonant-AI QuizProgressStore, ActivityLog/Streaks/
// ActivityText, ProfileSummary and BrailleAvatar. All wording verbatim.

// ---------------------------------------------------------------------------
// Quiz progress
// ---------------------------------------------------------------------------

/// Where a quiz stands. Mirrors QuizProgressStore.Status.
enum QuizStatus { notStarted, inProgress, completed }

/// Per-quiz progress: best correct-answer count across attempts plus totals.
/// Mirrors QuizProgressStore.QuizProgress.
class QuizProgress {
  const QuizProgress({
    this.status = QuizStatus.notStarted,
    this.bestScore = 0,
    this.totalQuestions = 0,
  });

  final QuizStatus status;
  final int bestScore;
  final int totalQuestions;

  /// Best score as a whole-number percent, rounding down. Zero totals read 0.
  int get percentComplete =>
      totalQuestions == 0 ? 0 : bestScore * 100 ~/ totalQuestions;

  String get statusLabel {
    switch (status) {
      case QuizStatus.notStarted:
        return 'Not started';
      case QuizStatus.inProgress:
        return 'Ready to continue';
      case QuizStatus.completed:
        return 'Completed';
    }
  }

  String get buttonLabel {
    switch (status) {
      case QuizStatus.notStarted:
        return 'Start quiz';
      case QuizStatus.inProgress:
        return 'Continue quiz';
      case QuizStatus.completed:
        return 'Review answers';
    }
  }

  QuizProgress copyWith({
    QuizStatus? status,
    int? bestScore,
    int? totalQuestions,
  }) =>
      QuizProgress(
        status: status ?? this.status,
        bestScore: bestScore ?? this.bestScore,
        totalQuestions: totalQuestions ?? this.totalQuestions,
      );
}

/// In-memory per-quiz progress map with the old store's transitions.
/// Session-only: nothing here touches disk yet.
class QuizProgressBook {
  QuizProgressBook([Map<String, QuizProgress>? progress])
      : _progress = Map<String, QuizProgress>.of(progress ?? const {});

  final Map<String, QuizProgress> _progress;

  Map<String, QuizProgress> get progress => Map<String, QuizProgress>.unmodifiable(_progress);

  QuizProgress operator [](String quizId) =>
      _progress[quizId] ?? const QuizProgress();

  /// Set when a quiz is started but not finished. Never downgrades a
  /// completed quiz back to in-progress on a re-open.
  void markInProgress(String quizId, int totalQuestions) {
    final QuizProgress existing = this[quizId];
    if (existing.status == QuizStatus.completed) return;
    _progress[quizId] =
        existing.copyWith(status: QuizStatus.inProgress, totalQuestions: totalQuestions);
  }

  /// Finished: keeps the highest correct-answer count across attempts.
  void markCompleted(String quizId, int correct, int total) {
    final QuizProgress existing = this[quizId];
    _progress[quizId] = existing.copyWith(
      status: QuizStatus.completed,
      bestScore: correct > existing.bestScore ? correct : existing.bestScore,
      totalQuestions: total,
    );
  }

  void clear() => _progress.clear();
}

// ---------------------------------------------------------------------------
// Activity and streaks
// ---------------------------------------------------------------------------

/// What the person has done, as plain values. Days are epoch days (whole
/// days since 1970 in the phone's own time zone), so "yesterday" is
/// just `today - 1`. Mirrors the old ActivityLog.
class ActivityLog {
  const ActivityLog({
    this.activeDays = const <int>{},
    this.listeningSeconds = 0,
    this.todayDay = -1,
    this.todaySeconds = 0,
    this.lessonsFinished = const <String>{},
  });

  /// Days that count as a day of learning.
  final Set<int> activeDays;

  /// Every second of speech listened to, ever.
  final int listeningSeconds;

  /// The day [todaySeconds] belongs to; a new day starts it again from zero.
  final int todayDay;
  final int todaySeconds;

  /// Ids of the lessons read to the last sentence.
  final Set<String> lessonsFinished;

  ActivityLog copyWith({
    Set<int>? activeDays,
    int? listeningSeconds,
    int? todayDay,
    int? todaySeconds,
    Set<String>? lessonsFinished,
  }) =>
      ActivityLog(
        activeDays: activeDays ?? this.activeDays,
        listeningSeconds: listeningSeconds ?? this.listeningSeconds,
        todayDay: todayDay ?? this.todayDay,
        todaySeconds: todaySeconds ?? this.todaySeconds,
        lessonsFinished: lessonsFinished ?? this.lessonsFinished,
      );
}

/// Streak rules. Pure functions over [ActivityLog], mirroring old Streaks.
class Streaks {
  Streaks._();

  /// A day counts once this much has been listened to, or a lesson or
  /// quiz is finished.
  static const int activeSeconds = 60;

  /// Older days are forgotten; a streak that long is shown the same either way.
  static const int keepDays = 400;

  /// Days in a row ending today. A streak is still alive on a day with
  /// nothing yet, as long as yesterday counted, so opening the app in the
  /// morning does not show a broken streak.
  static int current(Set<int> days, int today) {
    int day;
    if (days.contains(today)) {
      day = today;
    } else if (days.contains(today - 1)) {
      day = today - 1;
    } else {
      return 0;
    }
    int run = 0;
    while (days.contains(day)) {
      run++;
      day--;
    }
    return run;
  }

  static int longest(Set<int> days) {
    int best = 0;
    int run = 0;
    int? previous;
    final List<int> sorted = days.toList()..sort();
    for (final int day in sorted) {
      run = previous != null && day == previous + 1 ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// Adds [seconds] of listening. The day becomes active once it has had
  /// [activeSeconds] of it.
  static ActivityLog withListening(ActivityLog log, int seconds, int today) {
    if (seconds <= 0) return log;
    final ActivityLog sameDay =
        log.todayDay == today ? log : log.copyWith(todayDay: today, todaySeconds: 0);
    final int todaySeconds = sameDay.todaySeconds + seconds;
    final ActivityLog next = sameDay.copyWith(
      listeningSeconds: sameDay.listeningSeconds + seconds,
      todaySeconds: todaySeconds,
    );
    return todaySeconds >= activeSeconds ? withDayActive(next, today) : next;
  }

  static ActivityLog withDayActive(ActivityLog log, int today) {
    if (log.activeDays.contains(today)) return log;
    return log.copyWith(activeDays: trim({...log.activeDays, today}, today));
  }

  static ActivityLog withLessonFinished(ActivityLog log, String id, int today) =>
      withDayActive(
          log.copyWith(lessonsFinished: {...log.lessonsFinished, id}), today);

  static Set<int> trim(Set<int> days, int today) =>
      days.where((int d) => d > today - keepDays).toSet();
}

/// How these numbers are said and shown. One place, so the screen and the
/// spoken summary agree. Mirrors old ActivityText.
class ActivityText {
  ActivityText._();

  static String days(int n) => n == 1 ? '1 day' : '$n days';

  static String streakLine(int streak) =>
      streak <= 0 ? 'Streak: none yet' : 'Streak: ${days(streak)}';

  static String longestLine(int longest) => 'Longest streak: ${days(longest)}';

  static String listening(int seconds) {
    final int minutes = seconds ~/ 60;
    if (seconds < 60) return 'under a minute';
    if (minutes < 60) return minutes == 1 ? '1 minute' : '$minutes minutes';
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = hours == 1 ? '1 hour' : '$hours hours';
    if (rest == 0) return h;
    return '$h ${rest == 1 ? '1 minute' : '$rest minutes'}';
  }

  static String listeningLine(int seconds) => 'Listening: ${listening(seconds)}';
}

// ---------------------------------------------------------------------------
// Profile summary
// ---------------------------------------------------------------------------

/// What the Profile screen shows about progress. Plain numbers, so the
/// wording is unit tested. Mirrors old ProfileStats.
class ProfileStats {
  const ProfileStats({
    required this.quizzesDone,
    required this.quizzesTotal,
    required this.averagePercent,
    required this.materials,
    this.streak = 0,
    this.longestStreak = 0,
    this.listeningSeconds = 0,
    this.lessonsDone = 0,
    this.lessonsTotal = 0,
  });

  final int quizzesDone;
  final int quizzesTotal;

  /// Mean of each finished quiz's best score, in percent.
  /// Null until one is finished.
  final int? averagePercent;
  final int materials;

  /// Days in a row with some learning, still alive if yesterday counted.
  final int streak;
  final int longestStreak;
  final int listeningSeconds;
  final int lessonsDone;
  final int lessonsTotal;
}

/// Profile numbers and lines. Mirrors old ProfileSummary.
class ProfileSummary {
  ProfileSummary._();

  /// Counts only quizzes and lessons that exist now, so a removed one
  /// can't push a count past its total.
  static ProfileStats stats({
    required Map<String, QuizProgress> progress,
    required List<String> quizIds,
    required int materials,
    ActivityLog activity = const ActivityLog(),
    int today = 0,
    List<String> lessonIds = const <String>[],
  }) {
    final List<QuizProgress> done = quizIds
        .map((String id) => progress[id])
        .whereType<QuizProgress>()
        .where((QuizProgress p) => p.status == QuizStatus.completed)
        .toList();
    final int? average = done.isEmpty
        ? null
        : done.map((QuizProgress p) => p.percentComplete).reduce((int a, int b) => a + b) ~/
            done.length;
    return ProfileStats(
      quizzesDone: done.length,
      quizzesTotal: quizIds.length,
      averagePercent: average,
      materials: materials,
      streak: Streaks.current(activity.activeDays, today),
      longestStreak: Streaks.longest(activity.activeDays),
      listeningSeconds: activity.listeningSeconds,
      lessonsDone: lessonIds.where(activity.lessonsFinished.contains).length,
      lessonsTotal: lessonIds.length,
    );
  }

  static String quizLine(ProfileStats s) => s.quizzesTotal == 0
      ? 'Quizzes: none yet'
      : 'Quizzes: ${s.quizzesDone} of ${s.quizzesTotal} done';

  static String lessonsLine(ProfileStats s) => s.lessonsTotal == 0
      ? 'Lessons: none yet'
      : 'Lessons: ${s.lessonsDone} of ${s.lessonsTotal} finished';

  static String? averageLine(ProfileStats s) =>
      s.averagePercent == null ? null : 'Average best score: ${s.averagePercent} percent';

  static String materialsLine(ProfileStats s) =>
      s.materials == 0 ? 'Materials: none yet' : 'Materials: ${s.materials}';

  /// The spoken "How am I doing?" answer. Says what is there and one thing
  /// to do next, never a verdict.
  static String spoken(String? name, ProfileStats s) {
    final String who = (name ?? '').trim();
    final List<String> parts = <String>[
      if (who.isNotEmpty)
        'Here is how you are doing, $who.'
      else
        'Here is how you are doing.'
    ];
    if (s.streak > 0) parts.add('You are on a ${s.streak} day streak.');
    if (s.lessonsTotal > 0) {
      parts.add(s.lessonsDone == 0
          ? 'You have not finished a lesson yet.'
          : 'You have finished ${s.lessonsDone} of ${s.lessonsTotal} lessons.');
    }
    if (s.quizzesTotal == 0) {
      parts.add('There are no quizzes yet.');
    } else if (s.quizzesDone == 0) {
      parts.add('You have not finished a quiz yet.');
    } else {
      final String tail = s.averagePercent == null
          ? '.'
          : ', with an average best score of ${s.averagePercent} percent.';
      parts.add('You have finished ${s.quizzesDone} of ${s.quizzesTotal} quizzes$tail');
    }
    if (s.materials == 0) {
      parts.add('You have not added your own material yet.');
    } else if (s.materials == 1) {
      parts.add('You have added one material of your own.');
    } else {
      parts.add('You have added ${s.materials} materials of your own.');
    }
    if (s.listeningSeconds >= 60) {
      parts.add('You have listened for ${ActivityText.listening(s.listeningSeconds)}.');
    }
    if (s.quizzesTotal > 0 && s.quizzesDone < s.quizzesTotal) {
      parts.add('Next, try a quiz you have not finished.');
    } else if (s.lessonsTotal > 0 && s.lessonsDone < s.lessonsTotal) {
      parts.add('Next, open a lesson you have not finished.');
    } else if (s.materials == 0) {
      parts.add('You can add your own material in Settings.');
    } else {
      parts.add('Keep going.');
    }
    return parts.join(' ');
  }
}

// ---------------------------------------------------------------------------
// Braille avatar
// ---------------------------------------------------------------------------

/// The name written in braille, one cell per letter, used as the avatar.
/// Unique per name without a photo. Mirrors old BrailleAvatar.
class BrailleAvatar {
  BrailleAvatar._();

  /// Dot numbers 1-6 for a to z. Dots 1-3 run down the left column,
  /// 4-6 down the right.
  static const Map<String, String> letters = <String, String>{
    'a': '1', 'b': '12', 'c': '14', 'd': '145', 'e': '15', 'f': '124',
    'g': '1245', 'h': '125', 'i': '24', 'j': '245', 'k': '13', 'l': '123',
    'm': '134', 'n': '1345', 'o': '135', 'p': '1234', 'q': '12345',
    'r': '1235', 's': '234', 't': '2345', 'u': '136', 'v': '1236',
    'w': '2456', 'x': '1346', 'y': '13456', 'z': '1356',
  };

  /// One list of the dot numbers that are raised per cell. Only plain a-z
  /// letters count; the rest are skipped.
  static List<List<int>> cells(String? name) {
    final List<List<int>> out = <List<int>>[];
    for (final int unit in (name ?? '').toLowerCase().codeUnits) {
      final String? dots = letters[String.fromCharCode(unit)];
      if (dots == null) continue;
      out.add(dots.codeUnits.map((int c) => c - 0x30).toList());
    }
    return out;
  }

  /// Width of one cell so that [count] cells and their gaps fit in
  /// [available]. Never wider than [maxWidth].
  static double cellWidth({
    required int count,
    required double available,
    double maxWidth = 44,
    double gapRatio = 16 / 44,
  }) {
    if (count <= 0) return maxWidth;
    final double fit = available / (count + gapRatio * (count - 1));
    return fit < maxWidth ? fit : maxWidth;
  }
}
