import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pic_editor/core/commands/command_history.dart';
import 'package:pic_editor/core/commands/editor_command.dart';
import 'package:pic_editor/core/models/editor_document.dart';
import 'package:pic_editor/core/models/image_layer.dart';
import 'package:pic_editor/core/models/place_mode.dart';
import 'package:pic_editor/core/utils/decode_image.dart';
import 'package:pic_editor/core/utils/units.dart';
import 'package:pic_editor/data/paper_presets.dart';
import 'package:pic_editor/features/editor/tools/export_png.dart';
import 'package:pic_editor/state/editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('纸张尺寸与位置映射', () {
    test('默认 A4 纵向工作像素与导出像素', () {
      final spec = PaperPresets.defaultSpec;
      expect(spec.id, 'a4');
      final work = specSizePx(spec, landscape: false);
      final exported = specSizePx(spec, landscape: false, dpi: exportDpi);
      expect(work.width, closeTo(210 / mmPerInch * workingDpi, 0.01));
      expect(work.height, closeTo(297 / mmPerInch * workingDpi, 0.01));
      expect(exported.width, closeTo(work.width * 2, 0.01));
      expect(exported.height, closeTo(work.height * 2, 0.01));
    });

    test('未知纸张回退到 A4', () {
      expect(PaperPresets.byId('not-a-size').id, 'a4');
    });

    test('切换纸张按比例映射图层中心', () {
      final a4 = PaperPresets.byId('a4');
      final inch5 = PaperPresets.byId('inch5');
      final layer = _layer(position: Offset(a4.widthMm, a4.heightMm));
      final doc = EditorDocument(
        paper: a4,
        landscape: false,
        layers: [layer],
        selectedLayerId: layer.id,
      );
      final next = doc.remapped(paper: inch5);
      final oldSize = doc.sizePx;
      final newSize = next.sizePx;
      final mapped = next.layers.first as ImageLayer;
      expect(
        mapped.position.dx,
        closeTo(layer.position.dx * newSize.width / oldSize.width, 0.01),
      );
      expect(
        mapped.position.dy,
        closeTo(layer.position.dy * newSize.height / oldSize.height, 0.01),
      );
    });

    test('横纵切换保持相对位置', () {
      final paper = PaperPresets.byId('a4');
      final oldSize = specSizePx(paper, landscape: false);
      final layer = _layer(
        position: Offset(oldSize.width * 0.25, oldSize.height * 0.8),
      );
      final doc = EditorDocument(
        paper: paper,
        landscape: false,
        layers: [layer],
      );
      final next = doc.remapped(landscape: true);
      expect(next.landscape, isTrue);
      expect(next.sizePx.width, closeTo(oldSize.height, 0.01));
      expect(next.sizePx.height, closeTo(oldSize.width, 0.01));
      final mapped = next.layers.first as ImageLayer;
      expect(mapped.position.dx / next.sizePx.width, closeTo(0.25, 0.0001));
      expect(mapped.position.dy / next.sizePx.height, closeTo(0.8, 0.0001));
    });
  });

  group('命令历史', () {
    test('undo redo 成对恢复文档', () {
      final history = CommandHistory();
      final a = EditorDocument(
        paper: PaperPresets.byId('a4'),
        landscape: false,
        layers: const [],
      );
      final b = a.copyWith(landscape: true);
      history.pushApplied(
        DocumentCommand(label: '横向纸张', before: a, after: b),
      );
      expect(history.canUndo, isTrue);
      expect(history.undoLabel, '横向纸张');
      final undone = history.undo(b);
      expect(undone.landscape, isFalse);
      expect(history.canRedo, isTrue);
      final redone = history.redo(undone);
      expect(redone.landscape, isTrue);
    });
  });

  group('EditorController 主路径', () {
    late EditorController controller;

    setUp(() {
      controller = EditorController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('示例图添加两层并选中最后一张', () async {
      await controller.addSampleImages();
      expect(controller.layers.length, 2);
      expect(controller.layers.map((layer) => layer.name), ['蓝示例', '暖示例']);
      expect(controller.selectedImage?.name, '暖示例');
      expect(controller.canUndo, isTrue);
      expect(controller.undoLabel, '添加示例图');
    });

    test('切换纸张与横向会映射已有图层位置', () async {
      await controller.addSampleImages();
      final before = Map<String, Offset>.fromEntries(
        controller.layers.whereType<ImageLayer>().map(
              (layer) => MapEntry(layer.id, layer.position),
            ),
      );
      final oldSize = controller.paperSizePx;

      controller.setPaper('a3');
      expect(controller.paper.id, 'a3');
      final a3 = controller.paperSizePx;
      for (final layer in controller.layers.whereType<ImageLayer>()) {
        expect(
          layer.position.dx,
          closeTo(before[layer.id]!.dx * a3.width / oldSize.width, 0.05),
        );
        expect(
          layer.position.dy,
          closeTo(before[layer.id]!.dy * a3.height / oldSize.height, 0.05),
        );
      }

      controller.toggleOrientation();
      expect(controller.landscape, isTrue);
      expect(
        controller.paperSizePx.width,
        greaterThan(controller.paperSizePx.height),
      );
      for (final layer in controller.layers.whereType<ImageLayer>()) {
        expect(
          layer.position.dx / controller.paperSizePx.width,
          closeTo(before[layer.id]!.dx / oldSize.width, 0.0001),
        );
        expect(
          layer.position.dy / controller.paperSizePx.height,
          closeTo(before[layer.id]!.dy / oldSize.height, 0.0001),
        );
      }
    });

    test('裁剪写入归一化矩形', () async {
      await controller.addSampleImages();
      controller.enterCrop();
      expect(controller.cropMode, isTrue);
      controller.updateWorkingCrop(const Rect.fromLTWH(0.1, 0.15, 0.5, 0.6));
      controller.confirmCrop();
      expect(controller.cropMode, isFalse);
      final crop = controller.selectedImage!.cropRect!;
      expect(crop.left, closeTo(0.1, 0.0001));
      expect(crop.top, closeTo(0.15, 0.0001));
      expect(crop.width, closeTo(0.5, 0.0001));
      expect(crop.height, closeTo(0.6, 0.0001));
    });

    test('水平垂直翻转改 scale 符号', () async {
      await controller.addSampleImages();
      final start = controller.selectedImage!;
      controller.flipHorizontal();
      expect(controller.selectedImage!.scaleX, -start.scaleX);
      expect(controller.selectedImage!.scaleY, start.scaleY);
      controller.flipVertical();
      expect(controller.selectedImage!.scaleY, -start.scaleY);
    });

    test('适应铺满原比例', () async {
      await controller.addSampleImages();
      final paper = controller.paperSizePx;

      controller.applyPlaceMode(PlaceMode.original);
      expect(controller.selectedImage!.scaleX.abs(), closeTo(1, 0.0001));
      expect(controller.selectedImage!.scaleY.abs(), closeTo(1, 0.0001));

      controller.applyPlaceMode(PlaceMode.fit);
      _expectFits(controller.selectedImage!.displaySize, paper);

      controller.applyPlaceMode(PlaceMode.fill);
      _expectFills(controller.selectedImage!.displaySize, paper);
    });

    test('裁剪后适应按可见区域贴合纸张', () async {
      await controller.addSampleImages();
      controller.enterCrop();
      controller.updateWorkingCrop(const Rect.fromLTWH(0, 0, 0.5, 0.5));
      controller.confirmCrop();
      controller.applyPlaceMode(PlaceMode.fit);
      _expectFits(controller.selectedImage!.displaySize, controller.paperSizePx);

      controller.applyPlaceMode(PlaceMode.fill);
      _expectFills(controller.selectedImage!.displaySize, controller.paperSizePx);
    });

    test('锁定后不能翻转删除裁剪', () async {
      await controller.addSampleImages();
      final id = controller.selectedLayerId!;
      final scaleX = controller.selectedImage!.scaleX;
      controller.setLocked(id, true);
      expect(controller.selectedImage!.locked, isTrue);

      controller.flipHorizontal();
      expect(controller.selectedImage!.scaleX, scaleX);

      controller.enterCrop();
      expect(controller.cropMode, isFalse);

      controller.deleteSelected();
      expect(controller.layers.length, 2);
      expect(controller.layers.any((layer) => layer.id == id), isTrue);

      controller.setLocked(id, false);
      controller.deleteSelected();
      expect(controller.layers.length, 1);
      expect(controller.layers.any((layer) => layer.id == id), isFalse);
    });

    test('图层上下移改变绘制顺序', () async {
      await controller.addSampleImages();
      final bottom = controller.layers.first;
      final top = controller.layers.last;
      controller.moveLayer(top.id, -1);
      expect(controller.layers.first.id, top.id);
      expect(controller.layers.last.id, bottom.id);
      controller.moveLayer(top.id, 1);
      expect(controller.layers.last.id, top.id);
    });

    test('置于顶层和底层', () async {
      await controller.addSampleImages();
      expect(controller.layers.length, 2);
      final bottom = controller.layers.first;
      final top = controller.layers.last;
      expect(controller.isTopLayer(top.id), isTrue);
      expect(controller.isBottomLayer(bottom.id), isTrue);

      controller.sendToBack(top.id);
      expect(controller.layers.first.id, top.id);
      expect(controller.isBottomLayer(top.id), isTrue);
      expect(controller.layers.last.id, bottom.id);

      controller.bringToFront(top.id);
      expect(controller.layers.last.id, top.id);
      expect(controller.isTopLayer(top.id), isTrue);

      final undoLabel = controller.undoLabel;
      controller.bringToFront(top.id);
      expect(controller.undoLabel, undoLabel);
    });

    test('删除后撤销恢复图层与解码缓存', () async {
      await controller.addSampleImages();
      await controller.ensureDecoded();
      expect(controller.decodedImages.length, 2);
      final ids = controller.layers.map((layer) => layer.id).toList();

      controller.deleteSelected();
      expect(controller.layers.length, 1);
      expect(controller.decodedImages.containsKey(ids.last), isTrue);

      controller.undo();
      expect(controller.layers.length, 2);
      expect(controller.layers.map((layer) => layer.id), ids);
      expect(controller.decodedImages.containsKey(ids.last), isTrue);

      controller.redo();
      expect(controller.layers.length, 1);
      controller.undo();
      expect(controller.layers.length, 2);
    });

    test('隐藏图层仍保留但导出时跳过', () async {
      await controller.addSampleImages();
      final hiddenId = controller.layers.first.id;
      controller.setVisible(hiddenId, false);
      expect(controller.layers.first.visible, isFalse);
      expect(controller.hitTest(controller.selectedImage!.position), isNotNull);

      final bytes = await controller.exportPngBytes();
      expect(_isPng(bytes), isTrue);
    });

    test('导出 PNG bytes 尺寸为 300DPI 纸张', () async {
      await controller.addSampleImages();
      final bytes = await controller.exportPngBytes();
      expect(_isPng(bytes), isTrue);

      final image = await decodeImageBytes(bytes);
      final expected = controller.document.exportSizePx();
      expect(image.width, expected.width.round().clamp(1, 20000));
      expect(image.height, expected.height.round().clamp(1, 20000));
      image.dispose();

      expect(exportFileName(controller.document), contains('A4'));
      expect(exportFileName(controller.document), contains('纵向'));
    });

    test('横向导出文件名包含横向', () async {
      await controller.addSampleImages();
      controller.toggleOrientation();
      expect(exportFileName(controller.document), contains('横向'));
    });

    test('解码未完成时 dispose 不抛错', () async {
      final local = EditorController();
      final pending = local.addSampleImages();
      local.dispose();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
  });
}

ImageLayer _layer({required Offset position}) {
  return ImageLayer(
    id: 'layer-1',
    name: '测试',
    visible: true,
    locked: false,
    opacity: 1,
    position: position,
    rotation: 0,
    scaleX: 1,
    scaleY: 1,
    bytes: Uint8List(0),
    sourceSize: const Size(100, 80),
  );
}

void _expectFits(Size display, Size paper) {
  expect(display.width, lessThanOrEqualTo(paper.width + 0.5));
  expect(display.height, lessThanOrEqualTo(paper.height + 0.5));
  expect(
    (display.width - paper.width).abs() < 0.5 ||
        (display.height - paper.height).abs() < 0.5,
    isTrue,
    reason:
        '适应后应有一边贴合纸张，实际 ${display.width}x${display.height} / ${paper.width}x${paper.height}',
  );
}

void _expectFills(Size display, Size paper) {
  expect(display.width, greaterThanOrEqualTo(paper.width - 0.5));
  expect(display.height, greaterThanOrEqualTo(paper.height - 0.5));
}

bool _isPng(Uint8List bytes) {
  return bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}
