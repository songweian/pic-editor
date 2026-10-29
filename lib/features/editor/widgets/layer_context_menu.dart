import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/group_layer.dart';
import '../../../state/editor_controller.dart';

Future<void> showLayerContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String layerId,
  bool haptic = false,
}) async {
  final controller = context.read<EditorController>();
  if (controller.cropMode) return;
  if (controller.layerIndex(layerId) < 0) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
  final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);
  if (haptic) {
    HapticFeedback.mediumImpact();
  }
  controller.selectLayer(layerId);
  final layer = controller.selectedLayer;
  final isGroup = layer is GroupLayer;

  final selected = await showMenu<String>(
    context: navigator.context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlaySize.width - globalPosition.dx,
      overlaySize.height - globalPosition.dy,
    ),
    items: [
      const PopupMenuItem(
        value: 'isolate',
        child: _MenuRow(
          icon: Icons.filter_center_focus,
          label: '孤立显示',
        ),
      ),
      PopupMenuItem(
        value: 'clip',
        enabled: !controller.isBottomLayer(layerId),
        child: _MenuRow(
          icon: Icons.account_tree_outlined,
          label: layer?.clipToBelow == true ? '取消剪贴蒙版' : '创建剪贴蒙版',
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'up',
        enabled: !controller.isTopLayer(layerId),
        child: const _MenuRow(
          icon: Icons.keyboard_arrow_up,
          label: '上移一层',
        ),
      ),
      PopupMenuItem(
        value: 'down',
        enabled: !controller.isBottomLayer(layerId),
        child: const _MenuRow(
          icon: Icons.keyboard_arrow_down,
          label: '下移一层',
        ),
      ),
      PopupMenuItem(
        value: 'front',
        enabled: !controller.isTopLayer(layerId),
        child: const _MenuRow(
          icon: Icons.flip_to_front,
          label: '置于顶层',
        ),
      ),
      PopupMenuItem(
        value: 'back',
        enabled: !controller.isBottomLayer(layerId),
        child: const _MenuRow(
          icon: Icons.flip_to_back,
          label: '置于底层',
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: isGroup ? 'ungroup' : 'group',
        child: _MenuRow(
          icon: isGroup ? Icons.layers_clear : Icons.layers,
          label: isGroup ? '取消编组' : '编组',
        ),
      ),
      const PopupMenuItem(
        value: 'rasterize',
        child: _MenuRow(
          icon: Icons.auto_awesome_mosaic_outlined,
          label: '栅格化',
        ),
      ),
    ],
  );
  if (!context.mounted || selected == null) return;
  switch (selected) {
    case 'isolate':
      controller.isolateLayer(layerId);
      break;
    case 'clip':
      controller.clipSelectedToBelow();
      break;
    case 'up':
      controller.moveLayer(layerId, 1);
      break;
    case 'down':
      controller.moveLayer(layerId, -1);
      break;
    case 'front':
      controller.bringToFront(layerId);
      break;
    case 'back':
      controller.sendToBack(layerId);
      break;
    case 'group':
      controller.groupSelected();
      break;
    case 'ungroup':
      controller.ungroupSelected();
      break;
    case 'rasterize':
      await controller.rasterizeSelected();
      break;
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
