// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> savePng(Uint8List bytes, String filename) async {
  final blob = html.Blob(<dynamic>[bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  html.document.documentElement?.setAttribute('data-last-download', filename);
  html.document.documentElement
      ?.setAttribute('data-last-download-bytes', '${bytes.length}');
  anchor.click();
  await Future<void>.delayed(const Duration(milliseconds: 400));
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}
