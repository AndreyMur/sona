import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Волновая анимация состояния «Слушаю».
///
/// Лёгкая замена Rive-анимации на время tracer bullet: набор столбцов,
/// высота которых меняется по синусоиде.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key, this.barCount = 9, this.height = 72});

  final int barCount;
  final double height;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WaveformPainter(
              progress: _controller.value,
              barCount: widget.barCount,
              color: color,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.barCount,
    required this.color,
  });

  final double progress;
  final int barCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width / (barCount * 2.2);

    final centerY = size.height / 2;
    final maxBarHeight = size.height;
    final step = size.width / barCount;

    for (var i = 0; i < barCount; i++) {
      final phase = (i / barCount) * math.pi * 2;
      final wave = math.sin(progress * math.pi * 2 + phase);
      final factor = 0.25 + (wave + 1) / 2 * 0.75;
      final barHeight = maxBarHeight * factor;
      final x = step * i + step / 2;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.barCount != barCount ||
      oldDelegate.color != color;
}
