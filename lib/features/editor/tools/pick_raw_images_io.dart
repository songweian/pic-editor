import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'picked_image_bytes.dart';

Future<List<PickedImageBytes>> pickRawImages() async {
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
    return _pickWithImagePicker();
  }
  return _pickWithFilePicker();
}

Future<List<PickedImageBytes>> _pickWithImagePicker() async {
  try {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return const [];
    final result = <PickedImageBytes>[];
    for (final file in files) {
      Uint8List? bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        bytes = null;
      }
      result.add(PickedImageBytes(name: file.name, bytes: bytes));
    }
    return result;
  } catch (error) {
    if (isPickerCancel(error)) return const [];
    throw const ImportException('无法打开图片选择器，请检查文件权限后重试');
  }
}

Future<List<PickedImageBytes>> _pickWithFilePicker() async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return const [];

    final result = <PickedImageBytes>[];
    for (final file in picked.files) {
      result.add(
        PickedImageBytes(
          name: file.name,
          bytes: await _bytesOf(file),
        ),
      );
    }
    return result;
  } catch (error) {
    if (isPickerCancel(error)) return const [];
    throw const ImportException('无法打开图片选择器，请检查文件权限后重试');
  }
}

Future<Uint8List?> _bytesOf(PlatformFile file) async {
  final inline = file.bytes;
  if (inline != null && inline.isNotEmpty) return inline;

  final path = file.path;
  if (path == null || path.isEmpty) return inline;

  try {
    final ioFile = File(path);
    if (await ioFile.exists()) {
      final bytes = await ioFile.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
  } catch (_) {}
  return inline;
}
