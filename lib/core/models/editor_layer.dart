abstract class EditorLayer {
  String get id;
  String get name;
  bool get visible;
  bool get locked;
  double get opacity;

  EditorLayer copyLayer({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
  });
}
