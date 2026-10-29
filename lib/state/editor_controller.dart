import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/commands/command_history.dart';
import '../core/commands/editor_command.dart';
import '../core/models/editor_document.dart';
import '../core/models/editor_layer.dart';
import '../core/models/image_layer.dart';
import '../core/models/paper_spec.dart';
import '../core/models/place_mode.dart';
import '../core/utils/decode_image.dart';
import '../core/utils/ids.dart';
import '../core/utils/save_png.dart';
import '../data/paper_presets.dart';
import '../features/editor/tools/export_png.dart';
import '../features/editor/tools/import_images.dart';
import '../features/editor/tools/sample_image.dart';

enum HandleKind { nw, n, ne, e, se, s, sw, w, rotate }

class EditorController extends ChangeNotifier {
  EditorController()
      : _document = EditorDocument(
          paper: PaperPresets.defaultSpec,
          landscape: false,
          layers: const [],
        );

  final CommandHistory _history = CommandHistory();
  final TransformationController viewTransform = TransformationController();
  final Map<String, ui.Image> decodedImages = <String, ui.Image>{};

  EditorDocument _document;
  EditorDocument? _transientBefore;
  bool _panMode = false;
  bool _cropMode = false;
  Rect _workingCrop = const Rect.fromLTWH(0, 0, 1, 1);
  bool _exporting = false;
  bool _disposed = false;
  int _layerSeq = 1;
  int viewGeneration = 0;
  Size? lastViewport;

  EditorDocument get document => _document;
  PaperSpec get paper => _document.paper;
  bool get landscape => _document.landscape;
  Size get paperSizePx => _document.sizePx;
  List<EditorLayer> get layers => _document.layers;
  ImageLayer? get selectedImage => _document.selectedImage;
  String? get selectedLayerId => _document.selectedLayerId;
  bool get panMode => _panMode;
  bool get cropMode => _cropMode;
  Rect get workingCrop => _workingCrop;
  bool get exporting => _exporting;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get undoLabel => _history.undoLabel;
  String? get redoLabel => _history.redoLabel;
  double get viewScale => viewTransform.value.getMaxScaleOnAxis();

  @override
  void dispose() {
    _disposed = true;
    for (final image in decodedImages.values) {
      image.dispose();
    }
    decodedImages.clear();
    viewTransform.dispose();
    super.dispose();
  }

  void setPanMode(bool value) {
    if (_panMode == value) return;
    _panMode = value;
    if (value) {
      cancelCrop();
    }
    notifyListeners();
  }

  void selectLayer(String? id) {
    if (_cropMode) return;
    if (_document.selectedLayerId == id) return;
    _document = _document.copyWith(
      selectedLayerId: id,
      clearSelection: id == null,
    );
    notifyListeners();
  }

  void setPaper(String id) {
    if (_cropMode) return;
    final spec = PaperPresets.byId(id);
    if (spec.id == _document.paper.id) return;
    _commit(
      _document.remapped(paper: spec),
      '切换纸张 ${spec.label}',
    );
    viewGeneration++;
  }

  void toggleOrientation() {
    if (_cropMode) return;
    final next = _document.remapped(landscape: !_document.landscape);
    _commit(next, next.landscape ? '横向纸张' : '纵向纸张');
    viewGeneration++;
  }

  Future<int> importImages({PlaceMode mode = PlaceMode.fit}) async {
    if (_cropMode) return 0;
    final files = await pickImportedImages();
    return addImportedImages(files, mode: mode);
  }

  int addImportedImages(
    List<ImportedImage> files, {
    PlaceMode mode = PlaceMode.fit,
  }) {
    if (_cropMode || files.isEmpty) return 0;
    var next = _document;
    String? lastId;
    for (final file in files) {
      final layer = _placedLayer(
        bytes: file.bytes,
        sourceSize: file.size,
        name: file.name.isEmpty ? '图片 $_layerSeq' : file.name,
        mode: mode,
        paperSize: next.sizePx,
      );
      _layerSeq++;
      next = next.copyWith(
        layers: [...next.layers, layer],
        selectedLayerId: layer.id,
      );
      lastId = layer.id;
      _decodeLater(layer);
    }
    _commit(next, files.length > 1 ? '导入 ${files.length} 张图片' : '导入图片');
    return lastId == null ? 0 : files.length;
  }

  Future<void> addSampleImages() async {
    if (_cropMode) return;
    var next = _document;
    var index = 0;
    for (final spec in kSampleImages) {
      var layer = _placedLayer(
        bytes: buildSamplePng(spec),
        sourceSize: Size(spec.width.toDouble(), spec.height.toDouble()),
        name: spec.name,
        mode: PlaceMode.fit,
        paperSize: next.sizePx,
      );
      if (index > 0) {
        layer = layer.copyWith(
          position: layer.position + Offset(index * 48.0, index * 48.0),
        );
      }
      next = next.copyWith(
        layers: [...next.layers, layer],
        selectedLayerId: layer.id,
      );
      _decodeLater(layer);
      index++;
    }
    _commit(next, '添加示例图');
  }

