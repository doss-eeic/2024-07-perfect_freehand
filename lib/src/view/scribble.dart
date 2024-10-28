import 'dart:ui' as ui; // dart:uiを使用して低レベルなImageを扱う

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:scribble/src/view/notifier/scribble_notifier.dart';
import 'package:scribble/src/view/painting/scribble_editing_painter.dart';
import 'package:scribble/src/view/painting/scribble_painter.dart';
import 'package:scribble/src/view/pan_gesture_catcher.dart';
import 'package:scribble/src/view/state/scribble.state.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// {@template scribble}
/// This Widget represents a canvas on which users can draw with any pointer.
///
/// You can control its behavior from code using the [notifier] instance you
/// pass in.
/// {@endtemplate}
class Scribble extends StatelessWidget {
  /// {@macro scribble}
  const Scribble({
    /// The notifier that controls this canvas.
    required this.notifier,

    /// Whether to draw the pointer when in drawing mode
    this.drawPen = true,

    /// Whether to draw the pointer when in erasing mode
    this.drawEraser = true,

    /// Whether to simulate pressure when drawing lines that don't have pressure
    /// information (all points have the same pressure).
    this.simulatePressure = true,

    /// Background image to display behind the scribble area
    this.backgroundImage,
    this.webViewController,
    super.key,
  });

  /// The notifier that controls this canvas.
  final ScribbleNotifierBase notifier;

  /// Whether to draw the pointer when in drawing mode
  final bool drawPen;

  /// Whether to draw the pointer when in erasing mode
  final bool drawEraser;

  /// Whether to simulate pressure when drawing lines without pressure data
  final bool simulatePressure;

  /// Background image to display behind the scribble area
  final ui.Image? backgroundImage; // dart:uiのImage型を使う背景画像プロパティ
  final WebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScribbleState>(
      valueListenable: notifier,
      builder: (context, state, _) {
        final drawCurrentTool =
            drawPen && state is Drawing || drawEraser && state is Erasing;

        final child = SizedBox.expand(
          child: Stack(
            // Stackで背景と書き込みエリアを重ねる
            children: [
              if (webViewController != null)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: WebViewWidget(
                      controller: webViewController!,
                    ),
                  ),
                ),
              if (backgroundImage != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter:
                        BackgroundImagePainter(backgroundImage!), // 背景画像を描画
                  ),
                ),
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
            ],
          ),
        );

        return !state.active
            ? child
            : GestureCatcher(
                pointerKindsToCatch: state.supportedPointerKinds,
                child: MouseRegion(
                  cursor: drawCurrentTool &&
                          state.supportedPointerKinds
                              .contains(PointerDeviceKind.mouse)
                      ? SystemMouseCursors.none
                      : MouseCursor.defer,
                  onExit: notifier.onPointerExit,
                  child: Listener(
                    onPointerDown: notifier.onPointerDown,
                    onPointerMove: notifier.onPointerUpdate,
                    onPointerUp: notifier.onPointerUp,
                    onPointerHover: notifier.onPointerHover,
                    onPointerCancel: notifier.onPointerCancel,
                    child: child,
                  ),
                ),
              );
      },
    );
  }
}

/// CustomPainter to draw the background image
class BackgroundImagePainter extends CustomPainter {
  BackgroundImagePainter(this.backgroundImage);
  final ui.Image backgroundImage;

  @override
  void paint(Canvas canvas, Size size) {
    // 画像をキャンバス全体に合わせて描画する
    final paint = Paint();
    final imageSize = Size(
      backgroundImage.width.toDouble(),
      backgroundImage.height.toDouble(),
    );
    final srcRect = Offset.zero & imageSize;
    final dstRect = Offset.zero & size; // 背景をウィジェット全体にフィットさせる

    canvas.drawImageRect(backgroundImage, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
