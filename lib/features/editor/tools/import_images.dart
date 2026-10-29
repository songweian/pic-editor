import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'pick_raw_images.dart';

export 'picked_image_bytes.dart';

class ImportedImage {
  const ImportedImage({
    required this.bytes,
    required this.size,
    required this.name,
  });

  final Uint8List bytes;
  final Size size;
  final String name;
}

Future<List<ImportedImage>> pickImportedImages() async {
  List<PickedImageBytes> picked;
  try {
    picked = await pickRawImages();
  } catch (error) {
    if (isPickerCancel(error)) return const [];
    if (error is ImportException) rethrow;
    throw const ImportException('无法打开图片选择器，请检查文件权限后重试');
  }
  return importedImagesFromPicked(picked);
}

Future<List<ImportedImage>> importedImagesFromPicked(
  List<PickedImageBytes> picked,
) async {
  if (picked.isEmpty) return const [];

  final result = <ImportedImage>[];
  for (final file in picked) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) continue;
    final size = await decodeImageSize(bytes);
    if (size == null) continue;
    result.add(
      ImportedImage(
        bytes: bytes,
        size: size,
        name: prettyImageName(file.name),
      ),
    );
  }
  if (result.isEmpty) {
    throw const ImportException('无法读取所选图片，请改选 PNG、JPEG、GIF 或 WebP');
  }
  return result;
}

Future<Size?> decodeImageSize(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  } catch (_) {
    return null;
  }
}

String prettyImageName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '图片';
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0) return trimmed;
  return trimmed.substring(0, dot);
}
