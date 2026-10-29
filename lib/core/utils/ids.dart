import 'dart:math';

final Random _random = Random();

/// JS bitwise ops are 32-bit, so `1 << 32` is 0 on Flutter web and
/// `Random.nextInt` throws. Stay within signed 32-bit positive range.
const int kIdRandomMax = 1 << 30;

String newId() {
  return '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(kIdRandomMax)}';
}
