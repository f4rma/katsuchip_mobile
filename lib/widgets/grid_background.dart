import 'package:flutter/material.dart';

class GridBackground extends StatelessWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Simple tiled background using CustomPaint
        const _GridPainterLayer(),
        child,
      ],
    );
  }
}

class _GridPainterLayer extends StatelessWidget {
  const _GridPainterLayer();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFFFF7ED);
    canvas.drawRect(Offset.zero & size, bg);

    // draw light grid
    const gap = 16.0;
    final line = Paint()
      ..color = const Color(0x26FF7A00)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
