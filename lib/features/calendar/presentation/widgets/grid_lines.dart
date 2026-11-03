import 'package:flutter/widgets.dart';

/// Snaps [value] to the centre of a physical pixel, so that a line of one
/// physical pixel is drawn crisp instead of blended over two pixels (or
/// dropped) at fractional positions.
double snapToPixel(double value, double pixelRatio) =>
    ((value * pixelRatio).floorToDouble() + 0.5) / pixelRatio;

/// Inner lines of a [columns] × [rows] grid, painted in one pass above the
/// cells so that no cell background can hide them.
class GridLinesPainter extends CustomPainter {
  GridLinesPainter({
    required this.columns,
    required this.rows,
    required this.color,
    required this.pixelRatio,
  });

  final int columns;
  final int rows;
  final Color color;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1 / pixelRatio;
    for (var c = 1; c < columns; c++) {
      final x = snapToPixel(size.width * c / columns, pixelRatio);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var r = 1; r < rows; r++) {
      final y = snapToPixel(size.height * r / rows, pixelRatio);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridLinesPainter old) =>
      old.columns != columns ||
      old.rows != rows ||
      old.color != color ||
      old.pixelRatio != pixelRatio;
}
