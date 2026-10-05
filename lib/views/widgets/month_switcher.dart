import 'package:flutter/material.dart';

/// Which way the month on screen moved: later in time, earlier, or a jump
/// with no direction (the first load, or the default month after a delete).
enum MonthSwitchDirection { none, backward, forward }

/// Animates a change of month the Material "shared axis" way: the old
/// content fades out while sliding a little in the direction of travel, the
/// new one fades in from the opposite side. Later in time comes in from the
/// end side (the right, in a left-to-right locale), earlier from the start
/// side; with [MonthSwitchDirection.none] both just cross-fade.
///
/// The animation runs when [monthKey] changes; a rebuild with the same key
/// updates the child in place, so a refresh of the same month does not move
/// anything.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.monthKey,
    required this.direction,
    required this.child,
  });

  /// Identifies the month the [child] shows, e.g. its id.
  final Object? monthKey;
  final MonthSwitchDirection direction;
  final Widget child;

  /// How far the content travels, in logical pixels (the Material shared
  /// axis figure).
  static const distance = 30.0;
  static const duration = Durations.medium2;

  @override
  Widget build(BuildContext context) {
    final currentKey = ValueKey(monthKey);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedSwitcher(
      duration: duration,
      // Both children keep the constraints the switcher got and line up at
      // the start, so the new title stands where the old one stood. Nothing
      // is clipped here: the content may poke out a little while it slides.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.passthrough,
        alignment: AlignmentDirectional.topStart,
        clipBehavior: Clip.none,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == currentKey;
        var sign = switch (direction) {
          MonthSwitchDirection.forward => 1.0,
          MonthSwitchDirection.backward => -1.0,
          MonthSwitchDirection.none => 0.0,
        };
        // The outgoing child's animation runs backwards (1 to 0), so the
        // same tween read in reverse carries it out the other way.
        if (!incoming) sign = -sign;
        if (rtl) sign = -sign;
        // The old content is gone within the first third and the new one
        // shows up over the last two thirds, so they barely overlap.
        final fade = CurvedAnimation(
          parent: animation,
          curve: incoming ? const Interval(0.3, 1.0) : const Interval(0.7, 1.0),
        );
        final slide = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );
        return FadeTransition(
          opacity: fade,
          child: AnimatedBuilder(
            animation: slide,
            builder: (context, child) => Transform.translate(
              offset: Offset(sign * distance * (1 - slide.value), 0),
              child: child,
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: currentKey, child: child),
    );
  }
}
