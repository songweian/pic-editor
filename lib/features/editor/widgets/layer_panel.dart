import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/image_layer.dart';
import '../../../state/editor_controller.dart';
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
    final layers = controller.layers.reversed.toList();

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
                Text(
                  '${layers.length} 个',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        Expanded(
          child: layers.isEmpty
              ? const Center(
                  child: Text('还没有图层\n导入图片或添加示例图', textAlign: TextAlign.center),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: layers.length,
                  itemBuilder: (context, index) {
                    final layer = layers[index];
                    final selected = layer.id == controller.selectedLayerId;
                    final scheme = Theme.of(context).colorScheme;
                    return Listener(
                      key: ValueKey('layer-${layer.id}'),
                      onPointerDown: (event) {
                        if (event.buttons != kSecondaryMouseButton) return;
                        showLayerContextMenu(
                          context: context,
                          globalPosition: event.position,
                          layerId: layer.id,
                        );
                      },
                      child: GestureDetector(
                      onLongPressStart: (details) => showLayerContextMenu(
                        context: context,
                        globalPosition: details.globalPosition,
                        layerId: layer.id,
                        haptic: true,
                      ),
                      child: Material(
                        color: selected
                            ? scheme.primary.withOpacity(0.16)
                            : Colors.transparent,
                        child: InkWell(
                        onTap: () => controller.selectLayer(layer.id),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    layer is ImageLayer
                                        ? Icons.image_outlined
                                        : Icons.layers_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      layer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                      layer.locked
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      size: 18,
                                    ),
                                    onPressed: () => controller.setLocked(
                                      layer.id,
                                      !layer.locked,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    layer.locked
                                        ? '已锁定'
                                        : (layer.visible ? '可见' : '已隐藏'),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '上移一层',
                                    icon: const Icon(
                                      Icons.keyboard_arrow_up,
                                      size: 18,
                                    ),
                                    onPressed: controller.isTopLayer(layer.id)
                                        ? null
                                        : () => controller.moveLayer(
                                              layer.id,
                                              1,
                                            ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '下移一层',
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                    ),
                                    onPressed: controller.isBottomLayer(layer.id)
                                        ? null
                                        : () => controller.moveLayer(
                                              layer.id,
                                              -1,
                                            ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: '删除',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    onPressed: layer.locked
                                        ? null
                                        : () =>
                                            controller.deleteLayer(layer.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
