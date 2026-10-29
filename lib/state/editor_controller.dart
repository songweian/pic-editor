import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/commands/command_history.dart';
import '../core/commands/editor_command.dart';
import '../core/models/adjustment_layer.dart';
import '../core/models/editor_document.dart';
import '../core/models/editor_layer.dart';
import '../core/models/group_layer.dart';
import '../core/models/image_layer.dart';
import '../core/models/layer_mask.dart';
import '../core/models/layer_tree.dart';
import '../core/models/paper_spec.dart';
import '../core/models/place_mode.dart';
import '../core/utils/decode_image.dart';
import '../core/utils/ids.dart';
import '../core/utils/save_png.dart';
import '../data/paper_presets.dart';
import '../features/editor/tools/export_png.dart';
import '../features/editor/tools/import_images.dart';
import '../features/editor/tools/sample_image.dart';
import '../features/editor/widgets/layer_render.dart';

enum HandleKind { nw, n, ne, e, se, s, sw, w, rotate }

class EditorController extends ChangeNotifier {
  EditorController()
      : _document = EditorDocument(
          paper: PaperPresets.defaultSpec,
          landscape: false,
          layers: const [],
        ) {
    viewTransform.addListener(_onViewTransform);
  }

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
  String? _isolationId;
  bool _wireframePreview = false;
  bool _maskPaintBlack = true;
  bool _maskEditing = false;
  final Set<String> _collapsedGroups = <String>{};

  EditorDocument get document => _document;
  PaperSpec get paper => _document.paper;
  bool get landscape => _document.landscape;
  Size get paperSizePx => _document.sizePx;
  List<EditorLayer> get layers => _document.layers;
  ImageLayer? get selectedImage => _document.selectedImage;
  EditorLayer? get selectedLayer => _document.selectedLayer;
  GroupLayer? get selectedGroup => _document.selectedGroup;
  String? get selectedLayerId => _document.selectedLayerId;
  String? get isolationId => _isolationId;
  bool get isolating => _isolationId != null;
  bool get wireframePreview => _wireframePreview;
  bool get maskEditing => _maskEditing;
  bool get maskPaintBlack => _maskPaintBlack;
  bool get panMode => _panMode;
  bool get cropMode => _cropMode;
  Rect get workingCrop => _workingCrop;
  bool get exporting => _exporting;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get undoLabel => _history.undoLabel;
  String? get redoLabel => _history.redoLabel;
  double get viewScale => viewTransform.value.getMaxScaleOnAxis();

