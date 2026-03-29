import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool selectable;

  const AppText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    if (selectable) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
      );
    }

    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}