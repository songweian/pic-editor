import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/web_editor_commands.dart';
import '../../state/editor_controller.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/layer_panel.dart';
import 'widgets/paper_picker.dart';
import 'widgets/properties_panel.dart';
import 'widgets/tool_bar.dart';

const double kWideBreakpoint = 900;

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      bindWebEditorCommands(
        controller: () => context.read<EditorController>(),
        openLayers: () => _openLayerSheet(context),
        importImages: () => importImagesFromUi(
          context,
          context.read<EditorController>(),
        ),
        exportPng: () => exportPngFromUi(
          context,
          context.read<EditorController>(),
        ),
      );
    });
  }

  @override
  void dispose() {
    unbindWebEditorCommands();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            controller.redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            controller.redo,
        const SingleActivator(LogicalKeyboardKey.delete):
            controller.deleteSelected,
        const SingleActivator(LogicalKeyboardKey.backspace):
            controller.deleteSelected,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (controller.cropMode) {
            controller.cancelCrop();
          } else if (controller.maskEditing) {
            controller.setMaskEditing(false);
          } else if (controller.isolating) {
            controller.exitIsolation();
          } else {
            controller.selectLayer(null);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true):
            controller.groupSelected,
        const SingleActivator(LogicalKeyboardKey.keyG, control: true):
            controller.groupSelected,
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true):
            controller.ungroupSelected,
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          control: true,
          shift: true,
        ): controller.ungroupSelected,
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true):
            controller.rasterizeSelected,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            controller.rasterizeSelected,
        const SingleActivator(LogicalKeyboardKey.keyG, alt: true):
            controller.clipSelectedToBelow,
        const SingleActivator(LogicalKeyboardKey.keyM, meta: true):
            controller.addMaskToSelected,
        const SingleActivator(LogicalKeyboardKey.keyM, control: true):
            controller.addMaskToSelected,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: EditorAppBar(compact: !wide),
          body: wide ? const _WideBody() : const _NarrowBody(),
          bottomNavigationBar: wide
              ? null
              : EditorBottomBar(
                  onOpenLayers: () => _openLayerSheet(context),
                ),
        ),
      ),
    );
  }
}

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EditorAppBar({super.key, required this.compact});

  final bool compact;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    if (controller.cropMode) {
      return AppBar(
        title: const Text('裁剪图片'),
        leading: IconButton(
          tooltip: '取消',
          onPressed: controller.cancelCrop,
          icon: const Icon(Icons.close),
        ),
        actions: [
          Semantics(
            button: true,
            label: '完成裁剪',
            child: TextButton(
              onPressed: controller.confirmCrop,
              child: const Text('完成'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
      titleSpacing: 8,
      title: compact
          ? const Text('纸张排版')
          : const Row(
              children: [
                Text('纸张排版'),
                SizedBox(width: 12),
                Flexible(child: PaperPickerButton()),
                OrientationToggle(),
              ],
            ),
      actions: [
        if (compact) const PaperPickerButton(compact: true),
        if (compact) const OrientationToggle(),
        IconButton(
          tooltip: controller.undoLabel == null
              ? '撤销'
              : '撤销 ${controller.undoLabel}',
          onPressed: controller.canUndo ? controller.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: controller.redoLabel == null
              ? '重做'
              : '重做 ${controller.redoLabel}',
          onPressed: controller.canRedo ? controller.redo : null,
          icon: const Icon(Icons.redo),
        ),
        PopupMenuButton<String>(
          tooltip: '画布缩放',
          onSelected: (value) {
            final viewport =
                controller.lastViewport ?? MediaQuery.sizeOf(context);
            if (value == 'fit') {
              controller.fitPaperTo(viewport);
            } else {
              controller.setZoomPercent(int.parse(value), viewport);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'fit', child: Text('适应纸张')),
            PopupMenuItem(value: '50', child: Text('50%')),
            PopupMenuItem(value: '100', child: Text('100%')),
            PopupMenuItem(value: '200', child: Text('200%')),
          ],
          icon: const Icon(Icons.zoom_in),
        ),
        IconButton(
          tooltip: '导出 PNG',
          onPressed: controller.exporting
              ? null
              : () => exportPngFromUi(context, controller),
          icon: controller.exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
        ),
      ],
    );
  }
}

class _WideBody extends StatelessWidget {
  const _WideBody();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        EditorToolRail(),
        Expanded(child: EditorCanvas()),
        VerticalDivider(width: 1),
        SizedBox(
          width: 300,
          child: Column(
            children: [
              Expanded(flex: 3, child: LayerPanel()),
              Divider(height: 1),
              Expanded(flex: 2, child: PropertiesPanel()),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowBody extends StatelessWidget {
  const _NarrowBody();

  @override
  Widget build(BuildContext context) {
    return const EditorCanvas();
  }
}

void _openLayerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: const Column(
          children: [
            Expanded(flex: 3, child: LayerPanel()),
            Divider(height: 1),
            Expanded(flex: 2, child: PropertiesPanel()),
          ],
        ),
      );
    },
  );
}

Future<void> exportPngFromUi(
  BuildContext context,
  EditorController controller,
) async {
  try {
    final path = await controller.exportPng();
    if (!context.mounted) return;
    if (path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出：$path')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导出失败：$error')),
    );
  }
}
