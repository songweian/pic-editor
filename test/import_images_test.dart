import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pic_editor/core/models/place_mode.dart';
import 'package:pic_editor/core/utils/decode_image.dart';
import 'package:pic_editor/core/utils/ids.dart';
import 'package:pic_editor/features/editor/tools/import_images.dart';
import 'package:pic_editor/features/editor/tools/sample_image.dart';
import 'package:pic_editor/state/editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List validPng() => buildSamplePng(kSampleImages.first);

  group('图层 id', () {
    test('web 安全范围内可生成且不重复', () {
      expect(kIdRandomMax, greaterThan(0));
      expect(kIdRandomMax, lessThanOrEqualTo(0x7fffffff));
      final ids = <String>{for (var i = 0; i < 200; i++) newId()};
      expect(ids.length, 200);
    });
  });

  group('导入结果文案', () {
    test('取消或未选文件不提示', () {
      expect(importSuccessMessage(0), isNull);
      expect(isPickerCancel(Exception('User cancelled')), isTrue);
      expect(isPickerCancel(Exception('aborted by user')), isTrue);
      expect(importErrorMessage(Exception('User cancelled')), isEmpty);
    });

    test('失败给出中文提示而不是原始异常', () {
      expect(
        importErrorMessage(
            const ImportException('无法读取所选图片，请改选 PNG、JPEG、GIF 或 WebP')),
        '无法读取所选图片，请改选 PNG、JPEG、GIF 或 WebP',
      );
      expect(
        importErrorMessage(
            Exception('type ByteBuffer is not a subtype of Uint8List')),
        '导入失败，请换一张图片后重试',
      );
    });
  });

  group('importedImagesFromPicked', () {
    test('空列表视为取消，不报错', () async {
      expect(await importedImagesFromPicked(const []), isEmpty);
    });

    test('有效 PNG 可解码并保留文件名', () async {
      final bytes = validPng();
      final images = await importedImagesFromPicked([
        PickedImageBytes(name: '封面.png', bytes: bytes),
      ]);
      expect(images, hasLength(1));
      expect(images.single.name, '封面');
      expect(images.single.bytes, bytes);
      expect(images.single.size.width, kSampleImages.first.width);
      expect(images.single.size.height, kSampleImages.first.height);
    });

    test('空字节与无法解码的数据给出中文错误', () async {
      await expectLater(
        importedImagesFromPicked([
          PickedImageBytes(name: 'empty.png', bytes: Uint8List(0)),
        ]),
        throwsA(
          isA<ImportException>().having(
            (error) => error.message,
            'message',
            contains('无法读取所选图片'),
          ),
        ),
      );

      await expectLater(
        importedImagesFromPicked([
          PickedImageBytes(
              name: 'bad.png', bytes: Uint8List.fromList([1, 2, 3, 4])),
          const PickedImageBytes(name: 'missing.png'),
        ]),
        throwsA(isA<ImportException>()),
      );
    });

    test('部分失败时仍导入可读的图片', () async {
      final images = await importedImagesFromPicked([
        PickedImageBytes(name: 'bad.bin', bytes: Uint8List.fromList([0, 1, 2])),
        PickedImageBytes(name: 'ok.png', bytes: validPng()),
        const PickedImageBytes(name: 'missing.jpg'),
      ]);
      expect(images, hasLength(1));
      expect(images.single.name, 'ok');
    });
  });

  group('decodeImageSize', () {
    test('空数据返回 null，不挂起', () async {
      expect(await decodeImageSize(Uint8List(0)), isNull);
    });

    test('有效 PNG 返回宽高', () async {
      final size = await decodeImageSize(validPng());
      expect(size, isNotNull);
      expect(size!.width, kSampleImages.first.width);
      expect(size.height, kSampleImages.first.height);
    });

    test('乱码数据立刻返回 null，不走 Flutter codec', () async {
      final started = DateTime.now();
      expect(
        await decodeImageSize(Uint8List.fromList([0, 1, 2, 3, 4, 5])),
        isNull,
      );
      expect(DateTime.now().difference(started).inMilliseconds, lessThan(500));
    });
  });

  group('decodeImageBytes', () {
    test('示例 PNG 解成可绘制的 ui.Image', () async {
      final image = await decodeImageBytes(validPng());
      expect(image.width, kSampleImages.first.width);
      expect(image.height, kSampleImages.first.height);
      image.dispose();
    });

    test('空数据与坏数据抛错', () async {
      await expectLater(
        decodeImageBytes(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        decodeImageBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('EditorController.addImportedImages', () {
    late EditorController controller;

    setUp(() {
      controller = EditorController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('取消选择不改文档', () {
      expect(controller.addImportedImages(const []), 0);
      expect(controller.layers, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('有效图片放到纸面并选中', () async {
      final bytes = validPng();
      final size = await decodeImageSize(bytes);
      final count = controller.addImportedImages([
        ImportedImage(bytes: bytes, size: size!, name: '测试图'),
      ]);
      expect(count, 1);
      expect(controller.layers, hasLength(1));
      final layer = controller.selectedImage!;
      expect(layer.name, '测试图');
      expect(layer.bytes, bytes);
      expect(
        layer.displaySize.width,
        lessThanOrEqualTo(controller.paperSizePx.width + 0.5),
      );
      expect(
        layer.displaySize.height,
        lessThanOrEqualTo(controller.paperSizePx.height + 0.5),
      );
      expect(controller.undoLabel, '导入图片');
      await controller.ensureDecoded();
      expect(controller.decodedImages.containsKey(layer.id), isTrue);
      expect(
        controller.decodedImages[layer.id]!.width,
        kSampleImages.first.width,
      );
    });

    test('多张按适应放到纸面', () async {
      final first = validPng();
      final second = buildSamplePng(kSampleImages.last);
      final count = controller.addImportedImages([
        ImportedImage(
          bytes: first,
          size: (await decodeImageSize(first))!,
          name: '一',
        ),
        ImportedImage(
          bytes: second,
          size: (await decodeImageSize(second))!,
          name: '二',
        ),
      ], mode: PlaceMode.fit);
      expect(count, 2);
      expect(controller.layers.map((layer) => layer.name), ['一', '二']);
      expect(controller.selectedImage?.name, '二');
      expect(controller.undoLabel, '导入 2 张图片');
    });
  });
}
