import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../state/editor_controller.dart';
import 'layer_render.dart';

export 'layer_render.dart' show paintImageLayer, paintLayerTree;

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
      : layers = List.of(controller.layers),
        images = Map<String, ui.Image>.from(controller.decodedImages),
        isolationId = controller.isolationId,
        wireframe = controller.wireframePreview;

  final EditorController controller;
  final List layers;
  final Map<String, ui.Image> images;
  final String? isolationId;
  final bool wireframe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    paintLayerTree(
      canvas,
      size,
      layers: controller.layers,
      images: images,
      isolationId: isolationId,
      wireframe: wireframe,
    );
  }

  @override
  bool shouldRepaint(covariant PaperPainter oldDelegate) => true;
}
