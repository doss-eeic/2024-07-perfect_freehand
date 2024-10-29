import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scribble/src/view/notifier/scribble_notifier.dart';
import 'package:scribble/src/view/painting/scribble_editing_painter.dart';
import 'package:scribble/src/view/painting/scribble_painter.dart';
import 'package:scribble/src/view/pan_gesture_catcher.dart';
import 'package:scribble/src/view/state/scribble.state.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Scribble extends StatelessWidget {
  const Scribble({
    required this.notifier,
    this.drawPen = true,
    this.drawEraser = true,
    this.simulatePressure = true,
    this.backgroundImage,
    this.webViewController,
    super.key,
  });

  final ScribbleNotifierBase notifier;
  final bool drawPen;
  final bool drawEraser;
  final bool simulatePressure;
  final ui.Image? backgroundImage;
  final WebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (webViewController != null)
          WebViewWidget(
            controller: webViewController!,
          ),
        ValueListenableBuilder<ScribbleState>(
          valueListenable: notifier,
          builder: (context, state, _) {
            final drawCurrentTool =
                drawPen && state is Drawing || drawEraser && state is Erasing;

            return ClipRect(
              // ClipRectを追加して範囲外での描画を防ぐ
              child: Stack(
                children: [
                  // 背景画像を描画
                  if (backgroundImage != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BackgroundImagePainter(backgroundImage!),
                      ),
                    ),

                  Positioned.fill(
                    child: CustomPaint(
                      foregroundPainter: ScribbleEditingPainter(
                        state: state,
                        drawPointer: drawPen,
                        drawEraser: drawEraser,
                        simulatePressure: simulatePressure,
                      ),
                      child: RepaintBoundary(
                        key: notifier.repaintBoundaryKey,
                        child: Builder(
                          builder: (context) {
                            // RenderRepaintBoundary のサイズをログに出力
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final renderBox =
                                  context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                print(
                                  "RepaintBoundary size: ${renderBox.size.width} x ${renderBox.size.height}",
                                );
                              }
                            });
                            return CustomPaint(
                              painter: ScribblePainter(
                                sketch: state.sketch,
                                scaleFactor: state.scaleFactor,
                                simulatePressure: simulatePressure,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // ジェスチャーイベントの処理
                  if (state.active)
                    GestureCatcher(
                      pointerKindsToCatch: state.supportedPointerKinds,
                      child: MouseRegion(
                        cursor: drawPen &&
                                state.supportedPointerKinds
                                    .contains(PointerDeviceKind.mouse)
                            ? SystemMouseCursors.none
                            : MouseCursor.defer,
                        onExit: notifier.onPointerExit,
                        child: Listener(
                          onPointerDown: (details) {
                            // 描画範囲を超えないように制限
                            _handlePointerEventWithinBounds(details, context,
                                () {
                              notifier.onPointerDown(details);
                            });
                          },
                          onPointerMove: (details) {
                            _handlePointerEventWithinBounds(details, context,
                                () {
                              notifier.onPointerUpdate(details);
                            });
                          },
                          onPointerUp: notifier.onPointerUp,
                          onPointerHover: notifier.onPointerHover,
                          onPointerCancel: notifier.onPointerCancel,
                          child: Container(
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ポインタイベントがScribbleの範囲内かどうかをチェック
  void _handlePointerEventWithinBounds(
    PointerEvent details,
    BuildContext context,
    VoidCallback callback,
  ) {
    final renderBox = context.findRenderObject()! as RenderBox;
    final localPosition = renderBox.globalToLocal(details.position);

    // 描画範囲内か確認する
    if (localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= renderBox.size.width &&
        localPosition.dy <= renderBox.size.height) {
      callback();
    }
  }
}

/// CustomPainter to draw the background image
class BackgroundImagePainter extends CustomPainter {
  BackgroundImagePainter(this.backgroundImage);
  final ui.Image backgroundImage;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final imageSize = Size(
      backgroundImage.width.toDouble(),
      backgroundImage.height.toDouble(),
    );
    final srcRect = Offset.zero & imageSize;
    final dstRect = Offset.zero & size;

    canvas.drawImageRect(backgroundImage, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
