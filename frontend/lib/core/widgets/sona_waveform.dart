import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Волновая анимация дизайн-системы Sona (состояние «Слушаю»).
///
/// Реализована лёгким [CustomPainter] вместо Rive: ассет `.riv` не
/// поставляется дизайнером, а векторный столбчатый эквалайзер сохраняет
/// фирменный стиль и не тянет в сборку бинарный рантайм (~2 МБ), помогая
/// уложиться в бюджет размера приложения ≤ 60 МБ (см. issue #44).
///
/// Уважает системную настройку «уменьшить движение» ([MediaQuery]
/// `disableAnimations`): при включённой доступности волна статична.
class SonaWaveform extends StatefulWidget {
  const SonaWaveform({
    super.key,
    this.barCount = 9,
    this.height = 72,
    this.color,
    this.semanticLabel,
  });

  /// Число столбцов эквалайзера.
  final int barCount;

  /// Высота виджета.
  final double height;

  /// Цвет столбцов. По умолчанию — `colorScheme.primary`.
  final Color? color;

  /// Подпись для VoiceOver / TalkBack.
  final String? semanticLabel;

  @override
  State<SonaWaveform> createState() => _SonaWaveformState();
}

class _SonaWaveformState extends State<SonaWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox(
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
        ),
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
