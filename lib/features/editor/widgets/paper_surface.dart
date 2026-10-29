import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/image_layer.dart';
import '../../../state/editor_controller.dart';

void paintImageLayer(Canvas canvas, ImageLayer layer, ui.Image image) {
  if (layer.opacity <= 0) return;
  final crop = layer.normalizedCrop;
  final src = Rect.fromLTWH(
    crop.left * image.width,
    crop.top * image.height,
    crop.width * image.width,
    crop.height * image.height,
  );
  if (src.width <= 0.5 || src.height <= 0.5) return;

  canvas.save();
  canvas.translate(layer.position.dx, layer.position.dy);
  canvas.rotate(layer.rotation);
  canvas.scale(layer.scaleX, layer.scaleY);
  final dst = Rect.fromCenter(
    center: Offset.zero,
    width: src.width,
    height: src.height,
  );
  final paint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..color = Color.fromRGBO(255, 255, 255, layer.opacity);
  canvas.drawImageRect(image, src, dst, paint);
  canvas.restore();
}

class PaperBoard extends StatelessWidget {
  const PaperBoard({
    super.key,
    required this.controller,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.paperSizePx;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.42),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRect(
        child: CustomPaint(
          size: size,
          painter: PaperPainter(controller),
        ),
      ),
    );
  }
}

class PaperPainter extends CustomPainter {
  PaperPainter(this.controller)
      : layers = List<ImageLayer>.from(
          controller.layers.whereType<ImageLayer>(),
        ),
        images = Map<String, ui.Image>.from(controller.decodedImages);

  final EditorController controller;
  final List<ImageLayer> layers;
  final Map<String, ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final layer in layers) {
      if (!layer.visible) continue;
      final image = images[layer.id];
      if (image == null) continue;
      paintImageLayer(canvas, layer, image);
    }
  }

  @override
  bool shouldRepaint(covariant PaperPainter oldDelegate) => true;
}
