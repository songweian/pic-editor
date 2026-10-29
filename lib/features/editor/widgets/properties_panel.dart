import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/image_layer.dart';
import '../../../state/editor_controller.dart';

class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({super.key});

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  late final TextEditingController _nameController;
  String? _boundId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncName(ImageLayer? layer) {
    if (layer == null) {
      if (_boundId != null) {
        _boundId = null;
        _nameController.clear();
      }
      return;
    }
    if (_boundId != layer.id) {
      _boundId = layer.id;
      _nameController.text = layer.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final layer = controller.selectedImage;
    _syncName(layer);

    if (layer == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('选中一个图片图层后可编辑属性'),
      );
    }

    final rotationDeg = layer.rotation * 180 / 3.141592653589793;
    final scalePct =
        ((layer.scaleX.abs() + layer.scaleY.abs()) / 2 * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('属性', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          enabled: !layer.locked,
          decoration: const InputDecoration(
            labelText: '名称',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => controller.renameLayer(layer.id, value),
          onTapOutside: (_) =>
              controller.renameLayer(layer.id, _nameController.text),
        ),
        const SizedBox(height: 16),
        Text('不透明度 ${(layer.opacity * 100).round()}%'),
        Slider(
          value: layer.opacity.clamp(0.0, 1.0),
          onChanged: layer.locked ? null : controller.previewOpacity,
          onChangeEnd: layer.locked
              ? null
              : (_) => controller.commitOpacity(),
        ),
        const SizedBox(height: 8),
        Text('位置  ${layer.position.dx.toStringAsFixed(0)}, ${layer.position.dy.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        Text(
          '旋转  ${rotationDeg.toStringAsFixed(1)}°    缩放  $scalePct%',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: layer.locked ? null : controller.flipHorizontal,
              icon: const Icon(Icons.flip, size: 18),
              label: const Text('水平翻转'),
            ),
            OutlinedButton.icon(
              onPressed: layer.locked ? null : controller.flipVertical,
              icon: const Icon(Icons.flip, size: 18),
              label: const Text('垂直翻转'),
            ),
            OutlinedButton.icon(
              onPressed: layer.locked ? null : controller.enterCrop,
              icon: const Icon(Icons.crop, size: 18),
              label: const Text('裁剪'),
            ),
            OutlinedButton.icon(
              onPressed: layer.locked
                  ? null
                  : () => controller.deleteLayer(layer.id),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
          ],
        ),
      ],
    );
  }
}
