import '../../state/editor_controller.dart';

void bindWebEditorCommands({
  required EditorController Function() controller,
  required void Function() openLayers,
  required Future<void> Function() importImages,
  required Future<void> Function() exportPng,
}) {}

void unbindWebEditorCommands() {}
