import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

  final selected = await showMenu<String>(
    context: navigator.context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlaySize.width - globalPosition.dx,
      overlaySize.height - globalPosition.dy,
    ),
    items: [
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
      const PopupMenuDivider(),
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
    ],
  );
  if (!context.mounted || selected == null) return;
  switch (selected) {
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
