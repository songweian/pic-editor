import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class SampleImage {
  const SampleImage({
    required this.name,
    required this.width,
    required this.height,
    required this.r,
    required this.g,
    required this.b,
  });

  final String name;
  final int width;
  final int height;
  final int r;
  final int g;
  final int b;
}

const List<SampleImage> kSampleImages = [
  SampleImage(
    name: '蓝示例',
    width: 480,
    height: 320,
    r: 46,
    g: 92,
    b: 158,
  ),
  SampleImage(
    name: '暖示例',
    width: 320,
    height: 480,
    r: 176,
    g: 92,
    b: 64,
  ),
];

Uint8List buildSamplePng(SampleImage spec) {
  final image = img.Image(width: spec.width, height: spec.height);
  img.fill(image, color: img.ColorRgb8(spec.r, spec.g, spec.b));

  final light = img.ColorRgb8(
    math.min(255, spec.r + 70),
    math.min(255, spec.g + 70),
    math.min(255, spec.b + 50),
  );
  final dark = img.ColorRgb8(
    (spec.r * 0.45).round(),
    (spec.g * 0.45).round(),
    (spec.b * 0.45).round(),
  );
  final white = img.ColorRgb8(255, 255, 255);

  img.fillRect(
    image,
    x1: 24,
    y1: 24,
    x2: spec.width - 25,
    y2: spec.height - 25,
    color: light,
  );
  img.drawRect(
    image,
    x1: 40,
    y1: 40,
    x2: spec.width - 41,
    y2: spec.height - 41,
    color: white,
    thickness: 10,
  );

  final radius = math.min(spec.width, spec.height) ~/ 5;
  img.fillCircle(
    image,
    x: spec.width ~/ 2,
    y: spec.height ~/ 2,
    radius: radius,
    color: dark,
  );
  img.fillCircle(
    image,
    x: spec.width ~/ 2,
    y: spec.height ~/ 2,
    radius: radius ~/ 2,
    color: white,
  );

  for (var i = 1; i <= 6; i++) {
    final y = (spec.height * i / 7).round();
    img.drawLine(
      image,
      x1: 80,
      y1: y,
      x2: spec.width - 80,
      y2: y,
      color: dark,
      thickness: 3,
    );
  }

  return Uint8List.fromList(img.encodePng(image));
}
