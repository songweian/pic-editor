import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/image_layer.dart';
import '../../../core/utils/units.dart';
import '../../../state/editor_controller.dart';
import '../gestures/two_finger_tap.dart';
import 'crop_overlay.dart';
import 'layer_context_menu.dart';
import 'paper_surface.dart';
import 'selection_overlay.dart';

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key});

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  int _fittedGeneration = -1;
  _DragSession? _drag;
  final TwoFingerTapTracker _twoFinger = TwoFingerTapTracker();
  Matrix4? _viewBeforeTwoFinger;
  Offset? _twoFingerCentroid;
  bool _blockOneFinger = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EditorController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (viewport.width > 0 &&
            viewport.height > 0 &&
            _fittedGeneration != controller.viewGeneration) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_fittedGeneration == controller.viewGeneration) return;
            _fittedGeneration = controller.viewGeneration;
            controller.fitPaperTo(viewport);
          });
        }

        final selected = controller.selectedImage;
        final viewScale = controller.viewScale.clamp(0.05, 8.0);
        final paper = controller.paperSizePx;
        final mm = controller.document.sizeMm;

        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final factor = event.scrollDelta.dy > 0 ? 0.92 : 1.08;
              controller.zoomAt(event.localPosition, factor);
            }
          },
          onPointerDown: (event) {
            _twoFinger.down(event.pointer, event.position);
            if (_twoFinger.isTwoFinger) {
              _drag = null;
              controller.cancelTransient();
              _blockOneFinger = true;
              _viewBeforeTwoFinger ??= controller.copyViewMatrix();
              _twoFingerCentroid = _twoFinger.centroid;
            }
          },
          onPointerMove: (event) {
            _twoFinger.move(event.pointer, event.position);
            if (!_twoFinger.isTwoFinger) return;
            final next = _twoFinger.centroid;
            if (!controller.panMode &&
                _twoFinger.moved &&
                !_twoFinger.isPinch &&
                _twoFingerCentroid != null) {
              controller.panBy(next - _twoFingerCentroid!);
            }
            if (_twoFinger.moved) {
              _viewBeforeTwoFinger = null;
            }
            _twoFingerCentroid = next;
          },
          onPointerUp: (event) => _onViewportPointerUp(controller, event),
          onPointerCancel: (event) {
            _twoFinger.cancel(event.pointer);
            _twoFingerCentroid =
                _twoFinger.isTwoFinger ? _twoFinger.centroid : null;
            if (_twoFinger.pointerCount == 0) {
              _blockOneFinger = false;
              _viewBeforeTwoFinger = null;
            }
          },
          child: Stack(
            children: [
              ColoredBox(
                color: const Color(0xFF0E1013),
                child: InteractiveViewer(
                  transformationController: controller.viewTransform,
                  constrained: false,
                  minScale: 0.05,
                  maxScale: 8,
                  panEnabled: controller.panMode,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: SizedBox(
                    width: paper.width,
                    height: paper.height,
                    child: GestureDetector(
                      onDoubleTapDown: (details) {
                        if (controller.panMode || controller.cropMode) return;
                        final hit = controller.hitTest(
                          details.localPosition,
                          includeLocked: true,
                          deep: true,
                        );
                        if (hit != null) controller.isolateLayer(hit.id);
                      },
                      onLongPressStart: (details) {
                        if (controller.panMode ||
                            controller.cropMode ||
                            _twoFinger.isTwoFinger ||
                            _blockOneFinger) {
                          return;
                        }
                        _drag = null;
                        controller.cancelTransient();
                        _onContextMenu(
                          controller,
                          details.localPosition,
                          details.globalPosition,
                          haptic: true,
                        );
                      },
                      child: Listener(
                        onPointerDown: (event) {
                          if (event.buttons == kSecondaryMouseButton) {
                            _drag = null;
                            _onContextMenu(
                              controller,
                              event.localPosition,
                              event.position,
                            );
                            return;
                          }
                          if (_twoFinger.isTwoFinger || _blockOneFinger) {
                            return;
                          }
                          _onDown(controller, event.localPosition);
                        },
                        onPointerMove: (event) {
                          if (_twoFinger.isTwoFinger || _blockOneFinger) {
                            return;
                          }
                          _onMove(controller, event.localPosition);
                        },
                        onPointerUp: (_) {
                          if (_blockOneFinger) return;
                          _onUp(controller);
                        },
                        onPointerCancel: (_) {
                          if (_blockOneFinger) return;
                          _onUp(controller);
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            PaperBoard(controller: controller),
                            if (selected != null &&
                                selected.visible &&
                                !controller.cropMode)
                              Positioned.fill(
                                child: LayerSelectionOverlay(
                                  layer: selected,
                                  viewScale: viewScale,
                                ),
                              ),
                            if (controller.cropMode && selected != null)
                              Positioned.fill(
                                child: CropOverlay(
                                  layer: selected,
                                  crop: controller.workingCrop,
                                  viewScale: viewScale,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (controller.isolating)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xCC07080A),
                          width: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              if (controller.isolating)
                Positioned(
                  left: 12,
                  top: 12,
                  right: 12,
                  child: _BreadcrumbBar(controller: controller),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _StatusChip(
                  text:
                      '${controller.paper.label} · ${controller.landscape ? '横向' : '纵向'} · '
                      '${formatMm(mm.width)}×${formatMm(mm.height)} mm · '
                      '${paper.width.round()}×${paper.height.round()} px · '
                      '${(controller.viewScale * 100).round()}%',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onViewportPointerUp(
    EditorController controller,
    PointerEvent event,
  ) {
    final tap = _twoFinger.up(event.pointer);
    if (tap != null) {
      final saved = _viewBeforeTwoFinger;
      void restore() {
        if (saved != null) controller.restoreViewMatrix(saved);
      }

      restore();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) restore();
      });
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final paper = controller.viewportToPaper(box.globalToLocal(tap));
        _onContextMenu(
          controller,
          paper,
          tap,
          haptic: true,
          allowInPanMode: true,
        );
      }
    }
    _twoFingerCentroid = _twoFinger.isTwoFinger ? _twoFinger.centroid : null;
    if (_twoFinger.pointerCount == 0) {
      _blockOneFinger = false;
      _viewBeforeTwoFinger = null;
    }
  }

  void _onContextMenu(
    EditorController controller,
    Offset paperPoint,
    Offset globalPosition, {
    bool haptic = false,
    bool allowInPanMode = false,
  }) {
    if (controller.cropMode) return;
    if (controller.panMode && !allowInPanMode) return;
    final hit = controller.hitTest(
      paperPoint,
      includeLocked: true,
      deep: _deepSelect,
    );
    if (hit == null) {
      controller.selectLayer(null);
      return;
    }
    showLayerContextMenu(
      context: context,
      globalPosition: globalPosition,
      layerId: hit.id,
      haptic: haptic,
    );
  }

  bool get _deepSelect {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  void _onDown(EditorController controller, Offset paperPoint) {
    if (controller.panMode) return;
    if (controller.maskEditing) {
      controller.paintMaskAt(paperPoint);
      return;
    }

    final selected = controller.selectedImage;
    if (controller.cropMode && selected != null) {
      final handle = hitCropHandle(
        layer: selected,
        crop: controller.workingCrop,
        paperPoint: paperPoint,
        viewScale: controller.viewScale,
      );
      if (handle != null) {
        _drag = _DragSession(
          kind: _DragKind.crop,
          cropHandle: handle,
          startLayer: selected,
          startPaper: paperPoint,
          startCrop: controller.workingCrop,
        );
      }
      return;
    }

    if (selected != null && !selected.locked && selected.visible) {
      final handle = hitHandle(
        layer: selected,
        paperPoint: paperPoint,
        viewScale: controller.viewScale,
      );
      if (handle != null) {
        _drag = _DragSession(
          kind: _DragKind.handle,
          handle: handle,
          startLayer: selected,
          startPaper: paperPoint,
        );
        return;
      }
      if (selected.containsPaperPoint(paperPoint)) {
        _drag = _DragSession(
          kind: _DragKind.move,
          startLayer: selected,
          startPaper: paperPoint,
        );
        return;
      }
    }

    final hit = controller.hitTest(paperPoint, deep: _deepSelect);
    if (hit == null) {
      if (controller.isolating) {
        controller.exitIsolation();
      } else {
        controller.selectLayer(null);
      }
      _drag = null;
      return;
    }
    controller.selectLayer(hit.id);
    if (hit is ImageLayer && !hit.locked) {
      _drag = _DragSession(
        kind: _DragKind.move,
        startLayer: hit,
        startPaper: paperPoint,
      );
    } else {
      _drag = null;
    }
  }

  void _onMove(EditorController controller, Offset paperPoint) {
    if (controller.maskEditing) {
      controller.paintMaskAt(paperPoint);
      return;
    }
    final drag = _drag;
    if (drag == null) return;
    if ((paperPoint - drag.startPaper).distance < 1.5 && !drag.moved) {
      return;
    }
    if (!drag.moved && drag.kind != _DragKind.crop) {
      controller.beginTransient();
      drag.moved = true;
    } else {
      drag.moved = true;
    }

    if (drag.kind == _DragKind.crop) {
      final localDelta = drag.startLayer.toLocal(paperPoint) -
          drag.startLayer.toLocal(drag.startPaper);
      final next = applyCropHandle(
        start: drag.startCrop ?? const Rect.fromLTWH(0, 0, 1, 1),
        handle: drag.cropHandle ?? CropHandle.move,
        localDelta: localDelta,
        displaySize: drag.startLayer.displaySize,
      );
      controller.updateWorkingCrop(next);
      return;
    }

    if (drag.kind == _DragKind.move) {
      final delta = paperPoint - drag.startPaper;
      controller.previewLayer(
        drag.startLayer.copyWith(position: drag.startLayer.position + delta),
      );
      return;
    }

    if (drag.kind == _DragKind.handle && drag.handle != null) {
      controller.previewLayer(
        controller.applyHandle(
          start: drag.startLayer,
          handle: drag.handle!,
          currentPaper: paperPoint,
          startPaper: drag.startPaper,
        ),
      );
    }
  }

  void _onUp(EditorController controller) {
    if (controller.maskEditing) {
      controller.commitTransient('绘制蒙版');
    }
    final drag = _drag;
    _drag = null;
    if (drag == null || drag.kind == _DragKind.crop || !drag.moved) {
      return;
    }
    switch (drag.kind) {
      case _DragKind.move:
        controller.commitTransient('移动图层');
        break;
      case _DragKind.handle:
        controller.commitTransient(
          drag.handle == HandleKind.rotate ? '旋转图层' : '缩放图层',
        );
        break;
      case _DragKind.crop:
        break;
    }
  }
}

enum _DragKind { move, handle, crop }

class _DragSession {
  _DragSession({
    required this.kind,
    required this.startLayer,
    required this.startPaper,
    this.handle,
    this.cropHandle,
    this.startCrop,
  });

  final _DragKind kind;
  final ImageLayer startLayer;
  final Offset startPaper;
  final HandleKind? handle;
  final CropHandle? cropHandle;
  final Rect? startCrop;
  bool moved = false;
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final names = controller.breadcrumbNames;
    final ids = controller.breadcrumbIds;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '路径导航',
      child: Material(
        color: const Color(0xE11C1E22),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => controller.exitIsolation(),
                  child: const Text('主画布'),
                ),
                for (var i = 0; i < names.length; i++) ...[
                  const Icon(Icons.chevron_right,
                      size: 16, color: Colors.white54),
                  TextButton(
                    onPressed: () => controller.jumpBreadcrumb(ids[i]),
                    child: Text(names[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1C1E22),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
      ),
    );
  }
}
