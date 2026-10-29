import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> savePng(Uint8List bytes, String filename) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  final path = await FilePicker.platform.saveFile(
    dialogTitle: '导出 PNG',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['png'],
  );
  if (path == null) return null;
  final outPath = path.toLowerCase().endsWith('.png') ? path : '$path.png';
  await File(outPath).writeAsBytes(bytes);
  return outPath;
}
