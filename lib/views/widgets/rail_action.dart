import 'package:flutter/material.dart';

/// A secondary action at the bottom of the navigation rail (month picker,
/// Settings): an icon button, with its label underneath when the rail has
/// room for labels. The tooltip stays in both forms, as on the bottom bar's
/// destinations.
class RailAction extends StatelessWidget {
  const RailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.showLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool showLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!showLabel) return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              // Capped so a long label ellipsizes instead of widening the rail.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
