import 'package:flutter/material.dart';

import '../../tools/formatters.dart';

class InfoCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final double? amount;
  final List<Widget> children;
  final bool isOutlined;
  final bool isCurrency;
  final bool isInteger;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;

  const InfoCard({super.key,
    this.icon,
    required this.title,
    this.amount,
    this.children = const [],
    this.isOutlined = false,
    this.isCurrency = true,
    this.isInteger = false,
    this.color,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: isOutlined
          ? RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  if (icon != null)
                    Icon(icon, color: textColor ?? colorScheme.primary),
                  if (icon != null)
                    const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: textTheme.titleMedium?.copyWith(
                        color: textColor ?? colorScheme.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (amount != null && isCurrency)
                    Text(
                      Formatters.currencyFormatter.format(amount),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor ?? colorScheme.onSurface,
                      ),
                    ),
                  if (amount != null && isInteger)
                    Text(
                      amount!.toInt().toString(),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor ?? colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 8),
              Divider(
                  indent: 16,
                  endIndent: 16,
                  color: color != null ? colorScheme.surface : null
              ),
              ...children,
            ],
          ],
        ),
        ),
      ),
    );
  }
}