import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/profile_motion.dart';

void main() {
  group('count up', () {
    test('at full progress the label comes back untouched', () {
      expect(CountUp.apply('Quizzes: 3 of 4 done', 1), 'Quizzes: 3 of 4 done');
    });

    test('numbers climb from zero', () {
      expect(CountUp.apply('Quizzes: 3 of 4 done', 0), 'Quizzes: 0 of 0 done');
      expect(CountUp.apply('Quizzes: 4 of 4 done', 0.5), 'Quizzes: 2 of 2 done');
    });

    test('lines without numbers are left alone', () {
      expect(CountUp.apply('Streak: none yet', 0.3), 'Streak: none yet');
    });
  });

  group('avatar motion', () {
    test('dots light one after another inside a cell', () {
      expect(AvatarMotion.dotProgress(0, 1), 0);
      expect(AvatarMotion.dotProgress(1, 6), 1);
      expect(AvatarMotion.dotProgress(0.2, 1),
          closeTo((0.2 - 0 * 0.1) / 0.5, 1e-9));
      expect(AvatarMotion.dotProgress(0.2, 6), 0);
    });

    test('the swell grows then settles back to exactly one', () {
      expect(AvatarMotion.swell(0), 1);
      expect(AvatarMotion.swell(1), closeTo(1, 1e-9));
      expect(AvatarMotion.swell(0.5), closeTo(1.4, 1e-9));
    });

    test('resting dots fade in quickly at the start', () {
      expect(AvatarMotion.restingAlpha(0), 0);
      expect(AvatarMotion.restingAlpha(1), closeTo(0.15, 1e-9));
    });

    test('the shine rolls along the name and is gone at the end', () {
      expect(AvatarMotion.shine(0, 0, 3), greaterThan(0));
      expect(AvatarMotion.shine(1, 2, 3), 0);
      expect(AvatarMotion.shine(0.5, 99, 3), 0);
      expect(AvatarMotion.shine(0.5, 0, 0), 0);
    });
  });
}
