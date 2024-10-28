import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scribble/src/view/notifier/scribble_notifier.dart';
import 'package:scribble/src/view/painting/scribble_editing_painter.dart';
import 'package:scribble/src/view/painting/scribble_painter.dart';
import 'package:scribble/src/view/pan_gesture_catcher.dart';
import 'package:scribble/src/view/state/scribble.state.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Scribble クラスの修正とデバッグ用ログ追加
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

            return Stack(
              children: [
                // 背景画像を描画
                if (backgroundImage != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BackgroundImagePainter(backgroundImage!),
                    ),
                  ),
                // スケッチ描画
                CustomPaint(
                  foregroundPainter: ScribbleEditingPainter(
                    state: state,
                    drawPointer: drawPen,
                    drawEraser: drawEraser,
                    simulatePressure: simulatePressure,
                  ),
                  child: RepaintBoundary(
                    key: notifier.repaintBoundaryKey,
                    child: CustomPaint(
                      painter: ScribblePainter(
                        sketch: state.sketch,
                        scaleFactor: state.scaleFactor,
                        simulatePressure: simulatePressure,
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
                          print('Pointer Down: $details');
                          notifier.onPointerDown(details);
                        },
                        onPointerMove: (details) {
                          print('Pointer Move: $details');
                          notifier.onPointerUpdate(details);
                        },
                        onPointerUp: (details) {
                          print('Pointer Up: $details');
                          notifier.onPointerUp(details);
                        },
                        onPointerHover: (details) {
                          print('Pointer Hover: $details');
                          notifier.onPointerHover(details);
                        },
                        onPointerCancel: (details) {
                          print('Pointer Cancel: $details');
                          notifier.onPointerCancel(details);
                        },
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
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
