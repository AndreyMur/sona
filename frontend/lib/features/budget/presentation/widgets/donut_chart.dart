import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Срез пончик-диаграммы: подпись, величина и цвет сегмента.
class DonutSlice {
  const DonutSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Палитра сегментов диаграммы на токенах дизайн-системы.
const List<Color> kDonutPalette = [
  AppColors.primary,
  AppColors.primaryDark,
  AppColors.warning,
  AppColors.income,
  Color(0xFF7CB89A),
];

/// Пончик-диаграмма распределения трат по категориям.
///
/// Центр остаётся свободным — туда обычно ставят общую сумму.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 168,
    this.strokeWidth = 26,
    this.center,
  });

  final List<DonutSlice> slices;
  final double size;
  final double strokeWidth;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutPainter(
                slices: slices,
                strokeWidth: strokeWidth,
                trackColor:
                    Theme.of(context).colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
              ),
            ),
          ),
          if (center != null)
            Padding(
              padding: EdgeInsets.all(strokeWidth),
              child: center,
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<DonutSlice> slices;
  final double strokeWidth;
  final Color trackColor;

  static const double _gap = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final centerPoint = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centerPoint, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (slices.isEmpty) {
      paint.color = trackColor;
      canvas.drawArc(rect, 0, pi * 2, false, paint);
      return;
    }

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) {
      paint.color = trackColor;
      canvas.drawArc(rect, 0, pi * 2, false, paint);
      return;
    }

    final gaps = slices.length > 1 ? _gap * slices.length : 0.0;
    final usable = max(pi * 2 - gaps, 0.0);
    var start = -pi / 2;
    for (final slice in slices) {
      final sweep = slice.value / total * usable;
      paint.color = slice.color;
      canvas.drawArc(rect, start, max(sweep - _gap / 2, 0.001), false, paint);
      start += sweep + _gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      slices != oldDelegate.slices || strokeWidth != oldDelegate.strokeWidth;
}

/// Круглая метка легенды диаграммы.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
