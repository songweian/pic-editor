import 'package:flutter/material.dart';

import '../../../core/models/image_layer.dart';
import 'selection_overlay.dart';

enum CropHandle { nw, n, ne, e, se, s, sw, w, move }

class CropOverlay extends StatelessWidget {
  const CropOverlay({
    super.key,
    required this.layer,
    required this.crop,
    required this.viewScale,
  });

  final ImageLayer layer;
  final Rect crop;
  final double viewScale;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CropPainter(
          layer: layer,
          crop: crop,
          viewScale: viewScale,
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.layer,
    required this.crop,
    required this.viewScale,
  });

  final ImageLayer layer;
  final Rect crop;
  final double viewScale;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final size = layer.displaySize;
    canvas.save();
    canvas.translate(layer.position.dx, layer.position.dy);
    canvas.rotate(layer.rotation);

    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final cropRect = Rect.fromLTWH(
      bounds.left + crop.left * bounds.width,
      bounds.top + crop.top * bounds.height,
      crop.width * bounds.width,
      crop.height * bounds.height,
    );

    final dim = Path()
      ..addRect(bounds)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / viewScale
      ..color = kHandleColor;
    canvas.drawRect(cropRect, stroke);

    const thirds = [1 / 3, 2 / 3];
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / viewScale
      ..color = Colors.white.withOpacity(0.35);
    for (final t in thirds) {
      canvas.drawLine(
        Offset(cropRect.left + cropRect.width * t, cropRect.top),
        Offset(cropRect.left + cropRect.width * t, cropRect.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + cropRect.height * t),
        Offset(cropRect.right, cropRect.top + cropRect.height * t),
        grid,
      );
    }

    final handle = 9 / viewScale;
    final fill = Paint()..color = const Color(0xFF1C1E22);
    for (final point in cropHandlePoints(cropRect)) {
      final rect = Rect.fromCenter(center: point, width: handle, height: handle);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}

List<Offset> cropHandlePoints(Rect cropRect) {
  return [
    cropRect.topLeft,
    Offset(cropRect.center.dx, cropRect.top),
    cropRect.topRight,
    Offset(cropRect.right, cropRect.center.dy),
    cropRect.bottomRight,
    Offset(cropRect.center.dx, cropRect.bottom),
    cropRect.bottomLeft,
    Offset(cropRect.left, cropRect.center.dy),
  ];
}

CropHandle? hitCropHandle({
  required ImageLayer layer,
  required Rect crop,
  required Offset paperPoint,
  required double viewScale,
}) {
  final size = layer.displaySize;
  final bounds = Rect.fromCenter(
    center: Offset.zero,
    width: size.width,
    height: size.height,
  );
  final cropRect = Rect.fromLTWH(
    bounds.left + crop.left * bounds.width,
    bounds.top + crop.top * bounds.height,
    crop.width * bounds.width,
    crop.height * bounds.height,
  );
  final local = layer.toLocal(paperPoint);
  final threshold = 14 / viewScale;
  const kinds = [
    CropHandle.nw,
    CropHandle.n,
    CropHandle.ne,
    CropHandle.e,
    CropHandle.se,
    CropHandle.s,
    CropHandle.sw,
    CropHandle.w,
  ];
  final points = cropHandlePoints(cropRect);
  var best = threshold;
  CropHandle? found;
  for (var i = 0; i < kinds.length; i++) {
    final dist = (local - points[i]).distance;
    if (dist <= best) {
      best = dist;
      found = kinds[i];
    }
  }
  if (found != null) return found;
  if (cropRect.inflate(threshold).contains(local)) {
    return CropHandle.move;
  }
  return null;
}

Rect applyCropHandle({
  required Rect start,
  required CropHandle handle,
  required Offset localDelta,
  required Size displaySize,
}) {
  final dx = localDelta.dx / displaySize.width;
  final dy = localDelta.dy / displaySize.height;
  var left = start.left;
  var top = start.top;
  var right = start.right;
  var bottom = start.bottom;

  void moveX(bool startEdge) {
    if (startEdge) {
      left += dx;
    } else {
      right += dx;
    }
  }

  void moveY(bool startEdge) {
    if (startEdge) {
      top += dy;
    } else {
      bottom += dy;
    }
  }

  switch (handle) {
    case CropHandle.nw:
      moveX(true);
      moveY(true);
      break;
    case CropHandle.n:
      moveY(true);
      break;
    case CropHandle.ne:
      moveX(false);
      moveY(true);
      break;
    case CropHandle.e:
      moveX(false);
      break;
    case CropHandle.se:
      moveX(false);
      moveY(false);
      break;
    case CropHandle.s:
      moveY(false);
      break;
    case CropHandle.sw:
      moveX(true);
      moveY(false);
      break;
    case CropHandle.w:
      moveX(true);
      break;
    case CropHandle.move:
      left += dx;
      right += dx;
      top += dy;
      bottom += dy;
      if (left < 0) {
        right -= left;
        left = 0;
      }
      if (top < 0) {
        bottom -= top;
        top = 0;
      }
      if (right > 1) {
        left -= right - 1;
        right = 1;
      }
      if (bottom > 1) {
        top -= bottom - 1;
        bottom = 1;
      }
      break;
  }

  return Rect.fromLTRB(left, top, right, bottom);
}
