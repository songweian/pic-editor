import 'dart:ui';

import '../utils/units.dart';
import 'editor_layer.dart';
import 'image_layer.dart';
import 'paper_spec.dart';

class EditorDocument {
  const EditorDocument({
    required this.paper,
    required this.landscape,
    required this.layers,
    this.selectedLayerId,
  });

  final PaperSpec paper;
  final bool landscape;
  final List<EditorLayer> layers;
  final String? selectedLayerId;

  Size get sizeMm => specSizeMm(paper, landscape: landscape);

  Size get sizePx => specSizePx(paper, landscape: landscape);

  Size exportSizePx() => specSizePx(paper, landscape: landscape, dpi: exportDpi);

  EditorLayer? get selectedLayer {
    final id = selectedLayerId;
    if (id == null) return null;
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  ImageLayer? get selectedImage {
    final layer = selectedLayer;
    return layer is ImageLayer ? layer : null;
  }

  EditorDocument copyWith({
    PaperSpec? paper,
    bool? landscape,
    List<EditorLayer>? layers,
    String? selectedLayerId,
    bool clearSelection = false,
  }) {
    return EditorDocument(
      paper: paper ?? this.paper,
      landscape: landscape ?? this.landscape,
      layers: layers ?? this.layers,
      selectedLayerId:
          clearSelection ? null : (selectedLayerId ?? this.selectedLayerId),
    );
  }

  EditorDocument replaceLayer(EditorLayer layer) {
    return copyWith(
      layers: [
        for (final item in layers) item.id == layer.id ? layer : item,
      ],
    );
  }

  EditorDocument remapped({
    PaperSpec? paper,
    bool? landscape,
  }) {
    final oldSize = sizePx;
    final next = copyWith(paper: paper, landscape: landscape);
    final newSize = next.sizePx;
    if ((oldSize.width - newSize.width).abs() < 0.01 &&
        (oldSize.height - newSize.height).abs() < 0.01) {
      return next;
    }
    final sx = newSize.width / oldSize.width;
    final sy = newSize.height / oldSize.height;
    return next.copyWith(
      layers: [
        for (final layer in layers)
          if (layer is ImageLayer)
            layer.copyWith(
              position: Offset(layer.position.dx * sx, layer.position.dy * sy),
            )
          else
            layer,
      ],
    );
  }
}
