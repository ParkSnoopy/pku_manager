import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class FollowingHoverCard extends StatefulWidget {
  const FollowingHoverCard({
    super.key,
    required this.cardKey,
    required this.card,
    required this.child,
    this.cursor = MouseCursor.defer,
    this.waitDuration = const Duration(milliseconds: 100),
  });

  final Key cardKey;
  final Widget card;
  final Widget child;
  final MouseCursor cursor;
  final Duration waitDuration;

  @override
  State<FollowingHoverCard> createState() => _FollowingHoverCardState();
}

class _FollowingHoverCardState extends State<FollowingHoverCard> {
  Timer? _timer;
  OverlayEntry? _entry;
  Offset _pointer = Offset.zero;

  void _move(PointerEvent event) {
    _pointer = event.position;
    _entry?.markNeedsBuild();
  }

  void _enter(PointerEnterEvent event) {
    _move(event);
    _timer = Timer(widget.waitDuration, _show);
  }

  void _hide() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    if (!mounted || _entry != null) return;
    _entry = OverlayEntry(
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = math.min(320.0, size.width - 16);
        final maxHeight = math.min(420.0, size.height - 16);
        final right = _pointer.dx + 14;
        final left = right + width <= size.width - 8
            ? right
            : (_pointer.dx - width - 14).clamp(8.0, size.width - width - 8);
        final top = (_pointer.dy + 14)
            .clamp(8.0, math.max(8.0, size.height - maxHeight - 8))
            .toDouble();
        return Positioned(
          key: widget.cardKey,
          left: left,
          top: top,
          width: width,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.card,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: _enter,
    onHover: _move,
    onExit: (_) => _hide(),
    child: Listener(onPointerDown: (_) => _hide(), child: widget.child),
  );
}
