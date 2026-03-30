import 'package:flutter/material.dart';
import 'spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool outlined;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);

    Widget content = Container(
      padding: padding ?? AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: outlined
            ? Border.all(color: Colors.grey.shade300)
            : null,
        boxShadow: outlined
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}