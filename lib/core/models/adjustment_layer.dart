import 'editor_layer.dart';

enum AdjustmentKind { brightness, contrast }

class AdjustmentLayer implements EditorLayer {
  const AdjustmentLayer({
    required this.id,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    required this.kind,
    required this.amount,
    this.clipToBelow = true,
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

  final AdjustmentKind kind;

  /// -1 .. 1
  final double amount;

  AdjustmentLayer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    AdjustmentKind? kind,
    double? amount,
    bool? clipToBelow,
  }) {
    return AdjustmentLayer(
      id: id,
      name: name ?? this.name,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      opacity: opacity ?? this.opacity,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
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

extension AdjustmentKindLabel on AdjustmentKind {
  String get label {
    switch (this) {
      case AdjustmentKind.brightness:
        return '亮度';
      case AdjustmentKind.contrast:
        return '对比度';
    }
  }
}
