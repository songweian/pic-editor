import 'dart:typed_data';

class PickedImageBytes {
  const PickedImageBytes({required this.name, this.bytes});

  final String name;
  final Uint8List? bytes;
}

class ImportException implements Exception {
  const ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isPickerCancel(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('cancel') ||
      text.contains('abort') ||
      text.contains('user_cancelled') ||
      text.contains('usercanceled');
}

String? importSuccessMessage(int count) {
  if (count <= 0) return null;
  return '已导入 $count 张图片';
}

String importErrorMessage(Object error) {
  if (isPickerCancel(error)) return '';
  if (error is ImportException) return error.message;
  return '导入失败，请换一张图片后重试';
}
