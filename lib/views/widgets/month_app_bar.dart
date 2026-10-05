import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A collapsing top bar in the Material 3 "large" style: the month name is
/// big with its date range underneath while the content is at the top, and
/// shrinks into a one-line toolbar title as the content scrolls under it.
/// Tapping the title opens the month picker.
class MonthSliverAppBar extends StatelessWidget {
  const MonthSliverAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onTitleTap,
    this.leading,
    this.actions = const [],
    this.showProgress = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTitleTap;
  final Widget? leading;
  final List<Widget> actions;

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
        ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
        : null;
    if (compact) {
      return SliverAppBar(
        pinned: true,
        automaticallyImplyLeading: false,
        leading: leading,
        titleSpacing: leading == null ? 12 : 0,
        title: _InlineTitle(title: title, subtitle: subtitle, onTap: onTitleTap),
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
        onTap: onTitleTap,
        hasLeading: leading != null,
        trailingWidth: 48.0 * actions.length,
      ),
      bottom: progress,
    );
  }
}

/// The compact bar's title: the month name with the date range beside it.
class _InlineTitle extends StatelessWidget {
  const _InlineTitle({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: Text(title, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (subtitle != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsingTitle extends StatelessWidget {
  const _CollapsingTitle({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.hasLeading,
    required this.trailingWidth,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool hasLeading;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>()!;
    // 1 = fully expanded, 0 = collapsed to the toolbar.
    final range = settings.maxExtent - settings.minExtent;
    final t = range <= 0 ? 0.0 : ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final nameStyle = TextStyle.lerp(
      theme.textTheme.titleLarge,
      theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      t,
    )!;
    final left = lerpDouble(hasLeading ? 56.0 : 16.0, 16.0, t)!;
    final right = lerpDouble(trailingWidth + 8, 16.0, t)!;
    final bottom = lerpDouble(14.0, 20.0, t)!;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(left, 0, right, bottom),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null)
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          heightFactor: t,
                          child: Opacity(
                            opacity: t,
                            child: Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    );
  }
}
