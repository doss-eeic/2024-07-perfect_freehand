import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scribble/scribble.dart';
import 'package:value_notifier_tools/value_notifier_tools.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scribble with WebView SVG Background',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: const HomePage(title: 'Scribble with WebView'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScribbleNotifier notifier;
  late final WebViewController _webViewController; // WebViewControllerの追加
  String? svgData; // SVGデータを保存

  @override
  void initState() {
    super.initState();
    notifier = ScribbleNotifier();

    // WebViewControllerを初期化
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (url) {
            debugPrint('Page finished loading: $url');
          },
        ),
      );
  }

  // SVGデータを読み込む
  Future<void> _loadSvg() async {
    try {
      // assetsからSVGを文字列として読み込む
      svgData = await rootBundle.loadString('assets/images/segment.svg');
    } catch (e) {
      debugPrint("Failed to load SVG: $e");
    }
  }

  // ボタンを押したときにWebViewにSVGを読み込む関数
  void _loadSvgIntoWebView() {
    if (svgData != null) {
      final content = '''
      <html>
        <body style="margin: 0; padding: 0;">
          $svgData
        </body>
      </html>
    ''';

      _webViewController.loadRequest(Uri.dataFromString(
        content,
        mimeType: 'text/html',
        encoding: Encoding.getByName('utf-8'),
      ));
    } else {
      debugPrint("SVG data is null.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: _buildActions(context),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64),
        child: Column(
          children: [
            Expanded(
              child: Scribble(
                notifier: notifier,
                drawPen: true,
                webViewController: _webViewController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildColorToolbar(context),
                  const VerticalDivider(width: 32),
                  _buildStrokeToolbar(context),
                  const Expanded(child: SizedBox()),
                  _buildPointerModeSwitcher(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 他の機能に対応するボタンなど
  List<Widget> _buildActions(BuildContext context) {
    return [
      ValueListenableBuilder(
        valueListenable: notifier,
        builder: (context, value, child) => IconButton(
          icon: child as Icon,
          tooltip: "Undo",
          onPressed: notifier.canUndo ? notifier.undo : null,
        ),
        child: const Icon(Icons.undo),
      ),
      ValueListenableBuilder(
        valueListenable: notifier,
        builder: (context, value, child) => IconButton(
          icon: child as Icon,
          tooltip: "Redo",
          onPressed: notifier.canRedo ? notifier.redo : null,
        ),
        child: const Icon(Icons.redo),
      ),
      IconButton(
        icon: const Icon(Icons.clear),
        tooltip: "Clear",
        onPressed: notifier.clear,
      ),
      IconButton(
        icon: const Icon(Icons.image),
        tooltip: "Show PNG Image",
        onPressed: () => _showImage(context),
      ),
      IconButton(
        icon: const Icon(Icons.data_object),
        tooltip: "Show JSON",
        onPressed: () => _showJson(context),
      ),
      IconButton(
        icon: const Icon(Icons.image),
        tooltip: "Show SVG",
        onPressed: () => _showSvg(context),
      ),
      IconButton(
        tooltip: "Import SVG",
        onPressed: () => _importSvg(context),
        icon: const Icon(Icons.upload),
      ),
      IconButton(
        onPressed: () async {
          await _loadSvg(); // SVGデータをロード
          _loadSvgIntoWebView(); // WebViewにSVGを読み込む
        },
        icon: const Icon(Icons.upload),
      ),
    ];
  }

  void _importSvg(BuildContext context) async {
    try {
      // Load the SVG file from assets
      final svgData = await rootBundle.loadString('assets/images/sample.svg');

      // Use the loadFromSvg method in the notifier to display the SVG
      notifier.loadFromSvg(svgData);

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SVG imported successfully")),
      );
    } catch (e) {
      // If an error occurs, display it in a SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load SVG: $e")),
      );
    }
  }

  void _showImage(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 描画領域のサイズを確認する
      if (notifier.repaintBoundaryKey.currentContext != null) {
        final boundary = notifier.repaintBoundaryKey.currentContext!
            .findRenderObject() as RenderRepaintBoundary;

        // 実際のサイズをデバッグ出力
        final width = boundary.size.width;
        final height = boundary.size.height;
        print('RenderRepaintBoundary size: width = $width, height = $height');

        // サイズが有効か確認する
        if (width > 0 && height > 0) {
          try {
            // サイズが有効な場合にのみ画像を生成
            final image = await boundary.toImage();
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final pngBytes = byteData?.buffer.asUint8List();

            // ダイアログで画像を表示
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Generated Image"),
                content: pngBytes != null
                    ? Image.memory(pngBytes)
                    : const Text("Failed to generate image."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close"),
                  ),
                ],
              ),
            );
          } catch (e) {
            debugPrint("Error generating image: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error generating image: $e")),
            );
          }
        } else {
          // サイズが無効な場合のエラーハンドリング
          debugPrint("Invalid size: width and height must be greater than 0.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid size for image capture.")),
          );
        }
      } else {
        // RepaintBoundary が存在しない場合のエラーハンドリング
        debugPrint("RepaintBoundary is not ready.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("RepaintBoundary is not ready.")),
        );
      }
    });
  }

  void _showJson(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sketch as JSON"),
        content: SizedBox.expand(
          child: SelectableText(
            jsonEncode(notifier.currentSketch.toJson()),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  void _showSvg(BuildContext context) {
    final svgData = notifier.toSvg();
    debugPrint(svgData);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sketch as SVG"),
        content: SizedBox.expand(
          child: SingleChildScrollView(
            child: SelectableText(
              svgData,
              style: const TextStyle(fontFamily: 'Courier'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: svgData));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("SVG data copied to clipboard")),
              );
            },
            child: const Text("Copy"),
          ),
        ],
      ),
    );
  }

  Widget _buildStrokeToolbar(BuildContext context) {
    return ValueListenableBuilder<ScribbleState>(
      valueListenable: notifier,
      builder: (context, state, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (final w in notifier.widths)
            _buildStrokeButton(
              context,
              strokeWidth: w,
              state: state,
            ),
        ],
      ),
    );
  }

  Widget _buildStrokeButton(
    BuildContext context, {
    required double strokeWidth,
    required ScribbleState state,
  }) {
    final selected = state.selectedWidth == strokeWidth;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        elevation: selected ? 4 : 0,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => notifier.setStrokeWidth(strokeWidth),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: kThemeAnimationDuration,
            width: strokeWidth * 2,
            height: strokeWidth * 2,
            decoration: BoxDecoration(
                color: state.map(
                  drawing: (s) => Color(s.selectedColor),
                  erasing: (_) => Colors.transparent,
                ),
                border: state.map(
                  drawing: (_) => null,
                  erasing: (_) => Border.all(width: 1),
                ),
                borderRadius: BorderRadius.circular(50.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildColorToolbar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildColorButton(context, color: Colors.black),
        _buildColorButton(context, color: Colors.red),
        _buildColorButton(context, color: Colors.green),
        _buildColorButton(context, color: Colors.blue),
        _buildColorButton(context, color: Colors.yellow),
        _buildEraserButton(context),
      ],
    );
  }

  Widget _buildPointerModeSwitcher(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier.select(
        (value) => value.allowedPointersMode,
      ),
      builder: (context, value, child) {
        return SegmentedButton<ScribblePointerMode>(
          multiSelectionEnabled: false,
          emptySelectionAllowed: false,
          onSelectionChanged: (v) => notifier.setAllowedPointersMode(v.first),
          segments: const [
            ButtonSegment(
              value: ScribblePointerMode.all,
              icon: Icon(Icons.touch_app),
              label: Text("All pointers"),
            ),
            ButtonSegment(
              value: ScribblePointerMode.penOnly,
              icon: Icon(Icons.draw),
              label: Text("Pen only"),
            ),
          ],
          selected: {value},
        );
      },
    );
  }

  Widget _buildEraserButton(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier.select((value) => value is Erasing),
      builder: (context, value, child) => ColorButton(
        color: Colors.transparent,
        outlineColor: Colors.black,
        isActive: value,
        onPressed: () => notifier.setEraser(),
        child: const Icon(Icons.cleaning_services),
      ),
    );
  }

  Widget _buildColorButton(
    BuildContext context, {
    required Color color,
  }) {
    return ValueListenableBuilder(
      valueListenable: notifier.select(
        (value) => value is Drawing && value.selectedColor == color.value,
      ),
      builder: (context, value, child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ColorButton(
          color: color,
          isActive: value,
          onPressed: () => notifier.setColor(color),
        ),
      ),
    );
  }
}

class ColorButton extends StatelessWidget {
  const ColorButton({
    required this.color,
    required this.isActive,
    required this.onPressed,
    this.outlineColor,
    this.child,
    super.key,
  });

  final Color color;
  final Color? outlineColor;
  final bool isActive;
  final VoidCallback onPressed;
  final Icon? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kThemeAnimationDuration,
      decoration: ShapeDecoration(
        shape: CircleBorder(
          side: BorderSide(
            color: isActive ? outlineColor ?? color : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: IconButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: const CircleBorder(),
          side: isActive
              ? const BorderSide(color: Colors.white, width: 2)
              : const BorderSide(color: Colors.transparent),
        ),
        onPressed: onPressed,
        icon: child ?? const SizedBox(),
      ),
    );
  }
}
