import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'editor_layer.dart';

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

  Rect get normalizedCrop =>
      cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);

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
    );
  }

  @override
  EditorLayer copyLayer({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
  }) {
    return copyWith(
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
    );
  }
}