  void _onViewTransform() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    viewTransform.removeListener(_onViewTransform);
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
    if (id != null && _isolationId != null) {
      final allowed = isolatedSubtreeIds(layers, _isolationId);
      if (id != _isolationId && !allowed.contains(id)) {
        return;
      }
    }
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
    viewGeneration++;
    _commit(
      _document.remapped(paper: spec),
      '切换纸张 ${spec.label}',
    );
  }

  void toggleOrientation() {
    if (_cropMode) return;
    viewGeneration++;
    final next = _document.remapped(landscape: !_document.landscape);
    _commit(next, next.landscape ? '横向纸张' : '纵向纸张');
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
    final layer = _layerById(id);
    if (layer == null) return;
    _commit(
      _document.replaceLayer(layer.copyLayer(visible: visible)),
      visible ? '显示图层' : '隐藏图层',
    );
  }

  void setLocked(String id, bool locked) {
    final layer = _layerById(id);
    if (layer == null) return;
    _commit(
      _document.replaceLayer(layer.copyLayer(locked: locked)),
      locked ? '锁定图层' : '解锁图层',
    );
  }

  void renameLayer(String id, String name) {
    final layer = _layerById(id);
    if (layer == null) return;
    final trimmed = name.trim().isEmpty ? layer.name : name.trim();
    if (trimmed == layer.name) return;
    _commit(_document.replaceLayer(layer.copyLayer(name: trimmed)), '重命名图层');
  }

  void deleteLayer(String id) {
    final ref = findLayerRef(_document.layers, id);
    if (ref == null || ref.layer.locked) return;
    if (_isolationId == id) _isolationId = null;
    final remaining = removeLayerInTree(_document.layers, id);
    final siblings = siblingsOf(_document.layers, id);
    String? nextSelected = _document.selectedLayerId;
    if (nextSelected == id) {
      if (siblings.length <= 1) {
        nextSelected = ref.parentId;
      } else {
        nextSelected = siblings[math.min(ref.index, siblings.length - 2)].id;
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
  }

  void deleteSelected() {
    final id = _document.selectedLayerId;
    if (id == null || _cropMode) return;
    deleteLayer(id);
  }

  int layerIndex(String id) {
    final ref = findLayerRef(_document.layers, id);
    return ref?.index ?? -1;
  }

  bool isTopLayer(String id) {
    final siblings = siblingsOf(_document.layers, id);
    return siblings.isNotEmpty && siblings.last.id == id;
  }

  bool isBottomLayer(String id) {
    final siblings = siblingsOf(_document.layers, id);
    return siblings.isNotEmpty && siblings.first.id == id;
  }

  void moveLayer(String id, int delta) {
    if (findLayer(_document.layers, id) == null) return;
    _commit(
      _document.copyWith(layers: moveSibling(_document.layers, id, delta)),
      delta > 0 ? '上移图层' : '下移图层',
    );
  }

  void bringToFront(String id) {
    _commit(
      _document.copyWith(
        layers: moveSiblingToEdge(_document.layers, id, front: true),
      ),
      '置于顶层',
    );
  }

  void sendToBack(String id) {
    _commit(
      _document.copyWith(
        layers: moveSiblingToEdge(_document.layers, id, front: false),
      ),
      '置于底层',
    );
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
    setDragWireframe(true);
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
    setDragWireframe(false);
    notifyListeners();
  }

  void cancelTransient() {
    final before = _transientBefore;
    if (before == null) return;
    _document = before;
    _transientBefore = null;
    setDragWireframe(false);
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
    _applyHistoryDocument(_history.undo(_document));
  }

  void redo() {
    if (_cropMode || !_history.canRedo) return;
    cancelTransient();
    _applyHistoryDocument(_history.redo(_document));
  }

  Future<Uint8List> exportPngBytes() async {
    await ensureDecoded();
    return exportDocumentPng(
      document: _document,
      images: decodedImages,
    );
  }

  Future<void> ensureDecoded() async {
    for (final layer in imageLayersOf(_document.layers)) {
      await _decode(layer);
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
    final scale = math
        .min(
          (viewport.width - margin) / paper.width,
          (viewport.height - margin) / paper.height,
        )
        .clamp(0.05, 8.0);
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

  Offset viewportToPaper(Offset viewportPoint) {
    final inv = Matrix4.copy(viewTransform.value)..invert();
    return _transformPoint(inv, viewportPoint);
  }

  Matrix4 copyViewMatrix() => Matrix4.copy(viewTransform.value);

  void restoreViewMatrix(Matrix4 matrix) {
    viewTransform.value = Matrix4.copy(matrix);
    notifyListeners();
  }

  void panBy(Offset viewportDelta) {
    if (viewportDelta == Offset.zero) return;
    final current = viewTransform.value;
    final translation = current.getTranslation();
    final scale = current.getMaxScaleOnAxis();
    viewTransform.value = Matrix4.identity()
      ..translate(
        translation.x + viewportDelta.dx,
        translation.y + viewportDelta.dy,
      )
      ..scale(scale);
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

  EditorLayer? hitTest(
    Offset paperPoint, {
    bool includeLocked = false,
    bool deep = false,
  }) {
    final scope = _hitScope();
    EditorLayer? innermost;
    void visit(List<EditorLayer> list) {
      for (final layer in list.reversed) {
        if (!layer.visible) continue;
        if (layer.locked && !includeLocked && layer is! GroupLayer) continue;
        if (layer is GroupLayer) {
          if (layerContainsPoint(layer, paperPoint)) {
            visit(layer.children);
            innermost ??= layer;
          }
        } else if (layer is ImageLayer &&
            layer.containsPaperPoint(paperPoint)) {
          innermost ??= layer;
        }
      }
    }

    visit(scope);
    final hit = innermost;
    if (hit == null) return null;
    if (deep) return hit;
    final ref = findLayerRef(_document.layers, hit.id);
    if (ref == null) return hit;
    final path = ref.pathIds;
    final rootIndex = _isolationId == null ? 0 : path.indexOf(_isolationId!);
    final childIndex = _isolationId == null ? 0 : rootIndex + 1;
    if (childIndex >= 0 && childIndex < path.length) {
      return findLayer(_document.layers, path[childIndex]) ?? hit;
    }
    return hit;
  }

  List<EditorLayer> _hitScope() {
    if (_isolationId == null) return _document.layers;
    final node = findLayer(_document.layers, _isolationId!);
    if (node is GroupLayer) return node.children;
    return node == null ? _document.layers : [node];
  }

  ImageLayer? hitTestImage(Offset paperPoint, {bool includeLocked = false}) {
    final hit = hitTest(paperPoint, includeLocked: includeLocked, deep: true);
    return hit is ImageLayer ? hit : null;
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

  EditorLayer? _layerById(String id) => findLayer(_document.layers, id);

  ImageLayer? _imageById(String id) {
    final layer = _layerById(id);
    return layer is ImageLayer ? layer : null;
  }

  void _applyHistoryDocument(EditorDocument next) {
    final paperChanged = _document.paper.id != next.paper.id ||
        _document.landscape != next.landscape;
    _document = next;
    if (paperChanged) viewGeneration++;
    _syncDecoded();
    notifyListeners();
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
    for (final layer in imageLayersOf(_document.layers)) {
      _decodeLater(layer);
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

  List<String> get breadcrumbIds {
    final id = _isolationId ?? selectedLayerId;
    if (id == null) return const [];
    return findLayerRef(_document.layers, id)?.pathIds ?? const [];
  }

  List<String> get breadcrumbNames {
    final id = _isolationId ?? selectedLayerId;
    if (id == null) return const [];
    return findLayerRef(_document.layers, id)?.pathNames ?? const [];
  }

  bool isGroupCollapsed(String id) => _collapsedGroups.contains(id);

  void toggleGroupCollapsed(String id) {
    if (_collapsedGroups.contains(id)) {
      _collapsedGroups.remove(id);
    } else {
      _collapsedGroups.add(id);
    }
    notifyListeners();
  }

  void isolateLayer(String id) {
    if (findLayer(_document.layers, id) == null) return;
    _isolationId = id;
    _document = _document.copyWith(selectedLayerId: id);
    notifyListeners();
  }

  void exitIsolation({String? toId}) {
    if (_isolationId == null && toId == null) return;
    _isolationId = toId;
    notifyListeners();
  }

  void jumpBreadcrumb(String id) {
    if (id.isEmpty) {
      _isolationId = null;
      notifyListeners();
      return;
    }
    isolateLayer(id);
  }

  void groupSelected() {
    final id = selectedLayerId;
    if (id == null) return;
    final ref = findLayerRef(_document.layers, id);
    if (ref == null) return;
    final group = GroupLayer(
      id: newId(),
      name: '图层组',
      visible: true,
      locked: false,
      opacity: 1,
      children: [ref.layer],
    );
    _commit(
      _document.copyWith(
        layers: _insertAt(ref, group),
        selectedLayerId: group.id,
      ),
      '编组',
    );
  }

  List<EditorLayer> _insertAt(LayerRef ref, EditorLayer node) {
    List<EditorLayer> insert(List<EditorLayer> list) {
      final copy = [...list];
      final index = copy.indexWhere((layer) => layer.id == ref.layer.id);
      if (index >= 0) {
        copy[index] = node;
        return copy;
      }
      return [
        for (final layer in list)
          if (layer is GroupLayer)
            layer.copyWith(children: insert(layer.children))
          else
            layer,
      ];
    }

    return insert(_document.layers);
  }

  void ungroupSelected() {
    final group = selectedGroup;
    if (group == null) return;
    final ref = findLayerRef(_document.layers, group.id);
    if (ref == null) return;
    List<EditorLayer> explode(List<EditorLayer> list) {
      final index = list.indexWhere((layer) => layer.id == group.id);
      if (index >= 0) {
        final copy = [...list]..replaceRange(index, index + 1, group.children);
        return copy;
      }
      return [
        for (final layer in list)
          if (layer is GroupLayer)
            layer.copyWith(children: explode(layer.children))
          else
            layer,
      ];
    }

    _commit(
      _document.copyWith(
        layers: explode(_document.layers),
        selectedLayerId:
            group.children.isEmpty ? ref.parentId : group.children.last.id,
      ),
      '取消编组',
    );
  }

  void setPassThrough(String id, bool value) {
    final layer = _layerById(id);
    if (layer is! GroupLayer) return;
    _commit(
      _document.replaceLayer(layer.copyWith(passThrough: value)),
      value ? '穿透混合' : '正常封装',
    );
  }

  void addAdjustment(AdjustmentKind kind) {
    final target = selectedLayer;
    if (target == null) return;
    final adj = AdjustmentLayer(
      id: newId(),
      name: kind.label,
      visible: true,
      locked: false,
      opacity: 1,
      kind: kind,
      amount: 0.2,
      clipToBelow: true,
    );
    final siblings = siblingsOf(_document.layers, target.id);
    final index = siblings.indexWhere((layer) => layer.id == target.id);
    List<EditorLayer> insertAfter(List<EditorLayer> list) {
      final i = list.indexWhere((layer) => layer.id == target.id);
      if (i >= 0) {
        final copy = [...list]..insert(i + 1, adj);
        return copy;
      }
      return [
        for (final layer in list)
          if (layer is GroupLayer)
            layer.copyWith(children: insertAfter(layer.children))
          else
            layer,
      ];
    }

    if (index < 0) return;
    _commit(
      _document.copyWith(
        layers: insertAfter(_document.layers),
        selectedLayerId: adj.id,
      ),
      '添加${kind.label}',
    );
  }

  void setAdjustmentAmount(String id, double amount) {
    final layer = _layerById(id);
    if (layer is! AdjustmentLayer) return;
    _commit(
      _document.replaceLayer(layer.copyWith(amount: amount.clamp(-1.0, 1.0))),
      '调整${layer.kind.label}',
    );
  }

  void setClipToBelow(String id, bool value) {
    final layer = _layerById(id);
    if (layer == null) return;
    _commit(
      _document.replaceLayer(layer.copyLayer(clipToBelow: value)),
      value ? '剪贴蒙版' : '取消剪贴',
    );
  }

  void clipSelectedToBelow() {
    final id = selectedLayerId;
    if (id == null || isBottomLayer(id)) return;
    setClipToBelow(id, !(_layerById(id)?.clipToBelow ?? false));
  }

  void addMaskToSelected() {
    final layer = selectedImage;
    if (layer == null || layer.locked) return;
    _commit(
      _document.replaceLayer(layer.copyWith(mask: LayerMask.fullVisible())),
      '添加图层蒙版',
    );
    _maskEditing = true;
    notifyListeners();
  }

  void toggleMaskEnabled(String id) {
    final layer = _imageById(id);
    final mask = layer?.mask;
    if (layer == null || mask == null) return;
    _commit(
      _document.replaceLayer(
        layer.copyWith(mask: mask.copyWith(enabled: !mask.enabled)),
      ),
      mask.enabled ? '停用蒙版' : '启用蒙版',
    );
  }

  void setMaskEditing(bool value) {
    _maskEditing = value;
    notifyListeners();
  }

  void setMaskPaintBlack(bool value) {
    _maskPaintBlack = value;
    notifyListeners();
  }

  void paintMaskAt(Offset paperPoint, {double radius = 18}) {
    final layer = selectedImage;
    final mask = layer?.mask;
    if (layer == null || mask == null || !mask.enabled || layer.locked) return;
    final local = layer.toLocal(paperPoint);
    final size = layer.displaySize;
    if (size.width <= 1 || size.height <= 1) return;
    final u = (local.dx / size.width + 0.5).clamp(0.0, 1.0);
    final v = (local.dy / size.height + 0.5).clamp(0.0, 1.0);
    final pixels = Uint8List.fromList(mask.pixels);
    final rr = (radius / size.width * mask.width).clamp(1.0, mask.width / 2);
    final cx = u * (mask.width - 1);
    final cy = v * (mask.height - 1);
    final value = _maskPaintBlack ? 0 : 255;
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= rr * rr) {
          pixels[y * mask.width + x] = value;
        }
      }
    }
    beginTransient();
    previewLayer(layer.copyWith(mask: mask.copyWith(pixels: pixels)));
  }

  void resetLayer() {
    final layer = selectedLayer;
    if (layer == null || layer.locked) return;
    if (layer is ImageLayer) {
      _commit(
        _document.replaceLayer(
          layer.copyWith(
            brightness: 0,
            contrast: 0,
            clearMask: true,
            clipToBelow: false,
            clearCrop: true,
          ),
        ),
        '重置图层',
      );
      return;
    }
    if (layer is AdjustmentLayer) {
      _commit(
        _document.replaceLayer(layer.copyWith(amount: 0)),
        '重置图层',
      );
    }
  }

  Future<void> rasterizeSelected() async {
    final layer = selectedLayer;
    if (layer == null || layer.locked) return;
    await ensureDecoded();
    final bounds = layerBounds(layer) ?? (Offset.zero & paperSizePx);
    final width = bounds.width.ceil().clamp(1, 8000);
    final height = bounds.height.ceil().clamp(1, 8000);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(-bounds.left, -bounds.top);
    paintLayerTree(
      canvas,
      paperSizePx,
      layers: layer is GroupLayer ? layer.children : [layer],
      images: decodedImages,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) return;
    final bytes = data.buffer.asUint8List();
    final raster = ImageLayer(
      id: newId(),
      name: '${layer.name} 栅格',
      visible: true,
      locked: false,
      opacity: 1,
      position: bounds.center,
      rotation: 0,
      scaleX: 1,
      scaleY: 1,
      bytes: bytes,
      sourceSize: Size(width.toDouble(), height.toDouble()),
    );
    final ref = findLayerRef(_document.layers, layer.id);
    if (ref == null) return;
    _commit(
      _document.copyWith(
        layers: _insertAt(ref, raster),
        selectedLayerId: raster.id,
      ),
      '栅格化',
    );
    _decodeLater(raster);
    if (_isolationId == layer.id) _isolationId = raster.id;
  }

  void setDragWireframe(bool dragging) {
    final should = dragging && nestingComplexity(_document.layers) >= 8;
    if (_wireframePreview == should) return;
    _wireframePreview = should;
    notifyListeners();
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
