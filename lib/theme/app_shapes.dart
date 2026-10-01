import 'package:flutter/material.dart';

/// Continuous-curvature ("squircle") shapes — Flutter's native
/// [RoundedSuperellipseBorder], the same corner math Apple uses, not the
/// circular-arc [RoundedRectangleBorder] that has a visible kink where the
/// curve meets the flat edge.
///
/// One radius scale for the whole app instead of each widget picking its
/// own number.
class AppShapes {
  AppShapes._();

  static const double radiusXs = 8;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static OutlinedBorder card({double radius = radiusMd}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));

  static OutlinedBorder get button =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radiusSm));

  static OutlinedBorder get chip =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radiusXs));

  static OutlinedBorder get dialog =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radiusLg));

  /// [InputDecorationTheme.border] only accepts [InputBorder] subclasses
  /// (OutlineInputBorder/UnderlineInputBorder), which don't expose a
  /// continuous-curvature variant — this stays circular-arc, matching the
  /// radius scale but not the true squircle math used elsewhere.
  static OutlineInputBorder get input => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radiusSm),
    borderSide: BorderSide.none,
  );
}
