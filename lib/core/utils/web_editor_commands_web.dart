// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import '../../features/editor/tools/import_images.dart';
import '../../features/editor/tools/sample_image.dart';
import '../../state/editor_controller.dart';
import '../models/adjustment_layer.dart';
import '../models/group_layer.dart';
import '../models/image_layer.dart';
import '../models/place_mode.dart';

html.EventListener? _listener;

void bindWebEditorCommands({
  required EditorController Function() controller,
  required void Function() openLayers,
  required Future<void> Function() importImages,
  required Future<void> Function() exportPng,
}) {
  unbindWebEditorCommands();
  _listener = (html.Event event) {
    final name = '${(event as html.CustomEvent).detail}';
    final root = html.document.documentElement;
    root?.setAttribute('data-last-command', name);
    root?.removeAttribute('data-last-command-error');
    root?.setAttribute('data-last-command-status', 'running');
    final editor = controller();
    Future<void>(() async {
      try {
        await _handle(
          name,
          controller: editor,
          openLayers: openLayers,
          importImages: importImages,
          exportPng: exportPng,
        );
        root?.setAttribute('data-last-command-status', 'ok');
      } catch (error) {
        root?.setAttribute('data-last-command-error', '$error');
        root?.setAttribute('data-last-command-status', 'error');
      } finally {
        _writeState(editor);
      }
    });
  };
  html.window.addEventListener('pic-editor-command', _listener);
  html.window.document.documentElement?.setAttribute(
    'data-pic-editor-ready',
    '1',
  );
  _writeState(controller());
}

void unbindWebEditorCommands() {
  final listener = _listener;
  if (listener != null) {
    html.window.removeEventListener('pic-editor-command', listener);
    _listener = null;
  }
}

void _writeState(EditorController controller) {
  final root = html.document.documentElement;
  if (root == null) return;
  root.setAttribute('data-layer-count', '${controller.layers.length}');
  root.setAttribute('data-decoded-count', '${controller.decodedImages.length}');
  root.setAttribute('data-paper', controller.paper.id);
  root.setAttribute('data-landscape', controller.landscape ? '1' : '0');
  root.setAttribute('data-crop', controller.cropMode ? '1' : '0');
  root.setAttribute('data-selected', controller.selectedLayerId ?? '');
  root.setAttribute('data-can-undo', controller.canUndo ? '1' : '0');
  root.setAttribute('data-isolating', controller.isolating ? '1' : '0');
  root.setAttribute(
    'data-breadcrumb',
    controller.isolating
        ? ['主画布', ...controller.breadcrumbNames].join(' > ')
        : '',
  );
  root.setAttribute(
    'data-clip',
    controller.selectedLayer?.clipToBelow == true ? '1' : '0',
  );
  final selected = controller.selectedLayer;
  root.setAttribute(
    'data-grouped',
    selected is GroupLayer ? '1' : '0',
  );
  root.setAttribute(
    'data-masked',
    selected is ImageLayer && selected.mask != null ? '1' : '0',
  );
}

Future<void> _handle(
  String name, {
  required EditorController controller,
  required void Function() openLayers,
  required Future<void> Function() importImages,
  required Future<void> Function() exportPng,
}) async {
  switch (name) {
    case 'sample':
      await controller.addSampleImages();
      await controller.ensureDecoded();
      break;
    case 'import':
      await importImages();
      await controller.ensureDecoded();
      break;
    case 'import-demo':
      await _importDemo(controller);
      break;
    case 'paper-a3':
      controller.setPaper('a3');
      break;
    case 'paper-inch6':
      controller.setPaper('inch6');
      break;
    case 'orientation':
      controller.toggleOrientation();
      break;
    case 'fit':
      controller.applyPlaceMode(PlaceMode.fit);
      break;
    case 'fill':
      controller.applyPlaceMode(PlaceMode.fill);
      break;
    case 'original':
      controller.applyPlaceMode(PlaceMode.original);
      break;
    case 'flip-h':
      controller.flipHorizontal();
      break;
    case 'flip-v':
      controller.flipVertical();
      break;
    case 'crop':
      controller.enterCrop();
      break;
    case 'crop-done':
      controller.confirmCrop();
      break;
    case 'crop-cancel':
      controller.cancelCrop();
      break;
    case 'delete':
      controller.deleteSelected();
      break;
    case 'undo':
      controller.undo();
      await controller.ensureDecoded();
      break;
    case 'redo':
      controller.redo();
      await controller.ensureDecoded();
      break;
    case 'layers':
      openLayers();
      break;
    case 'layer-up':
      _moveSelected(controller, 1);
      break;
    case 'layer-down':
      _moveSelected(controller, -1);
      break;
    case 'layer-front':
      final frontId = controller.selectedLayerId;
      if (frontId != null) controller.bringToFront(frontId);
      break;
    case 'layer-back':
      final backId = controller.selectedLayerId;
      if (backId != null) controller.sendToBack(backId);
      break;
    case 'export':
      await exportPng();
      break;
    case 'group':
      controller.groupSelected();
      break;
    case 'ungroup':
      controller.ungroupSelected();
      break;
    case 'isolate':
      final isolateId = controller.selectedLayerId;
      if (isolateId != null) controller.isolateLayer(isolateId);
      break;
    case 'exit-isolate':
      controller.exitIsolation();
      break;
    case 'mask':
      controller.addMaskToSelected();
      break;
    case 'clip':
      controller.clipSelectedToBelow();
      break;
    case 'reset-layer':
      controller.resetLayer();
      break;
    case 'rasterize':
      await controller.rasterizeSelected();
      break;
    case 'adjustment':
      controller.addAdjustment(AdjustmentKind.brightness);
      break;
  }
}

void _moveSelected(EditorController controller, int delta) {
  final id = controller.selectedLayerId;
  if (id == null) return;
  controller.moveLayer(id, delta);
}

Future<void> _importDemo(EditorController controller) async {
  final bytes = buildSamplePng(kSampleImages.first);
  final size = await decodeImageSize(bytes);
  if (size == null) {
    throw const ImportException('无法读取所选图片，请改选 PNG、JPEG、GIF 或 WebP');
  }
  controller.addImportedImages([
    ImportedImage(bytes: bytes, size: size, name: '导入测试'),
  ]);
  await controller.ensureDecoded();
}
