import 'package:flutter/material.dart';

/// Controlled responsive scaling utility.
/// Clamped between 0.90x and 1.15x referencing 390px mobile screen width.
abstract final class AppScale {
  static const double referenceWidth = 390.0;
  static const double minFactor = 0.90;
  static const double maxFactor = 1.15;

  static double factor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / referenceWidth).clamp(minFactor, maxFactor);
  }

  static double font(BuildContext context, double size) {
    return size * factor(context);
  }

  static double spacing(BuildContext context, double size) {
    return size * factor(context);
  }

  static double icon(BuildContext context, double size) {
    return size * factor(context);
  }
}
