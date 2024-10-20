// lib/utils/svg_to_sketch_converter.dart

import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'package:xml/xml.dart' as xml;

class SvgToSketchConverter {
  static Sketch convertSvgToSketch(String svgString) {
    final document = xml.XmlDocument.parse(svgString);
    final polylines = document.findAllElements('polyline');

    final sketchLines = <SketchLine>[];

    for (final polyline in polylines) {
      final pointsAttribute = polyline.getAttribute('points');
      if (pointsAttribute == null || pointsAttribute.isEmpty) {
        continue; // ポイントがない場合はスキップ
      }

      final points = _parsePoints(pointsAttribute);

      // ポリラインのスタイルを抽出
      final strokeColorString = polyline.getAttribute('stroke') ?? '#000000';
      final strokeWidthString = polyline.getAttribute('stroke-width') ?? '1.0';
      final strokeLineCap = polyline.getAttribute('stroke-linecap') ?? 'butt';
      final strokeLineJoin =
          polyline.getAttribute('stroke-linejoin') ?? 'miter';

      final color = _parseColor(strokeColorString);
      final strokeWidth = double.tryParse(strokeWidthString) ?? 1.0;

      // SketchLine を作成
      final sketchLine = SketchLine(
        color: color.value,
        width: strokeWidth,
        // strokeWidth: strokeWidth,
        points: points,
        // isEraser: false,
      );

      sketchLines.add(sketchLine);
    }

    return Sketch(lines: sketchLines);
  }

  static List<Point> _parsePoints(String pointsString) {
    final points = <Point>[];
    final pointPairs = pointsString.trim().split(RegExp(r'\s+'));
    for (final pair in pointPairs) {
      final coords = pair.split(',');
      if (coords.length == 2) {
        final x = double.tryParse(coords[0]) ?? 0.0;
        final y = double.tryParse(coords[1]) ?? 0.0;
        points.add(Point(x, y));
      }
    }
    return points;
  }

  static Color _parseColor(String colorString) {
    if (colorString.toLowerCase() == 'none') {
      return Colors.transparent;
    }
    try {
      var hexColor = colorString.toUpperCase().replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.black;
    }
  }
}
