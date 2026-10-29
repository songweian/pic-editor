import 'editor_layer.dart';

enum GroupBlend { passThrough, normal }

class GroupLayer implements EditorLayer {
  const GroupLayer({
    required this.id,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    required this.children,
    this.passThrough = true,
    this.clipToBelow = false,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final bool visible;
  @override
  final bool locked;
  @override
  final double opacity;
  @override
  final bool clipToBelow;

  final List<EditorLayer> children;
  final bool passThrough;

  GroupBlend get blend =>
      passThrough ? GroupBlend.passThrough : GroupBlend.normal;

  GroupLayer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    List<EditorLayer>? children,
    bool? passThrough,
    bool? clipToBelow,
  }) {
    return GroupLayer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      children: children ?? this.children,
      passThrough: passThrough ?? this.passThrough,
      clipToBelow: clipToBelow ?? this.clipToBelow,
    );
  }

  @override
  EditorLayer copyLayer({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    bool? clipToBelow,
  }) {
    return copyWith(
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
      clipToBelow: clipToBelow,
    );
  }
}
