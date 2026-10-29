import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/place_mode.dart';
import '../../../state/editor_controller.dart';
import '../tools/import_images.dart';

class EditorToolRail extends StatelessWidget {
  const EditorToolRail({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    return ColoredBox(
      color: const Color(0xFF1C1E22),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 88,
          child: ScrollConfiguration(
            behavior: const _ToolbarScrollBehavior(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: _toolItems(context, controller, vertical: true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditorBottomBar extends StatelessWidget {
  const EditorBottomBar({super.key, required this.onOpenLayers});

  final VoidCallback onOpenLayers;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    return ColoredBox(
      color: const Color(0xFF1C1E22),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: ScrollConfiguration(
            behavior: const _ToolbarScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  ..._toolItems(context, controller, vertical: false),
                  _ToolButton(
                    icon: Icons.layers_outlined,
                    label: '图层',
                    vertical: false,
                    onPressed: onOpenLayers,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarScrollBehavior extends MaterialScrollBehavior {
  const _ToolbarScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

List<Widget> _toolItems(
  BuildContext context,
  EditorController controller, {
  required bool vertical,
}) {
  final hasLayer = controller.selectedImage != null;
  final locked = controller.selectedImage?.locked ?? true;
  return [
    _ToolButton(
      icon: Icons.touch_app,
      label: '选择',
      vertical: vertical,
      selected: !controller.panMode,
      onPressed: () => controller.setPanMode(false),
    ),
    _ToolButton(
      icon: Icons.pan_tool,
      label: '平移',
      vertical: vertical,
      selected: controller.panMode,
      onPressed: () => controller.setPanMode(true),
    ),
    _ToolButton(
      icon: Icons.add_photo_alternate_outlined,
      label: '导入',
      vertical: vertical,
      onPressed: () => importImagesFromUi(context, controller),
    ),
    _ToolButton(
      icon: Icons.dashboard_outlined,
      label: '示例图',
      vertical: vertical,
      onPressed: controller.addSampleImages,
    ),
    _ToolButton(
      icon: Icons.fit_screen,
      label: PlaceMode.fit.label,
      vertical: vertical,
      onPressed: hasLayer && !locked
          ? () => controller.applyPlaceMode(PlaceMode.fit)
          : null,
    ),
    _ToolButton(
      icon: Icons.aspect_ratio,
      label: PlaceMode.fill.label,
      vertical: vertical,
      onPressed: hasLayer && !locked
          ? () => controller.applyPlaceMode(PlaceMode.fill)
          : null,
    ),
    _ToolButton(
      icon: Icons.crop_original,
      label: PlaceMode.original.label,
      vertical: vertical,
      onPressed: hasLayer && !locked
          ? () => controller.applyPlaceMode(PlaceMode.original)
          : null,
    ),
    _ToolButton(
      icon: Icons.crop,
      label: '裁剪',
      vertical: vertical,
      selected: controller.cropMode,
      onPressed: hasLayer && !locked ? controller.enterCrop : null,
    ),
    _ToolButton(
      icon: Icons.flip,
      label: '水平翻转',
      vertical: vertical,
      onPressed: hasLayer && !locked ? controller.flipHorizontal : null,
    ),
    _ToolButton(
      icon: Icons.swap_vert,
      label: '垂直翻转',
      vertical: vertical,
      onPressed: hasLayer && !locked ? controller.flipVertical : null,
    ),
    _ToolButton(
      icon: Icons.delete_outline,
      label: '删除',
      vertical: vertical,
      onPressed: hasLayer && !locked ? controller.deleteSelected : null,
    ),
  ];
}

Future<void> importImagesFromUi(
  BuildContext context,
  EditorController controller,
) async {
  try {
    final count = await controller.importImages();
    if (!context.mounted) return;
    final text = importSuccessMessage(count);
    if (text == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  } catch (error, stack) {
    debugPrint('导入失败: $error\n$stack');
    if (!context.mounted) return;
    if (isPickerCancel(error)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(importErrorMessage(error))),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.vertical,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool vertical;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = selected
        ? scheme.primary
        : (enabled ? scheme.onSurface : Colors.white24);
    final item = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: vertical ? 8 : 12,
          vertical: 8,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor:
            selected ? scheme.primary.withOpacity(0.16) : Colors.transparent,
      ),
      child: item,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: vertical ? button : SizedBox(width: 76, child: button),
    );
  }
}
