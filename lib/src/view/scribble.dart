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
    print('Scribble build');
    return Stack(
      children: [
        if (webViewController != null)
          AbsorbPointer(
            child: WebViewWidget(
              controller: webViewController!,
            ),
          ),
        ValueListenableBuilder<ScribbleState>(
          valueListenable: notifier,
          builder: (context, state, _) {
            final drawCurrentTool =
                drawPen && state is Drawing || drawEraser && state is Erasing;

            return SizedBox.expand(
              child: Stack(
                children: [
                  if (backgroundImage != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BackgroundImagePainter(backgroundImage!),
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
          },
        ),
        ValueListenableBuilder<ScribbleState>(
          valueListenable: notifier,
          builder: (context, state, _) {
            return !state.active
                ? const SizedBox.shrink()
                : GestureCatcher(
                    pointerKindsToCatch: state.supportedPointerKinds,
                    child: MouseRegion(
                      cursor: drawPen &&
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
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
          },
        ),
      ],
    );
  }
}

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
