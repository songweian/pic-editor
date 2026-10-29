// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_bytes.dart';

const kImportFileInputId = 'pic-editor-import-input';

Future<List<PickedImageBytes>> pickRawImages() async {
  final seeded = html.document.getElementById(kImportFileInputId);
  if (seeded is html.FileUploadInputElement) {
    final files = _filesOf(seeded);
    if (files.isNotEmpty) {
      try {
        return await _readAll(files);
      } finally {
        seeded.value = '';
      }
    }
    seeded.remove();
  }

  final input = html.FileUploadInputElement()
    ..id = kImportFileInputId
    ..accept = 'image/png,image/jpeg,image/jpg,image/webp,image/gif,image/*'
    ..multiple = true
    ..style.display = 'none';

  final completer = Completer<List<html.File>?>();

  void finish(List<html.File>? files) {
    if (!completer.isCompleted) {
      completer.complete(files);
    }
  }

  input.onChange.listen((_) => finish(_filesOf(input)));
  input.addEventListener('cancel', (_) => finish(null));
  void onFocus(html.Event _) {
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!completer.isCompleted) finish(null);
    });
  }

  html.window.addEventListener('focus', onFocus);

  html.document.body!.append(input);

  try {
    input.click();
  } catch (_) {
    if (!completer.isCompleted) {
      throw const ImportException('无法打开图片选择器，请检查文件权限后重试');
    }
  }

  try {
    final files = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );
    if (files == null || files.isEmpty) return const [];
    return await _readAll(files);
  } on ImportException {
    rethrow;
  } catch (error) {
    if (isPickerCancel(error)) return const [];
    throw const ImportException('无法读取所选图片，请改选 PNG、JPEG、GIF 或 WebP');
  } finally {
    html.window.removeEventListener('focus', onFocus);
    input.remove();
  }
}

Future<List<PickedImageBytes>> _readAll(List<html.File> files) async {
  final result = <PickedImageBytes>[];
  for (final file in files) {
    result.add(
      PickedImageBytes(
        name: file.name,
        bytes: await _readBytes(file),
      ),
    );
  }
  return result;
}

List<html.File> _filesOf(html.FileUploadInputElement input) {
  final list = input.files;
  if (list == null || list.isEmpty) return const [];
  return List<html.File>.generate(list.length, (index) => list[index]);
}

Future<Uint8List?> _readBytes(html.File file) {
  if (file.size <= 0) return Future<Uint8List?>.value(Uint8List(0));

  final reader = html.FileReader();
  final done = Completer<Uint8List?>();
  reader.onError.listen((_) {
    if (!done.isCompleted) done.complete(null);
  });
  reader.onLoadEnd.listen((_) {
    if (done.isCompleted) return;
    try {
      done.complete(_asBytes(reader.result));
    } catch (_) {
      done.complete(null);
    }
  });
  reader.readAsArrayBuffer(file);
  return done.future;
}

Uint8List? _asBytes(Object? raw) {
  if (raw == null) return null;
  if (raw is Uint8List) return raw;
  if (raw is ByteBuffer) return Uint8List.view(raw);
  if (raw is TypedData) {
    return Uint8List.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes);
  }
  try {
    return Uint8List.fromList(List<int>.from(raw as Iterable<dynamic>));
  } catch (_) {
    return null;
  }
}
