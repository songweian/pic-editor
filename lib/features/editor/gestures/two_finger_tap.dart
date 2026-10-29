import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TwoFingerTapTracker {
  TwoFingerTapTracker({
    this.moveSlop = 18,
    this.maxDuration = const Duration(milliseconds: 450),
  });

  final double moveSlop;
  final Duration maxDuration;

  final Map<int, Offset> _down = <int, Offset>{};
  final Map<int, Offset> _last = <int, Offset>{};
  DateTime? _twoFingerAt;
  double? _startSpan;
  bool _moved = false;

  int get pointerCount => _last.length;
  bool get isTwoFinger => _last.length >= 2;
  bool get moved => _moved;

  Offset get centroid {
    if (_last.isEmpty) return Offset.zero;
    var sum = Offset.zero;
    for (final point in _last.values) {
      sum += point;
    }
    return sum / _last.length.toDouble();
  }

  double get span {
    if (_last.length < 2) return 0;
    final points = _last.values.take(2).toList();
    return (points[0] - points[1]).distance;
  }

  bool get isPinch {
    final start = _startSpan;
    if (start == null) return false;
    return (span - start).abs() > 24;
  }

  void down(int pointer, Offset global) {
    _down[pointer] = global;
    _last[pointer] = global;
    if (_last.length == 2) {
      _twoFingerAt = DateTime.now();
      _startSpan = span;
      _moved = false;
    } else if (_last.length > 2) {
      _moved = true;
    }
  }

  void move(int pointer, Offset global) {
    _last[pointer] = global;
    final start = _down[pointer];
    if (start != null && (global - start).distance > moveSlop) {
      _moved = true;
    }
  }

  /// Returns the tap centroid when a two-finger tap completes.
  Offset? up(int pointer) {
    Offset? tap;
    if (_last.length == 2 &&
        !_moved &&
        _twoFingerAt != null &&
        DateTime.now().difference(_twoFingerAt!) <= maxDuration) {
      tap = centroid;
    }
    _down.remove(pointer);
    _last.remove(pointer);
    if (_last.length < 2) {
      _twoFingerAt = null;
      _startSpan = null;
    }
    return tap;
  }

  void cancel(int pointer) {
    _down.remove(pointer);
    _last.remove(pointer);
    _twoFingerAt = null;
    if (_last.length < 2) {
      _moved = false;
      _startSpan = null;
    }
  }

  void reset() {
    _down.clear();
    _last.clear();
    _twoFingerAt = null;
    _startSpan = null;
    _moved = false;
  }
}

class TwoFingerTapDetector extends StatefulWidget {
  const TwoFingerTapDetector({
    super.key,
    required this.onTwoFingerTap,
    required this.child,
  });

  final ValueChanged<Offset> onTwoFingerTap;
  final Widget child;

  @override
  State<TwoFingerTapDetector> createState() => _TwoFingerTapDetectorState();
}

class _TwoFingerTapDetectorState extends State<TwoFingerTapDetector> {
  final TwoFingerTapTracker _tracker = TwoFingerTapTracker();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) return;
        _tracker.down(event.pointer, event.position);
      },
      onPointerMove: (event) => _tracker.move(event.pointer, event.position),
      onPointerUp: (event) {
        final tap = _tracker.up(event.pointer);
        if (tap != null) widget.onTwoFingerTap(tap);
      },
      onPointerCancel: (event) => _tracker.cancel(event.pointer),
      child: widget.child,
    );
  }
}
