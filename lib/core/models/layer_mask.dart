import 'dart:typed_data';

/// Low-resolution grayscale mask. 255 keeps pixels, 0 hides them.
class LayerMask {
  const LayerMask({
    required this.pixels,
    this.width = 64,
    this.height = 64,
    this.enabled = true,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final bool enabled;

  static LayerMask fullVisible({int width = 64, int height = 64}) {
    return LayerMask(
      pixels: Uint8List(width * height)..fillRange(0, width * height, 255),
      width: width,
      height: height,
    );
  }

  LayerMask copyWith({
    Uint8List? pixels,
    int? width,
    int? height,
    bool? enabled,
  }) {
    return LayerMask(
      pixels: pixels ?? Uint8List.fromList(this.pixels),
      width: width ?? this.width,
      height: height ?? this.height,
      enabled: enabled ?? this.enabled,
    );
  }

  int sample(double u, double v) {
    if (pixels.isEmpty) return 255;
    final x = (u.clamp(0.0, 1.0) * (width - 1)).round();
    final y = (v.clamp(0.0, 1.0) * (height - 1)).round();
    return pixels[y * width + x];
  }
}
