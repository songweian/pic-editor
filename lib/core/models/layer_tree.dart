import 'dart:ui';

import 'adjustment_layer.dart';
import 'editor_layer.dart';
import 'group_layer.dart';
import 'image_layer.dart';

class LayerRef {
  const LayerRef({
    required this.layer,
    required this.parentId,
    required this.index,
    required this.pathIds,
    required this.pathNames,
  });

  final EditorLayer layer;
  final String? parentId;
  final int index;
  final List<String> pathIds;
  final List<String> pathNames;

  int get depth => pathIds.length - 1;
}

Iterable<LayerRef> walkLayers(
  List<EditorLayer> roots, {
  String? parentId,
  List<String> pathIds = const [],
  List<String> pathNames = const [],
}) sync* {
  for (var i = 0; i < roots.length; i++) {
    final layer = roots[i];
    final ids = [...pathIds, layer.id];
    final names = [...pathNames, layer.name];
    yield LayerRef(
      layer: layer,
      parentId: parentId,
      index: i,
      pathIds: ids,
      pathNames: names,
    );
    if (layer is GroupLayer) {
      yield* walkLayers(
        layer.children,
        parentId: layer.id,
        pathIds: ids,
        pathNames: names,
      );
    }
  }
}

EditorLayer? findLayer(List<EditorLayer> roots, String id) {
  for (final ref in walkLayers(roots)) {
    if (ref.layer.id == id) return ref.layer;
  }
  return null;
}

LayerRef? findLayerRef(List<EditorLayer> roots, String id) {
  for (final ref in walkLayers(roots)) {
    if (ref.layer.id == id) return ref;
  }
  return null;
}

List<ImageLayer> imageLayersOf(List<EditorLayer> roots) {
  return [
    for (final ref in walkLayers(roots))
      if (ref.layer is ImageLayer) ref.layer as ImageLayer,
  ];
}

List<EditorLayer> replaceLayerInTree(
  List<EditorLayer> roots,
  EditorLayer next,
) {
  return [
    for (final layer in roots)
      if (layer.id == next.id)
        next
      else if (layer is GroupLayer)
        layer.copyWith(children: replaceLayerInTree(layer.children, next))
      else
        layer,
  ];
}

List<EditorLayer> removeLayerInTree(List<EditorLayer> roots, String id) {
  return [
    for (final layer in roots)
      if (layer.id == id)
        ...<EditorLayer>[]
      else if (layer is GroupLayer)
        layer.copyWith(children: removeLayerInTree(layer.children, id))
      else
        layer,
  ];
}

List<EditorLayer> siblingsOf(List<EditorLayer> roots, String id) {
  final ref = findLayerRef(roots, id);
  if (ref == null) return const [];
  if (ref.parentId == null) return roots;
  final parent = findLayer(roots, ref.parentId!);
  return parent is GroupLayer ? parent.children : const [];
}

List<EditorLayer> moveSibling(
  List<EditorLayer> roots,
  String id,
  int delta,
) {
  final ref = findLayerRef(roots, id);
  if (ref == null) return roots;
  List<EditorLayer> shift(List<EditorLayer> list) {
    final index = list.indexWhere((layer) => layer.id == id);
    if (index < 0) return list;
    final nextIndex = (index + delta).clamp(0, list.length - 1);
    if (nextIndex == index) return list;
    final copy = [...list];
    final item = copy.removeAt(index);
    copy.insert(nextIndex, item);
    return copy;
  }

  if (ref.parentId == null) return shift(roots);
  final parent = findLayer(roots, ref.parentId!);
  if (parent is! GroupLayer) return roots;
  return replaceLayerInTree(
      roots, parent.copyWith(children: shift(parent.children)));
}

List<EditorLayer> moveSiblingToEdge(
  List<EditorLayer> roots,
  String id, {
  required bool front,
}) {
  final siblings = siblingsOf(roots, id);
  if (siblings.isEmpty) return roots;
  final current = siblings.indexWhere((layer) => layer.id == id);
  final target = front ? siblings.length - 1 : 0;
  return moveSibling(roots, id, target - current);
}

Set<String> isolatedSubtreeIds(List<EditorLayer> roots, String? isolationId) {
  if (isolationId == null) return const {};
  final node = findLayer(roots, isolationId);
  if (node == null) return {isolationId};
  if (node is! GroupLayer) return {isolationId};
  return {
    isolationId,
    for (final ref in walkLayers(node.children)) ref.layer.id,
  };
}

int nestingComplexity(List<EditorLayer> roots) {
  var images = 0;
  var maxDepth = 0;
  var adjustments = 0;
  for (final ref in walkLayers(roots)) {
    if (ref.depth > maxDepth) maxDepth = ref.depth;
    if (ref.layer is ImageLayer) images++;
    if (ref.layer is AdjustmentLayer) adjustments++;
  }
  return images + adjustments * 2 + maxDepth * 3;
}

Rect? layerBounds(EditorLayer layer) {
  if (layer is ImageLayer) return layer.paperBounds;
  if (layer is GroupLayer) {
    Rect? bounds;
    for (final child in layer.children) {
      final next = layerBounds(child);
      if (next == null) continue;
      bounds = bounds == null ? next : bounds.expandToInclude(next);
    }
    return bounds;
  }
  return null;
}

bool layerContainsPoint(EditorLayer layer, Offset paperPoint) {
  final bounds = layerBounds(layer);
  if (bounds == null) return false;
  if (layer is ImageLayer) return layer.containsPaperPoint(paperPoint);
  return bounds.inflate(8).contains(paperPoint);
}