  void applyPlaceMode(PlaceMode mode) {
    final layer = selectedImage;
    if (layer == null || layer.locked || _cropMode) return;
    final placed = _placedLayer(
      bytes: layer.bytes,
      sourceSize: layer.croppedSourceSize,
      name: layer.name,
      mode: mode,
      paperSize: _document.sizePx,
    );
    _commit(
      _document.replaceLayer(
        layer.copyWith(
          position: placed.position,
          rotation: 0,
          scaleX: placed.scaleX,
          scaleY: placed.scaleY,
        ),
      ),
      mode.label,
    );
  }

  void setVisible(String id, bool visible) {
    final layer = _imageById(id);
    if (layer == null) return;
    _commit(
      _document.replaceLayer(layer.copyWith(visible: visible)),
      visible ? '显示图层' : '隐藏图层',
    );
  }

  void setLocked(String id, bool locked) {
    final layer = _imageById(id);
    if (layer == null) return;
    _commit(
      _document.replaceLayer(layer.copyWith(locked: locked)),
      locked ? '锁定图层' : '解锁图层',
    );
  }

  void renameLayer(String id, String name) {
    final layer = _imageById(id);
    if (layer == null) return;
    final trimmed = name.trim().isEmpty ? layer.name : name.trim();
    if (trimmed == layer.name) return;
    _commit(_document.replaceLayer(layer.copyWith(name: trimmed)), '重命名图层');
  }

  void deleteLayer(String id) {
    final index = _document.layers.indexWhere((layer) => layer.id == id);
    if (index < 0) return;
    final target = _document.layers[index];
    if (target.locked) return;
    final remaining = [..._document.layers]..removeAt(index);
    String? nextSelected = _document.selectedLayerId;
    if (nextSelected == id) {
      if (remaining.isEmpty) {
        nextSelected = null;
      } else {
        nextSelected = remaining[math.min(index, remaining.length - 1)].id;
      }
    }
    _commit(
      _document.copyWith(
        layers: remaining,
        selectedLayerId: nextSelected,
        clearSelection: nextSelected == null,
      ),
      '删除图层',
    );
    // Keep decodedImages cached so undo can restore the layer immediately.
  }

  void deleteSelected() {
    final id = _document.selectedLayerId;
    if (id == null || _cropMode) return;
    deleteLayer(id);
  }

  int layerIndex(String id) {
    return _document.layers.indexWhere((layer) => layer.id == id);
  }

  bool isTopLayer(String id) {
    final index = layerIndex(id);
    return index >= 0 && index == _document.layers.length - 1;
  }

  bool isBottomLayer(String id) {
    return layerIndex(id) == 0;
  }

  void moveLayer(String id, int delta) {
    final index = layerIndex(id);
    if (index < 0) return;
    _moveLayerTo(
      id,
      index + delta,
      delta > 0 ? '上移图层' : '下移图层',
    );
  }

  void bringToFront(String id) {
    if (_document.layers.isEmpty) return;
    _moveLayerTo(id, _document.layers.length - 1, '置于顶层');
  }

  void sendToBack(String id) {
    _moveLayerTo(id, 0, '置于底层');
  }

  void _moveLayerTo(String id, int targetIndex, String label) {
    final list = [..._document.layers];
    final index = list.indexWhere((layer) => layer.id == id);
    if (index < 0 || list.length < 2) return;
    final nextIndex = targetIndex.clamp(0, list.length - 1);
    if (nextIndex == index) return;
    final item = list.removeAt(index);
    list.insert(nextIndex, item);
    _commit(_document.copyWith(layers: list), label);
  }

  void flipHorizontal() {
    final layer = selectedImage;
    if (layer == null || layer.locked || _cropMode) return;
    _commit(
      _document.replaceLayer(layer.copyWith(scaleX: -layer.scaleX)),
      '水平翻转',
    );
  }

  void flipVertical() {
    final layer = selectedImage;
    if (layer == null || layer.locked || _cropMode) return;
    _commit(
      _document.replaceLayer(layer.copyWith(scaleY: -layer.scaleY)),
      '垂直翻转',
    );
  }

  void beginTransient() {
    _transientBefore ??= _document;
  }

  void previewLayer(ImageLayer layer) {
    beginTransient();
    _document = _document.replaceLayer(layer);
    notifyListeners();
  }

  void commitTransient(String label) {
    final before = _transientBefore;
    if (before == null) return;
    _transientBefore = null;
    _history.pushApplied(
      DocumentCommand(label: label, before: before, after: _document),
    );
    notifyListeners();
  }

