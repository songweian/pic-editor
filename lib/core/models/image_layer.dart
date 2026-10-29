import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'editor_layer.dart';
import 'layer_mask.dart';

class ImageLayer implements EditorLayer {
  const ImageLayer({
    required this.id,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    required this.position,
    required this.rotation,
    required this.scaleX,
    required this.scaleY,
    required this.bytes,
    required this.sourceSize,
    this.cropRect,
    this.clipToBelow = false,
    this.mask,
    this.brightness = 0,
    this.contrast = 0,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final bool visible;
  @override
  final bool locked;
  @override
  final double opacity;

  /// Center of the layer on the paper, in working-DPI pixels.
  final Offset position;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final Uint8List bytes;
  final Size sourceSize;

  /// Normalized crop on the source image, `null` means the full image.
  final Rect? cropRect;
  @override
  final bool clipToBelow;
  final LayerMask? mask;

  /// Built-in non-destructive adjustments, -1 .. 1.
  final double brightness;
  final double contrast;

  Rect get normalizedCrop => cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);

  Size get croppedSourceSize {
    final crop = normalizedCrop;
    return Size(sourceSize.width * crop.width, sourceSize.height * crop.height);
  }

  Size get displaySize {
    final src = croppedSourceSize;
    return Size(src.width * scaleX.abs(), src.height * scaleY.abs());
  }

  Offset toLocal(Offset paperPoint) {
    final delta = paperPoint - position;
    final c = math.cos(-rotation);
    final s = math.sin(-rotation);
    return Offset(delta.dx * c - delta.dy * s, delta.dx * s + delta.dy * c);
  }

  Offset toPaper(Offset localPoint) {
    final c = math.cos(rotation);
    final s = math.sin(rotation);
    return position +
        Offset(
          localPoint.dx * c - localPoint.dy * s,
          localPoint.dx * s + localPoint.dy * c,
        );
  }

  bool containsPaperPoint(Offset paperPoint) {
    final local = toLocal(paperPoint);
    final size = displaySize;
    return local.dx.abs() <= size.width / 2 &&
        local.dy.abs() <= size.height / 2;
  }

  Rect get paperBounds {
    final size = displaySize;
    final half = Offset(size.width / 2, size.height / 2);
    final corners = <Offset>[
      toPaper(Offset(-half.dx, -half.dy)),
      toPaper(Offset(half.dx, -half.dy)),
      toPaper(Offset(half.dx, half.dy)),
      toPaper(Offset(-half.dx, half.dy)),
    ];
    var minX = corners.first.dx;
    var maxX = corners.first.dx;
    var minY = corners.first.dy;
    var maxY = corners.first.dy;
    for (final corner in corners) {
      minX = math.min(minX, corner.dx);
      maxX = math.max(maxX, corner.dx);
      minY = math.min(minY, corner.dy);
      maxY = math.max(maxY, corner.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  ImageLayer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    Offset? position,
    double? rotation,
    double? scaleX,
    double? scaleY,
    Uint8List? bytes,
    Size? sourceSize,
    Rect? cropRect,
    bool clearCrop = false,
    bool? clipToBelow,
    LayerMask? mask,
    bool clearMask = false,
    double? brightness,
    double? contrast,
  }) {
    return ImageLayer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      bytes: bytes ?? this.bytes,
      sourceSize: sourceSize ?? this.sourceSize,
      cropRect: clearCrop ? null : (cropRect ?? this.cropRect),
      clipToBelow: clipToBelow ?? this.clipToBelow,
      mask: clearMask ? null : (mask ?? this.mask),
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
    );
  }

  @override
  EditorLayer copyLayer({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    bool? clipToBelow,
  }) {
    return copyWith(
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
      clipToBelow: clipToBelow,
    );
  }
}
