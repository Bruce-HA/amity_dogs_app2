import 'dart:math';
import 'package:flutter/material.dart';

class RotatableImage extends StatelessWidget {
  final String imageUrl;
  final int rotation;
  final BoxFit fit;
  final Alignment alignment;
  final String? heroTag;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const RotatableImage({
    super.key,
    required this.imageUrl,
    this.rotation = 0,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.heroTag,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Transform.rotate(
      angle: rotation * pi / 180,
      child: Image.network(
        imageUrl,
        fit: fit,
        alignment: alignment,
        key: ValueKey('$imageUrl-$rotation'),
        errorBuilder: errorBuilder,
      ),
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: image,
      );
    }

    return image;
  }
}