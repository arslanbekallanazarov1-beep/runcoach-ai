import 'package:flutter/material.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(12),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}
