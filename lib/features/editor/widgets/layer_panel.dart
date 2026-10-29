import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/adjustment_layer.dart';
import '../../../core/models/editor_layer.dart';
import '../../../core/models/group_layer.dart';
import '../../../core/models/image_layer.dart';
import '../../../core/models/layer_tree.dart';
import '../../../state/editor_controller.dart';
import '../gestures/two_finger_tap.dart';
import 'layer_context_menu.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({
    super.key,
    this.scrollController,
    this.showHeader = true,
  });

  final ScrollController? scrollController;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final count = walkLayers(controller.layers).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text('图层', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('$count 个', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        Expanded(
          child: controller.layers.isEmpty
              ? const Center(
                  child: Text('还没有图层\n导入图片或添加示例图', textAlign: TextAlign.center),
                )
              : ListView(
                  controller: scrollController,
                  children: _tiles(context, controller, controller.layers, 0),
                ),
        ),
      ],
    );
  }

  List<Widget> _tiles(
    BuildContext context,
    EditorController controller,
    List<EditorLayer> nodes,
    int depth,
  ) {
    final widgets = <Widget>[];
    final reversed = nodes.reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      final layer = reversed[i];
      widgets.add(
        _LayerRow(
          layer: layer,
          depth: depth,
        ),
      );
      if (i < reversed.length - 1) {
        widgets.add(_ClipGap(upperId: layer.id));
      }
      if (layer is GroupLayer && !controller.isGroupCollapsed(layer.id)) {
        widgets.addAll(
          _tiles(context, controller, layer.children, depth + 1),
        );
      }
    }
    return widgets;
  }
}

class _ClipGap extends StatelessWidget {
  const _ClipGap({required this.upperId});

  final String upperId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final keys = HardwareKeyboard.instance.logicalKeysPressed;
        final alt = keys.contains(LogicalKeyboardKey.altLeft) ||
            keys.contains(LogicalKeyboardKey.altRight);
        if (!alt) return;
        final controller = context.read<EditorController>();
        controller.selectLayer(upperId);
        controller.clipSelectedToBelow();
      },
      child: const SizedBox(height: 6),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.layer, required this.depth});

  final EditorLayer layer;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final selected = layer.id == controller.selectedLayerId;
    final scheme = Theme.of(context).colorScheme;
    final image = layer is ImageLayer ? layer as ImageLayer : null;
    final isolated = isolatedSubtreeIds(
      controller.layers,
      controller.isolationId,
    );
    final inFocus = !controller.isolating || isolated.contains(layer.id);
    return Opacity(
      opacity: inFocus ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: controller.isolating && !inFocus,
        child: TwoFingerTapDetector(
          key: ValueKey('layer-${layer.id}'),
          onTwoFingerTap: (global) => showLayerContextMenu(
            context: context,
            globalPosition: global,
            layerId: layer.id,
            haptic: true,
          ),
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons != kSecondaryMouseButton) return;
              showLayerContextMenu(
                context: context,
                globalPosition: event.position,
                layerId: layer.id,
              );
            },
            child: Material(
              color: selected
                  ? scheme.primary.withOpacity(0.16)
                  : Colors.transparent,
              child: InkWell(
                onTap: () => controller.selectLayer(layer.id),
                onLongPress: () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                  showLayerContextMenu(
                    context: context,
                    globalPosition: pos + const Offset(24, 24),
                    layerId: layer.id,
                    haptic: true,
                  );
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(8 + depth * 14.0, 6, 4, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (layer.clipToBelow)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.south_west, size: 14),
                            ),
                          if (layer is GroupLayer)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: controller.isGroupCollapsed(layer.id)
                                  ? '展开'
                                  : '折叠',
                              icon: Icon(
                                controller.isGroupCollapsed(layer.id)
                                    ? Icons.chevron_right
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              onPressed: () =>
                                  controller.toggleGroupCollapsed(layer.id),
                            )
                          else
                            Icon(_iconFor(layer), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              layer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (image != null && image.mask != null)
                            GestureDetector(
                              onTap: () {
                                final shift = HardwareKeyboard
                                    .instance.logicalKeysPressed
                                    .any(
                                  (key) =>
                                      key == LogicalKeyboardKey.shiftLeft ||
                                      key == LogicalKeyboardKey.shiftRight,
                                );
                                if (shift) {
                                  controller.toggleMaskEnabled(image.id);
                                } else {
                                  controller.selectLayer(image.id);
                                  controller.setMaskEditing(true);
                                }
                              },
                              child: Tooltip(
                                message: 'Shift+点击停用/恢复蒙版',
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white54),
                                    color: image.mask!.enabled
                                        ? Colors.white24
                                        : Colors.red.withOpacity(0.35),
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: layer.visible ? '隐藏' : '显示',
                            icon: Icon(
                              layer.visible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => controller.setVisible(
                              layer.id,
                              !layer.visible,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: layer.locked ? '解锁' : '锁定',
                            icon: Icon(
                              layer.locked ? Icons.lock : Icons.lock_open,
                              size: 18,
                            ),
                            onPressed: () => controller.setLocked(
                              layer.id,
                              !layer.locked,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(EditorLayer layer) {
    if (layer is GroupLayer) return Icons.folder_outlined;
    if (layer is AdjustmentLayer) return Icons.tune;
    return Icons.image_outlined;
  }
}
