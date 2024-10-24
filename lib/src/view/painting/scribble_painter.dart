import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scribble/scribble.dart';
import 'package:scribble/src/view/painting/scribble_editing_painter.dart';
import 'package:scribble/src/view/painting/sketch_line_path_mixin.dart';
import 'package:scribble/src/view/pan_gesture_catcher.dart';
import 'package:xml/xml.dart';

/// A painter for drawing a scribble sketch.
class ScribblePainter extends CustomPainter with SketchLinePathMixin {
  /// Creates a new [ScribblePainter] instance.
  ScribblePainter({
    required this.sketch,
    required this.scaleFactor,
    required this.simulatePressure,
  });

  /// The [Sketch] to draw.
  final Sketch sketch;

  /// {@macro view.state.scribble_state.scale_factor}
  final double scaleFactor;

  @override
  final bool simulatePressure;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < sketch.lines.length; ++i) {
      final path = getPathForLine(
        sketch.lines[i],
        scaleFactor: scaleFactor,
      );
      if (path == null) {
        continue;
      }
      paint.color = Color(sketch.lines[i].color);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ScribblePainter oldDelegate) {
    return oldDelegate.sketch != sketch ||
        oldDelegate.simulatePressure != simulatePressure ||
        oldDelegate.scaleFactor != scaleFactor;
  }
}

/// BackgroundPainter class for drawing SVG background excluding polyline
class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.svgDocument);
  final XmlDocument svgDocument;

  @override
  void paint(Canvas canvas, Size size) {
    final svgRoot = svgDocument.rootElement;

    // Iterate over all elements except polyline and draw them as a background
    for (final element in svgRoot.children) {
      if (element is XmlElement && element.name.local != 'polyline') {
        // Handle different SVG elements like 'rect', 'circle', etc.
        if (element.name.local == 'rect') {
          final x = double.parse(element.getAttribute('x') ?? '0');
          final y = double.parse(element.getAttribute('y') ?? '0');
          final width = double.parse(element.getAttribute('width') ?? '100');
          final height = double.parse(element.getAttribute('height') ?? '100');
          final paint = Paint()
            ..color = _parseHexColor(element.getAttribute('fill') ?? '#000000');
          canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
        } else if (element.name.local == 'circle') {
          final cx = double.parse(element.getAttribute('cx') ?? '0');
          final cy = double.parse(element.getAttribute('cy') ?? '0');
          final r = double.parse(element.getAttribute('r') ?? '0');
          final paint = Paint()
            ..color = _parseHexColor(element.getAttribute('fill') ?? '#000000');
          canvas.drawCircle(Offset(cx, cy), r, paint);
        } else if (element.name.local == 'text') {
          final x = double.parse(element.getAttribute('x') ?? '0');
          final y = double.parse(element.getAttribute('y') ?? '0');
          final textContent = element.text;
          final textPainter = TextPainter(
            text: TextSpan(
              text: textContent,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(x, y));
        }
        // Add more element types as needed
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  // Utility to parse hex color
  Color _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

/// Scribble widget with background SVG drawing support
class ScribbleWithBackground extends StatelessWidget {
  const ScribbleWithBackground({
    required this.notifier,
    required this.svgDocument,
    this.drawPen = true,
    this.drawEraser = true,
    this.simulatePressure = true,
    super.key,
  });

  /// The notifier that controls this canvas.
  final ScribbleNotifierBase notifier;

  /// SVG document to use as a background (excluding polylines)
  final XmlDocument svgDocument;

  /// Whether to draw the pointer when in drawing mode
  final bool drawPen;

  /// Whether to draw the pointer when in erasing mode
  final bool drawEraser;

  /// Whether to simulate pressure when drawing
  final bool simulatePressure;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScribbleState>(
      valueListenable: notifier,
      builder: (context, state, _) {
        final drawCurrentTool =
            drawPen && state is Drawing || drawEraser && state is Erasing;
        final child = SizedBox.expand(
          child: Stack(
            children: [
              // Background Painter to draw non-polyline elements
              CustomPaint(
                painter: BackgroundPainter(svgDocument),
                child: Container(),
              ),
              // Foreground Scribble canvas for drawing polylines
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

class SvgWithHtml extends StatelessWidget {
  const SvgWithHtml({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SVG with HTML content")),
      body: Column(
        children: [
          // SVG部分の表示
          SvgPicture.asset(
            'assets/images/segment.svg',
            // `flutter_svg`はforeignObjectを無視します
            width: 300,
            height: 200,
          ),
          // 外部のHTML部分をFlutterで再現
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "図形と方程式の講義テキスト",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  "「図形と方程式」は高校数学でとても重要な単元です。"
                  "ここでは、図形を数式で表したり、数式から図形を描いたりします。",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScribbleWithBackgroundExample extends StatefulWidget {
  const ScribbleWithBackgroundExample({super.key});

  @override
  _ScribbleWithBackgroundExampleState createState() =>
      _ScribbleWithBackgroundExampleState();
}

class _ScribbleWithBackgroundExampleState
    extends State<ScribbleWithBackgroundExample> {
  late ScribbleNotifier notifier;
  ui.Image? backgroundImage; // 背景画像用の変数

  @override
  void initState() {
    super.initState();
    notifier = ScribbleNotifier();
    _loadBackgroundImage();
  }

  // 背景画像をdart:ui.Image形式で読み込む
  Future<void> _loadBackgroundImage() async {
    final data = await rootBundle.load('assets/images/background.png');
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() {
      backgroundImage = frame.image; // dart:ui.Imageを設定
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scribble with Background")),
      body: backgroundImage != null
          ? Scribble(
              notifier: notifier,
              backgroundImage: backgroundImage, // 背景画像を渡す
            )
          : const Center(child: CircularProgressIndicator()), // ローディング中
      floatingActionButton: FloatingActionButton(
        onPressed: notifier.clear, // クリア機能
        child: const Icon(Icons.clear),
      ),
    );
  }
}
