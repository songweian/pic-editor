import '../models/editor_document.dart';

abstract class EditorCommand {
  String get label;
  EditorDocument apply(EditorDocument current);
  EditorDocument revert(EditorDocument current);
}

class DocumentCommand implements EditorCommand {
  const DocumentCommand({
    required this.label,
    required this.before,
    required this.after,
  });

  @override
  final String label;
  final EditorDocument before;
  final EditorDocument after;

  @override
  EditorDocument apply(EditorDocument current) => after;

  @override
  EditorDocument revert(EditorDocument current) => before;
}