  void cancelTransient() {
    final before = _transientBefore;
    if (before == null) return;
    _document = before;
    _transientBefore = null;
    notifyListeners();
  }

  void previewOpacity(double opacity) {
    final layer = selectedImage;
    if (layer == null || layer.locked) return;
    previewLayer(layer.copyWith(opacity: opacity.clamp(0.0, 1.0)));
  }

  void commitOpacity() => commitTransient('不透明度');

  void enterCrop() {
    final layer = selectedImage;
    if (layer == null || layer.locked) return;
    _cropMode = true;
    _panMode = false;
    _workingCrop = const Rect.fromLTWH(0, 0, 1, 1);
    notifyListeners();
  }

  void updateWorkingCrop(Rect crop) {
    _workingCrop = _sanitizeCrop(crop);
    notifyListeners();
  }

  void cancelCrop() {
    if (!_cropMode) return;
    _cropMode = false;
    _workingCrop = const Rect.fromLTWH(0, 0, 1, 1);
    notifyListeners();
  }

  void confirmCrop() {
    final layer = selectedImage;
    if (layer == null || !_cropMode) return;
    final composed = _composeCrop(layer.normalizedCrop, _workingCrop);
    _cropMode = false;
    _workingCrop = const Rect.fromLTWH(0, 0, 1, 1);
    _commit(_document.replaceLayer(layer.copyWith(cropRect: composed)), '裁剪');
  }

  void undo() {
    if (_cropMode) {
      cancelCrop();
      return;
    }
    if (!_history.canUndo) return;
    cancelTransient();
    _document = _history.undo(_document);
    _syncDecoded();
    notifyListeners();
  }

  void redo() {
    if (_cropMode || !_history.canRedo) return;
    cancelTransient();
    _document = _history.redo(_document);
    _syncDecoded();
    notifyListeners();
  }

  Future<Uint8List> exportPngBytes() async {
    await ensureDecoded();
    return exportDocumentPng(
      document: _document,
      images: decodedImages,
    );
  }

  Future<void> ensureDecoded() async {
    for (final layer in _document.layers) {
      if (layer is ImageLayer) {
        await _decode(layer);
      }
    }
  }

  Future<String?> exportPng() async {
    if (_exporting) return null;
    _exporting = true;
    notifyListeners();
    try {
      final bytes = await exportPngBytes();
      return savePng(bytes, exportFileName(_document));
    } finally {
      _exporting = false;
      notifyListeners();
    }
  }

  void fitPaperTo(Size viewport, {double margin = 56}) {
    lastViewport = viewport;
    final paper = paperSizePx;
    if (paper.width <= 0 || paper.height <= 0) return;
    final scale = math.min(
      (viewport.width - margin) / paper.width,
      (viewport.height - margin) / paper.height,
    ).clamp(0.05, 8.0);
    final dx = (viewport.width - paper.width * scale) / 2;
    final dy = (viewport.height - paper.height * scale) / 2;
    viewTransform.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    notifyListeners();
  }

  void setZoomPercent(int percent, Size viewport) {
    lastViewport = viewport;
    final scale = (percent / 100).clamp(0.05, 8.0);
    final paper = paperSizePx;
    final dx = (viewport.width - paper.width * scale) / 2;
    final dy = (viewport.height - paper.height * scale) / 2;
    viewTransform.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    notifyListeners();
  }

  void zoomAt(Offset viewportPoint, double factor) {
    final old = viewTransform.value;
    final oldScale = old.getMaxScaleOnAxis();
    final newScale = (oldScale * factor).clamp(0.05, 8.0);
    final inv = Matrix4.copy(old)..invert();
    final child = _transformPoint(inv, viewportPoint);
    final translation = viewportPoint - child * newScale;
    viewTransform.value = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..scale(newScale);
    notifyListeners();
  }

  ImageLayer applyHandle({
    required ImageLayer start,
    required HandleKind handle,
    required Offset currentPaper,
    required Offset startPaper,
  }) {
    if (handle == HandleKind.rotate) {
      final a0 = math.atan2(
        startPaper.dy - start.position.dy,
        startPaper.dx - start.position.dx,
      );
      final a1 = math.atan2(
        currentPaper.dy - start.position.dy,
        currentPaper.dx - start.position.dx,
      );
      return start.copyWith(rotation: start.rotation + (a1 - a0));
    }

    final local = start.toLocal(currentPaper);
    final src = start.croppedSourceSize;
    const minAbs = 0.02;
    var scaleX = start.scaleX;
    var scaleY = start.scaleY;

    switch (handle) {
      case HandleKind.e:
      case HandleKind.w:
        scaleX = _signedScale(local.dx.abs() * 2 / src.width, start.scaleX);
        break;
      case HandleKind.n:
      case HandleKind.s:
        scaleY = _signedScale(local.dy.abs() * 2 / src.height, start.scaleY);
        break;
      case HandleKind.nw:
      case HandleKind.ne:
      case HandleKind.se:
      case HandleKind.sw:
        final startLocal = start.toLocal(startPaper);
        final startDist = startLocal.distance;
        if (startDist > 0.5) {
          final factor = (local.distance / startDist).clamp(0.02, 40.0);
          scaleX = _signedScale(start.scaleX.abs() * factor, start.scaleX);
          scaleY = _signedScale(start.scaleY.abs() * factor, start.scaleY);
        }
        break;
      case HandleKind.rotate:
        break;
    }

    if (scaleX.abs() < minAbs) {
      scaleX = minAbs * scaleX.sign;
    }
    if (scaleY.abs() < minAbs) {
      scaleY = minAbs * scaleY.sign;
    }
    return start.copyWith(scaleX: scaleX, scaleY: scaleY);
  }

