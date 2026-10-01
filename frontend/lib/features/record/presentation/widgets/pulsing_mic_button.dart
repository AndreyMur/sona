import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Большая круглая кнопка микрофона с мягкой пульсацией.
class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    super.key,
    required this.onPressed,
    this.label = 'Сказать',
    this.size = 148,
  });

  final VoidCallback onPressed;
  final String label;
  final double size;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final scale = 1 + _controller.value * 0.08;
                return SizedBox(
                  width: widget.size + 40,
                  height: widget.size + 40,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: scale,
                          child: Container(
                            width: widget.size + 32,
                            height: widget.size + 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary.withValues(
                                alpha: 0.08 + _controller.value * 0.06,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 1 + _controller.value * 0.03,
                          child: child,
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: scheme.primary.withValues(alpha: 0.4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Icon(
                      Icons.mic_rounded,
                      size: widget.size * 0.42,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
