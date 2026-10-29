import '../models/editor_document.dart';
import 'editor_command.dart';

class CommandHistory {
  final List<EditorCommand> _undo = <EditorCommand>[];
  final List<EditorCommand> _redo = <EditorCommand>[];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  void pushApplied(EditorCommand command) {
    _undo.add(command);
    _redo.clear();
  }

  EditorDocument undo(EditorDocument current) {
    if (_undo.isEmpty) return current;
    final command = _undo.removeLast();
    _redo.add(command);
    return command.revert(current);
  }

  EditorDocument redo(EditorDocument current) {
    if (_redo.isEmpty) return current;
    final command = _redo.removeLast();
    _undo.add(command);
    return command.apply(current);
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
