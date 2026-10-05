import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import 'month_switcher.dart';

/// A collapsing top bar in the Material 3 "large" style: the month name is
/// big with its date range underneath while the content is at the top, and
/// shrinks into a one-line toolbar title as the content scrolls under it.
/// Tapping the title opens the month picker; a pair of chevrons beside it
/// steps one month back or forward, and a change of month slides the title
/// in the direction the month lies in time.
class MonthSliverAppBar extends StatelessWidget {
  const MonthSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.monthKey,
    this.switchDirection = MonthSwitchDirection.none,
    this.onTitleTap,
    this.onPreviousMonth,
    this.onNextMonth,
    this.leading,
    this.actions = const [],
    this.actionsWidth,
    this.showProgress = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;

  /// Identifies the month the title names, e.g. its id; when it changes the
  /// title animates in the [switchDirection] (see [MonthSwitcher]).
  final Object? monthKey;
  final MonthSwitchDirection switchDirection;
  final VoidCallback? onTitleTap;

  /// Step to the neighbouring month, for the chevrons beside the title. A
  /// null callback disables its chevron; with both null the chevrons hide.
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final Widget? leading;
  final List<Widget> actions;

  /// Width the collapsed title keeps clear for [actions]; 48 dp per action
  /// when not given (right for icon buttons only).
  final double? actionsWidth;

  /// Shows a thin progress line under the bar while the month reloads.
  final bool showProgress;

  /// A one-line toolbar instead of the large collapsing title, for windows
  /// of compact height (a phone in landscape); the date range then sits
  /// next to the month name.
  final bool compact;

  /// Height of the expanded bar, without the status bar.
  static const expandedHeight = 152.0;

  @override
  Widget build(BuildContext context) {
    final progress = showProgress
        ? const PreferredSize(
            preferredSize: Size.fromHeight(2),
            child: LinearProgressIndicator(minHeight: 2),
          )
        : null;
    if (compact) {
      return SliverAppBar(
        pinned: true,
        automaticallyImplyLeading: false,
        leading: leading,
        titleSpacing: leading == null ? 12 : 0,
        title: _InlineTitle(
          title: title,
          subtitle: subtitle,
          monthKey: monthKey,
          switchDirection: switchDirection,
          onTap: onTitleTap,
          onPrevious: onPreviousMonth,
          onNext: onNextMonth,
        ),
        actions: actions,
        bottom: progress,
      );
    }
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      automaticallyImplyLeading: false,
      leading: leading,
      actions: actions,
      flexibleSpace: _CollapsingTitle(
        title: title,
        subtitle: subtitle,
        monthKey: monthKey,
        switchDirection: switchDirection,
        onTap: onTitleTap,
        onPrevious: onPreviousMonth,
        onNext: onNextMonth,
        hasLeading: leading != null,
        trailingWidth: actionsWidth ?? 48.0 * actions.length,
      ),
      bottom: progress,
    );
  }
}

/// The compact bar's title: the month name with the date range beside it,
/// and the chevrons right after.
class _InlineTitle extends StatelessWidget {
  const _InlineTitle({
    required this.title,
    required this.subtitle,
    required this.monthKey,
    required this.switchDirection,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
  });

  final String title;
  final String? subtitle;
  final Object? monthKey;
  final MonthSwitchDirection switchDirection;
  final VoidCallback? onTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: MonthSwitcher(
                monthKey: monthKey,
                direction: switchDirection,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onPrevious != null || onNext != null)
          _MonthChevrons(onPrevious: onPrevious, onNext: onNext),
      ],
    );
  }
}

class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({
    required this.title,
    required this.subtitle,
    required this.monthKey,
    required this.switchDirection,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
    required this.hasLeading,
    required this.trailingWidth,
  });

  final String title;
  final String? subtitle;
  final Object? monthKey;
  final MonthSwitchDirection switchDirection;
  final VoidCallback? onTap;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool hasLeading;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;
    // 1 = fully expanded, 0 = collapsed to the toolbar.
    final range = settings.maxExtent - settings.minExtent;
    final t = range <= 0
        ? 0.0
        : ((settings.currentExtent - settings.minExtent) / range).clamp(
            0.0,
            1.0,
          );
    final theme = Theme.of(context);
    final nameStyle = TextStyle.lerp(
      theme.textTheme.titleLarge,
      theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      t,
    )!;
    final showChevrons = onPrevious != null || onNext != null;
    final left = lerpDouble(hasLeading ? 56.0 : 16.0, 16.0, t)!;
    // Expanded, the chevrons line up under the toolbar's icon buttons (4 dp
    // from the edge, as those are); without them the title keeps 16 dp.
    final right = lerpDouble(trailingWidth + 8, showChevrons ? 4.0 : 16.0, t)!;
    final bottom = lerpDouble(14.0, 20.0, t)!;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(left, 0, right, bottom),
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    // Only as tall as the title, so the row stays at the
                    // bottom of the header instead of filling it.
                    heightFactor: 1,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: MonthSwitcher(
                          monthKey: monthKey,
                          direction: switchDirection,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: nameStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null)
                                ClipRect(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    heightFactor: t,
                                    child: Opacity(
                                      opacity: t,
                                      child: Text(
                                        subtitle!,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The chevrons belong to the expanded header, at its far end
                // like a date picker's month navigation; they fade and fold
                // away as it collapses into the toolbar, where the actions
                // take the room.
                if (showChevrons)
                  ClipRect(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      widthFactor: t,
                      heightFactor: t,
                      child: Opacity(
                        opacity: t,
                        child: IgnorePointer(
                          ignoring: t < 0.5,
                          child: _MonthChevrons(
                            onPrevious: onPrevious,
                            onNext: onNext,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pair of chevrons that step one month back or forward, as a Material
/// date picker navigates its months. A null callback disables its chevron.
class _MonthChevrons extends StatelessWidget {
  const _MonthChevrons({required this.onPrevious, required this.onNext});

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          color: color,
          tooltip: l10n.prevMonth,
          onPressed: onPrevious,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          color: color,
          tooltip: l10n.nextMonth,
          onPressed: onNext,
        ),
      ],
    );
  }
}
