import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/paper_spec.dart';
import '../../../core/utils/units.dart';
import '../../../data/paper_presets.dart';
import '../../../state/editor_controller.dart';

class PaperPickerButton extends StatelessWidget {
  const PaperPickerButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    final paper = controller.paper;
    final mm = controller.document.sizeMm;
    return PopupMenuButton<String>(
      tooltip: controller.cropMode ? '裁剪时不能换纸张' : '选择纸张',
      enabled: !controller.cropMode && !controller.exporting,
      onSelected: controller.setPaper,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        for (final category in PaperCategory.values) {
          items.add(
            PopupMenuItem<String>(
              enabled: false,
              child: Text(
                category.label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
          for (final spec in PaperPresets.of(category)) {
            items.add(
              PopupMenuItem<String>(
                value: spec.id,
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: spec.id == paper.id
                          ? const Icon(Icons.check, size: 16)
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        '${spec.label}  ${formatMm(spec.widthMm)}×${formatMm(spec.heightMm)} mm',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
        return items;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.crop_portrait, size: 18),
            const SizedBox(width: 6),
            Text(
              compact
                  ? paper.label
                  : '${paper.label}  ${formatMm(mm.width)}×${formatMm(mm.height)} mm',
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class OrientationToggle extends StatelessWidget {
  const OrientationToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    return IconButton(
      tooltip: controller.cropMode
          ? '裁剪时不能改方向'
          : controller.landscape
              ? '当前横向，点击改为纵向'
              : '当前纵向，点击改为横向',
      onPressed: controller.cropMode ? null : controller.toggleOrientation,
      icon: Icon(
        controller.landscape ? Icons.crop_landscape : Icons.crop_portrait,
      ),
    );
  }
}
