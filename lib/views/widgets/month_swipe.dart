import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'month_switcher.dart';

/// A horizontal swipe that moves one month, as on a calendar. While the
/// finger is down the month on screen follows it a little, like a rubber
/// band, and a chevron comes out at the edge the neighbouring month lies
/// behind: the left edge for an earlier month (a swipe to the right), the
/// right edge for a later one. Once the finger has travelled
/// [commitDistance] the chevron fills in, with a click; letting go then, or
/// a flick of at least [flingVelocity], calls [onMove]. Afterwards the
/// content eases back into place; the change of month itself is animated
/// by [MonthSwitcher]. With no month in the swipe's direction nothing moves.
///
/// The displacement also goes to [shift], for anything else that should be
/// pulled along with the month, such as the title in the top bar.
class MonthSwipeDetector extends StatefulWidget {
  const MonthSwipeDetector({
    super.key,
    required this.canGoBackward,
    required this.canGoForward,
    required this.onMove,
    required this.shift,
    required this.child,
  });

  /// Whether there is an earlier month (reached with a swipe to the right).
  final bool canGoBackward;

  /// Whether there is a later month (reached with a swipe to the left).
  final bool canGoForward;
  final ValueChanged<MonthSwitchDirection> onMove;

  /// Receives the content's displacement, positive to the right.
  final ValueNotifier<double> shift;
  final Widget child;

  /// The most the content moves, in logical pixels.
  static const peekDistance = 40.0;

  /// How far the finger travels before a release moves the month.
  static const commitDistance = 96.0;

  /// A flick at least this fast (logical pixels per second) moves the month
  /// whatever the distance.
  static const flingVelocity = 250.0;

  @override
  State<MonthSwipeDetector> createState() => _MonthSwipeDetectorState();
}

class _MonthSwipeDetectorState extends State<MonthSwipeDetector>
    with SingleTickerProviderStateMixin {
  /// The finger's travel since the drag began, positive to the right.
  double _drag = 0;

  /// Past the threshold: a release now moves the month.
  bool _armed = false;

  /// Eases [_drag] back to zero after a release.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: Durations.medium1,
  )..addListener(_onSettleTick);
  double _settleFrom = 0;

  MonthSwitchDirection get _direction => _drag > 0
      ? MonthSwitchDirection.backward
      : _drag < 0
          ? MonthSwitchDirection.forward
          : MonthSwitchDirection.none;

  bool _canGo(MonthSwitchDirection direction) => switch (direction) {
        MonthSwitchDirection.backward => widget.canGoBackward,
        MonthSwitchDirection.forward => widget.canGoForward,
        MonthSwitchDirection.none => false,
      };

  /// The travel that counts: none when there is no month that way.
  double get _effectiveDrag => _canGo(_direction) ? _drag : 0;

  /// The content's displacement: 40% of the finger's travel at first, then
  /// less and less, never beyond [MonthSwipeDetector.peekDistance].
  double get _shift {
    final drag = _effectiveDrag;
    if (drag == 0) return 0;
    const peek = MonthSwipeDetector.peekDistance;
    return drag.sign * peek * (1 - math.exp(-0.4 * drag.abs() / peek));
  }

  /// How far along the way to the threshold the finger is, 0 to 1.
  double get _progress =>
      (_effectiveDrag.abs() / MonthSwipeDetector.commitDistance).clamp(
        0.0,
        1.0,
      );

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _set(double drag) {
    setState(() => _drag = drag);
    widget.shift.value = _shift;
  }

  void _onDragStart(DragStartDetails details) {
    // A grab while the content is still easing back carries on from there.
    _settle.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _set(_drag + (details.primaryDelta ?? 0));
    final armed = _progress >= 1;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final flung = velocity.abs() >= MonthSwipeDetector.flingVelocity;
    final direction = flung
        ? (velocity > 0
            ? MonthSwitchDirection.backward
            : MonthSwitchDirection.forward)
        : _direction;
    if ((_armed || flung) && _canGo(direction)) {
      if (!_armed) HapticFeedback.selectionClick();
      widget.onMove(direction);
    }
    _settleBack();
  }

  void _settleBack() {
    _settleFrom = _drag;
    _settle.forward(from: 0);
  }

  void _onSettleTick() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    _set(_settleFrom * (1 - t));
    if (_settle.isCompleted) _armed = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _settleBack,
      child: Stack(
        children: [
          Transform.translate(offset: Offset(_shift, 0), child: widget.child),
          if (progress > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: _EdgeChevron(
                  progress: progress,
                  armed: _armed,
                  atStart: _direction == MonthSwitchDirection.backward,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chevron that comes out of the edge as the finger travels: a small
/// tonal disc that slides in and fills in with the primary colour once a
/// release will move the month.
class _EdgeChevron extends StatelessWidget {
  const _EdgeChevron({
    required this.progress,
    required this.armed,
    required this.atStart,
  });

  final double progress;
  final bool armed;

  /// At the left edge, pointing left (an earlier month); otherwise at the
  /// right edge, pointing right.
  final bool atStart;

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // From just beyond the edge to a small margin inside it.
    final inset = lerpDouble(-_size, 12.0, Curves.easeOut.transform(progress))!;
    return Align(
      alignment: atStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(atStart ? inset : -inset, 0),
          child: AnimatedContainer(
            duration: Durations.short3,
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  armed ? scheme.primaryContainer : scheme.surfaceContainerHigh,
            ),
            child: Icon(
              atStart
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color:
                  armed ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
