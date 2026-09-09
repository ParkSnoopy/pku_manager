import 'package:flutter/material.dart';

class FlashingOutline extends StatefulWidget {
  const FlashingOutline({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final bool active;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<FlashingOutline> createState() => _FlashingOutlineState();
}

class _FlashingOutlineState extends State<FlashingOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FlashingOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: widget.active
            ? Border.all(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .25 + _controller.value * .75),
                width: 3,
              )
            : null,
      ),
      child: child,
    ),
  );
}
