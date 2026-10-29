import 'package:flutter/material.dart';

import '../../../core/models/image_layer.dart';
import '../../../state/editor_controller.dart';

const Color kHandleColor = Color(0xFFE2C48A);

class LayerSelectionOverlay extends StatelessWidget {
  const LayerSelectionOverlay({
    super.key,
    required this.layer,
    required this.viewScale,
  });

  final ImageLayer layer;
  final double viewScale;

  @override
  Widget build(BuildContext context) {
    final size = layer.displaySize;
    return IgnorePointer(
      child: CustomPaint(
        painter: _SelectionPainter(
          layer: layer,
          viewScale: viewScale,
          size: size,
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter({
    required this.layer,
    required this.viewScale,
    required this.size,
  });

  final ImageLayer layer;
  final double viewScale;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / viewScale
      ..color = kHandleColor;
    final fill = Paint()..color = const Color(0xFF1C1E22);

    canvas.save();
    canvas.translate(layer.position.dx, layer.position.dy);
    canvas.rotate(layer.rotation);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height),
      stroke,
    );

    final handle = 9 / viewScale;
    for (final point in handlePoints(size)) {
      final rect = Rect.fromCenter(
        center: point,
        width: handle,
        height: handle,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }

    final rotateCenter = Offset(0, -size.height / 2 - 26 / viewScale);
    canvas.drawLine(
      Offset(0, -size.height / 2),
      rotateCenter,
      stroke,
    );
    canvas.drawCircle(rotateCenter, 7 / viewScale, fill);
    canvas.drawCircle(rotateCenter, 7 / viewScale, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) => true;
}

List<Offset> handlePoints(Size size) {
  final hw = size.width / 2;
  final hh = size.height / 2;
  return [
    Offset(-hw, -hh),
    Offset(0, -hh),
    Offset(hw, -hh),
    Offset(hw, 0),
    Offset(hw, hh),
    Offset(0, hh),
    Offset(-hw, hh),
    Offset(-hw, 0),
  ];
}

Offset rotateHandleLocal(Size size, double viewScale) {
  return Offset(0, -size.height / 2 - 26 / viewScale);
}

HandleKind? hitHandle({
  required ImageLayer layer,
  required Offset paperPoint,
  required double viewScale,
}) {
  final local = layer.toLocal(paperPoint);
  final size = layer.displaySize;
  final threshold = 14 / viewScale;
  final rotate = rotateHandleLocal(size, viewScale);
  if ((local - rotate).distance <= threshold) {
    return HandleKind.rotate;
  }
  const kinds = [
    HandleKind.nw,
    HandleKind.n,
    HandleKind.ne,
    HandleKind.e,
    HandleKind.se,
    HandleKind.s,
    HandleKind.sw,
    HandleKind.w,
  ];
  final points = handlePoints(size);
  var best = threshold;
  HandleKind? found;
  for (var i = 0; i < kinds.length; i++) {
    final dist = (local - points[i]).distance;
    if (dist <= best) {
      best = dist;
      found = kinds[i];
    }
  }
  return found;
}

double selectionHandleThreshold(double viewScale) => 14 / viewScale;

