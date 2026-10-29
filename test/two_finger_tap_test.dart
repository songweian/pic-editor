import 'package:flutter_test/flutter_test.dart';
import 'package:pic_editor/features/editor/gestures/two_finger_tap.dart';

void main() {
  test('双指轻点返回中心点', () {
    final tracker = TwoFingerTapTracker();
    tracker.down(1, const Offset(10, 10));
    tracker.down(2, const Offset(30, 10));
    expect(tracker.isTwoFinger, isTrue);
    expect(tracker.centroid, const Offset(20, 10));
    expect(tracker.up(1), const Offset(20, 10));
    expect(tracker.up(2), isNull);
  });

  test('双指滑动不算点击', () {
    final tracker = TwoFingerTapTracker();
    tracker.down(1, const Offset(10, 10));
    tracker.down(2, const Offset(30, 10));
    tracker.move(1, const Offset(10, 80));
    tracker.move(2, const Offset(30, 80));
    expect(tracker.moved, isTrue);
    expect(tracker.isPinch, isFalse);
    expect(tracker.up(1), isNull);
    expect(tracker.up(2), isNull);
  });

  test('双指开合识别为捏合', () {
    final tracker = TwoFingerTapTracker();
    tracker.down(1, const Offset(0, 0));
    tracker.down(2, const Offset(40, 0));
    tracker.move(1, const Offset(-40, 0));
    tracker.move(2, const Offset(80, 0));
    expect(tracker.isPinch, isTrue);
    expect(tracker.up(1), isNull);
  });
}