  ImageLayer? hitTest(Offset paperPoint, {bool includeLocked = false}) {
    for (final layer in _document.layers.reversed) {
      if (layer is! ImageLayer || !layer.visible) continue;
      if (layer.locked && !includeLocked) continue;
      if (layer.containsPaperPoint(paperPoint)) return layer;
    }
    return null;
  }

  ImageLayer _placedLayer({
    required Uint8List bytes,
    required Size sourceSize,
    required String name,
    required PlaceMode mode,
    required Size paperSize,
  }) {
    final double scale;
    switch (mode) {
      case PlaceMode.fit:
        scale = math.min(
          paperSize.width / sourceSize.width,
          paperSize.height / sourceSize.height,
        );
        break;
      case PlaceMode.fill:
        scale = math.max(
          paperSize.width / sourceSize.width,
          paperSize.height / sourceSize.height,
        );
        break;
      case PlaceMode.original:
        scale = 1;
        break;
    }
    return ImageLayer(
      id: newId(),
      name: name,
      visible: true,
      locked: false,
      opacity: 1,
      position: Offset(paperSize.width / 2, paperSize.height / 2),
      rotation: 0,
      scaleX: scale,
      scaleY: scale,
      bytes: bytes,
      sourceSize: sourceSize,
    );
  }

  ImageLayer? _imageById(String id) {
    for (final layer in _document.layers) {
      if (layer.id == id && layer is ImageLayer) return layer;
    }
    return null;
  }

  void _commit(EditorDocument next, String label) {
    _transientBefore = null;
    _history.pushApplied(
      DocumentCommand(label: label, before: _document, after: next),
    );
    _document = next;
    notifyListeners();
  }

  void _decodeLater(ImageLayer layer) {
    _decode(layer);
  }

  void _syncDecoded() {
    for (final layer in _document.layers) {
      if (layer is ImageLayer) {
        _decodeLater(layer);
      }
    }
  }

  Future<void> _decode(ImageLayer layer) async {
    if (_disposed || decodedImages.containsKey(layer.id)) return;
    try {
      final image = await decodeImageBytes(layer.bytes);
      if (_disposed || decodedImages.containsKey(layer.id)) {
        image.dispose();
        return;
      }
      decodedImages[layer.id] = image;
      notifyListeners();
    } catch (_) {
      // Keep the layer; it simply will not paint until bytes are valid.
    }
  }

  Rect _composeCrop(Rect base, Rect overlay) {
    return _sanitizeCrop(
      Rect.fromLTWH(
        base.left + overlay.left * base.width,
        base.top + overlay.top * base.height,
        overlay.width * base.width,
        overlay.height * base.height,
      ),
    );
  }

  Rect _sanitizeCrop(Rect crop) {
    const minSize = 0.04;
    var left = crop.left.clamp(0.0, 1.0);
    var top = crop.top.clamp(0.0, 1.0);
    var right = crop.right.clamp(0.0, 1.0);
    var bottom = crop.bottom.clamp(0.0, 1.0);
    if (right - left < minSize) {
      right = (left + minSize).clamp(0.0, 1.0);
      left = (right - minSize).clamp(0.0, 1.0);
    }
    if (bottom - top < minSize) {
      bottom = (top + minSize).clamp(0.0, 1.0);
      top = (bottom - minSize).clamp(0.0, 1.0);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _signedScale(double absValue, double original) {
    final sign = original < 0 ? -1.0 : 1.0;
    return absValue.abs() * sign;
  }

  Offset _transformPoint(Matrix4 matrix, Offset point) {
    final v = matrix.storage;
    final x = point.dx;
    final y = point.dy;
    final w = v[3] * x + v[7] * y + v[15];
    final nx = v[0] * x + v[4] * y + v[12];
    final ny = v[1] * x + v[5] * y + v[13];
    if (w == 0) return Offset(nx, ny);
    return Offset(nx / w, ny / w);
  }
}
