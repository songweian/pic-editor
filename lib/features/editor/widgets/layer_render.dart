import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/adjustment_layer.dart';
import '../../../core/models/editor_layer.dart';
import '../../../core/models/group_layer.dart';
import '../../../core/models/image_layer.dart';
import '../../../core/models/layer_mask.dart';
import '../../../core/models/layer_tree.dart';

ColorFilter adjustmentFilter({
  required double brightness,
  required double contrast,
}) {
  final c = 1 + contrast;
  final b = brightness * 255;
  final t = (1 - c) * 128;
  return ColorFilter.matrix(<double>[
    c,
    0,
    0,
    0,
    b + t,
    0,
    c,
    0,
    0,
    b + t,
    0,
    0,
    c,
    0,
    b + t,
    0,
    0,
    0,
    1,
    0,
  ]);
}

void paintImageLayer(
  Canvas canvas,
  ImageLayer layer,
  ui.Image image, {
  double opacityMul = 1,
  bool wireframe = false,
  double extraBrightness = 0,
  double extraContrast = 0,
}) {
  final opacity = (layer.opacity * opacityMul).clamp(0.0, 1.0);
  if (opacity <= 0) return;
  if (wireframe) {
    final bounds = layer.paperBounds;
    canvas.drawRect(
      bounds,
      Paint()
        ..color = const Color(0xFFE8C36A).withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    return;
  }

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
    ..color = Color.fromRGBO(255, 255, 255, opacity)
    ..colorFilter = adjustmentFilter(
      brightness: (layer.brightness + extraBrightness).clamp(-1.0, 1.0),
      contrast: (layer.contrast + extraContrast).clamp(-1.0, 1.0),
    );
  canvas.saveLayer(dst, paint);
  canvas.drawImageRect(
    image,
    src,
    dst,
    Paint()..filterQuality = FilterQuality.high,
  );
  final mask = layer.mask;
  if (mask != null && mask.enabled) {
    _stampMask(canvas, layer, mask, dst);
  }
  canvas.restore();
  canvas.restore();
}

void _stampMask(Canvas canvas, ImageLayer layer, LayerMask mask, Rect dst) {
  for (var y = 0; y < mask.height; y++) {
    for (var x = 0; x < mask.width; x++) {
      final a = mask.pixels[y * mask.width + x];
      if (a >= 250) continue;
      final cell = Rect.fromLTWH(
        dst.left + dst.width * x / mask.width,
        dst.top + dst.height * y / mask.height,
        dst.width / mask.width + 0.5,
        dst.height / mask.height + 0.5,
      );
      canvas.drawRect(
        cell,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 1 - a / 255)
          ..blendMode = BlendMode.dstOut,
      );
    }
  }
}

StackedAdjustment collectAdjustments(
    List<EditorLayer> siblings, int imageIndex) {
  var brightness = 0.0;
  var contrast = 0.0;
  for (var i = imageIndex + 1; i < siblings.length; i++) {
    final layer = siblings[i];
    if (layer is! AdjustmentLayer || !layer.visible) continue;
    if (!layer.clipToBelow) continue;
    switch (layer.kind) {
      case AdjustmentKind.brightness:
        brightness += layer.amount * layer.opacity;
        break;
      case AdjustmentKind.contrast:
        contrast += layer.amount * layer.opacity;
        break;
    }
  }
  return StackedAdjustment(brightness: brightness, contrast: contrast);
}

class StackedAdjustment {
  const StackedAdjustment({
    required this.brightness,
    required this.contrast,
  });

  final double brightness;
  final double contrast;
}

void paintLayerTree(
  Canvas canvas,
  Size size, {
  required List<EditorLayer> layers,
  required Map<String, ui.Image> images,
  String? isolationId,
  bool wireframe = false,
}) {
  final isolated = isolatedSubtreeIds(layers, isolationId);
  _paintList(
    canvas,
    size,
    layers: layers,
    images: images,
    isolated: isolated,
    isolating: isolationId != null,
    wireframe: wireframe,
    opacityMul: 1,
  );
}

void _paintList(
  Canvas canvas,
  Size size, {
  required List<EditorLayer> layers,
  required Map<String, ui.Image> images,
  required Set<String> isolated,
  required bool isolating,
  required bool wireframe,
  required double opacityMul,
}) {
  for (var i = 0; i < layers.length; i++) {
    final layer = layers[i];
    if (!layer.visible) continue;
    final active = !isolating || isolated.contains(layer.id);
    final dim = active ? opacityMul : opacityMul * 0.2;
    if (layer is GroupLayer) {
      if (layer.passThrough) {
        _paintList(
          canvas,
          size,
          layers: layer.children,
          images: images,
          isolated: isolated,
          isolating: isolating,
          wireframe: wireframe,
          opacityMul: dim * layer.opacity,
        );
      } else {
        final bounds = layerBounds(layer) ?? (Offset.zero & size);
        canvas.saveLayer(
          bounds.inflate(8),
          Paint()..color = Color.fromRGBO(255, 255, 255, dim * layer.opacity),
        );
        _paintList(
          canvas,
          size,
          layers: layer.children,
          images: images,
          isolated: isolated,
          isolating: false,
          wireframe: wireframe,
          opacityMul: 1,
        );
        canvas.restore();
      }
      continue;
    }
    if (layer is ImageLayer) {
      final image = images[layer.id];
      if (image == null) continue;
      final adj = collectAdjustments(layers, i);
      if (layer.clipToBelow && i > 0) {
        final clipBounds = layerBounds(layers[i - 1]);
        if (clipBounds != null) canvas.save();
        if (clipBounds != null) canvas.clipRect(clipBounds);
        paintImageLayer(
          canvas,
          layer,
          image,
          opacityMul: dim,
          wireframe: wireframe,
          extraBrightness: adj.brightness,
          extraContrast: adj.contrast,
        );
        if (clipBounds != null) canvas.restore();
      } else {
        paintImageLayer(
          canvas,
          layer,
          image,
          opacityMul: dim,
          wireframe: wireframe,
          extraBrightness: adj.brightness,
          extraContrast: adj.contrast,
        );
      }
    }
  }
}
