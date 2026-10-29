import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pic_editor/app.dart';
import 'package:pic_editor/core/models/place_mode.dart';
import 'package:pic_editor/features/editor/editor_page.dart';
import 'package:pic_editor/features/editor/tools/import_images.dart';
import 'package:pic_editor/features/editor/tools/sample_image.dart';
import 'package:pic_editor/state/editor_controller.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('宽屏编辑器渲染纸张和图层面板', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    expect(find.text('纸张排版'), findsOneWidget);
    expect(find.textContaining('A4'), findsWidgets);
    expect(find.text('图层'), findsWidgets);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('示例图'), findsOneWidget);
    expect(find.textContaining('还没有图层'), findsOneWidget);
  });

  testWidgets('窄屏使用底栏和图层面板入口', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    expect(find.text('纸张排版'), findsOneWidget);
    expect(find.text('图层'), findsOneWidget);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('导入'), findsOneWidget);
  });

  testWidgets('导入有效图片后出现在图层列表', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    final controller =
        tester.element(find.byType(EditorPage)).read<EditorController>();
    final bytes = buildSamplePng(kSampleImages.first);
    final size = await tester.runAsync(() => decodeImageSize(bytes));
    expect(size, isNotNull);

    controller.addImportedImages([
      ImportedImage(bytes: bytes, size: size!, name: '导入测试'),
    ]);
    await tester.runAsync(controller.ensureDecoded);
    await tester.pump();

    expect(controller.layers, hasLength(1));
    expect(controller.decodedImages.containsKey(controller.selectedLayerId), isTrue);
    expect(find.text('导入测试'), findsWidgets);
    expect(find.textContaining('还没有图层'), findsNothing);
  });

  testWidgets('添加示例图、切换纸张、翻转方向', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    final controller =
        tester.element(find.byType(EditorPage)).read<EditorController>();

    await controller.addSampleImages();
    await tester.pump();

    expect(controller.layers.length, 2);
    expect(find.text('蓝示例'), findsWidgets);
    expect(find.text('暖示例'), findsWidgets);

    controller.setPaper('a3');
    await tester.pump();
    expect(controller.paper.id, 'a3');
    expect(controller.layers.length, 2);

    controller.toggleOrientation();
    await tester.pump();
    expect(controller.landscape, isTrue);
    expect(find.textContaining('横向'), findsWidgets);
  });

  testWidgets('点击示例图后可裁剪、翻转、撤销删除', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const PicEditorApp());
      await tester.pump();

      final controller =
          tester.element(find.byType(EditorPage)).read<EditorController>();
      await tester.tap(find.bySemanticsLabel('示例图'));
      await tester.pump();
      await tester.runAsync(controller.ensureDecoded);
      await tester.pump();

      expect(controller.layers.length, 2);
      expect(controller.canUndo, isTrue);

      final beforeFlip = controller.selectedImage!.scaleX;
      await tester.tap(find.bySemanticsLabel('水平翻转').first);
      await tester.pump();
      expect(controller.selectedImage!.scaleX, -beforeFlip);

      controller.enterCrop();
      await tester.pump();
      expect(find.text('裁剪图片'), findsOneWidget);
      controller.updateWorkingCrop(const Rect.fromLTWH(0.1, 0.1, 0.6, 0.6));
      controller.confirmCrop();
      await tester.pump();
      expect(controller.cropMode, isFalse);
      expect(controller.selectedImage!.cropRect, isNotNull);

      final remainingId = controller.layers.first.id;
      controller.deleteSelected();
      await tester.pump();
      expect(controller.layers.length, 1);
      expect(controller.layers.first.id, remainingId);

      controller.undo();
      await tester.pump();
      await tester.runAsync(controller.ensureDecoded);
      expect(controller.layers.length, 2);
      expect(
        controller.decodedImages.containsKey(controller.selectedLayerId),
        isTrue,
      );

      controller.applyPlaceMode(PlaceMode.fill);
      await tester.pump();
      final filled = controller.selectedImage!;
      final paper = controller.paperSizePx;
      expect(
        filled.displaySize.width >= paper.width - 0.5 ||
            filled.displaySize.height >= paper.height - 0.5,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('长按图层打开顺序菜单并可置于底层', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    final controller =
        tester.element(find.byType(EditorPage)).read<EditorController>();
    await controller.addSampleImages();
    await tester.pump();

    final topId = controller.layers.last.id;
    await tester.longPress(find.text('暖示例').first);
    await tester.pumpAndSettle();

    expect(find.text('上移一层'), findsOneWidget);
    expect(find.text('下移一层'), findsOneWidget);
    expect(find.text('置于顶层'), findsOneWidget);
    expect(find.text('置于底层'), findsOneWidget);

    await tester.tap(find.text('置于底层'));
    await tester.pumpAndSettle();
    expect(controller.layers.first.id, topId);
    expect(controller.isBottomLayer(topId), isTrue);
  });

  testWidgets('右键图层打开顺序菜单并可置于顶层', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PicEditorApp());
    await tester.pump();

    final controller =
        tester.element(find.byType(EditorPage)).read<EditorController>();
    await controller.addSampleImages();
    await tester.pump();

    final bottomId = controller.layers.first.id;
    await tester.tap(find.text('蓝示例').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('置于顶层'), findsOneWidget);
    await tester.tap(find.text('置于顶层'));
    await tester.pumpAndSettle();
    expect(controller.layers.last.id, bottomId);
    expect(controller.isTopLayer(bottomId), isTrue);
  });
}
