import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

Future<ui.Image> decodeImageBytes(Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw const FormatException('empty image bytes');
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('unsupported image bytes');
  }

  final pixels = decoded.getBytes(order: img.ChannelOrder.rgba);
  if (pixels.isEmpty) {
    throw const FormatException('decoded image has no pixels');
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    decoded.width,
    decoded.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
