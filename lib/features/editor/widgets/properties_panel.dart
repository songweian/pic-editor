import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/adjustment_layer.dart';
import '../../../core/models/group_layer.dart';
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
    final image = controller.selectedImage;
    final selected = controller.selectedLayer;
    _syncName(image);

    if (selected == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('选中一个图层后可编辑属性'),
      );
    }

    if (selected is GroupLayer) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('图层组', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('穿透混合'),
            subtitle: const Text('关闭后封装为独立渲染黑盒'),
            value: selected.passThrough,
            onChanged: selected.locked
                ? null
                : (value) => controller.setPassThrough(selected.id, value),
          ),
          FilledButton.tonal(
            onPressed: selected.locked ? null : controller.ungroupSelected,
            child: const Text('取消编组'),
          ),
        ],
      );
    }

    if (selected is AdjustmentLayer) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(selected.kind.label,
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            min: -1,
            max: 1,
            value: selected.amount.clamp(-1, 1),
            onChanged: selected.locked
                ? null
                : (value) => controller.setAdjustmentAmount(selected.id, value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('剪贴到下一层'),
            value: selected.clipToBelow,
            onChanged: selected.locked
                ? null
                : (value) => controller.setClipToBelow(selected.id, value),
          ),
          FilledButton.tonal(
            onPressed: selected.locked ? null : controller.resetLayer,
            child: const Text('重置图层'),
          ),
        ],
      );
    }

    final layer = image;
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
          onChangeEnd: layer.locked ? null : (_) => controller.commitOpacity(),
        ),
        const SizedBox(height: 8),
        Text(
            '位置  ${layer.position.dx.toStringAsFixed(0)}, ${layer.position.dy.toStringAsFixed(0)}'),
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
              onPressed:
                  layer.locked ? null : () => controller.deleteLayer(layer.id),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
            OutlinedButton.icon(
              onPressed: layer.locked ? null : controller.addMaskToSelected,
              icon: const Icon(Icons.texture, size: 18),
              label: const Text('图层蒙版'),
            ),
            OutlinedButton.icon(
              onPressed: layer.locked ? null : controller.resetLayer,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('重置图层'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('亮度 ${(layer.brightness * 100).round()}'),
        Slider(
          min: -1,
          max: 1,
          value: layer.brightness.clamp(-1, 1),
          onChanged: layer.locked
              ? null
              : (value) => controller.previewLayer(
                    layer.copyWith(brightness: value),
                  ),
          onChangeEnd:
              layer.locked ? null : (_) => controller.commitTransient('亮度'),
        ),
        Text('对比度 ${(layer.contrast * 100).round()}'),
        Slider(
          min: -1,
          max: 1,
          value: layer.contrast.clamp(-1, 1),
          onChanged: layer.locked
              ? null
              : (value) => controller.previewLayer(
                    layer.copyWith(contrast: value),
                  ),
          onChangeEnd:
              layer.locked ? null : (_) => controller.commitTransient('对比度'),
        ),
        if (controller.maskEditing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '蒙版绘制：${controller.maskPaintBlack ? '黑=隐藏' : '白=恢复'}，在画布上拖拽。不要用橡皮擦。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
