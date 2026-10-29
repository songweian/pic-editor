import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/editor_document.dart';
import '../../../core/utils/units.dart';
import '../widgets/paper_surface.dart';

Future<Uint8List> exportDocumentPng({
  required EditorDocument document,
  required Map<String, ui.Image> images,
}) async {
  final size = document.exportSizePx();
  final width = size.width.round().clamp(1, 20000);
  final height = size.height.round().clamp(1, 20000);
  const scale = exportDpi / workingDpi;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Offset.zero & Size(width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );
  canvas.scale(scale);

  paintLayerTree(
    canvas,
    Size(width / scale, height / scale),
    layers: document.layers,
    images: images,
  );

  final picture = recorder.endRecording();
  final out = await picture.toImage(width, height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  picture.dispose();
  if (data == null) {
    throw StateError('无法编码 PNG');
  }
  return data.buffer.asUint8List();
}

String exportFileName(EditorDocument document) {
  final stamp = DateTime.now();
  final mm =
      '${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}';
  final tt =
      '${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}';
  final orient = document.landscape ? '横向' : '纵向';
  return '${document.paper.label}_$orient${mm}_$tt.png';
}
