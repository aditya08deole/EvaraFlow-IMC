import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'app_shapes.dart';

class AppColors {
  // Light, calm off-white backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundSecondary = Color(0xFFF1F5F9);

  static const Color surface = Colors.white;
  static const Color surfaceSecondary = Color(0xFFF1F5F9);

  // Light-tint chip surfaces (flat, not blurred)
  static const Color glassSurface = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0xFFE2E8F0);
  static const Color glassBorderBlue = Color(0xFFBAE6FD);

  static const Color cardSurface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Text colors — an Apple-style label hierarchy: one ink, decreasing
  // weight. textPrimary/textSecondary/textMuted keep their existing values
  // (changing them risks a legibility regression this pass can't fully
  // audit); tertiaryLabel is the missing fourth tier, added for genuinely
  // decorative use only (placeholder text, disabled icons) — not for
  // anything that needs to stay as legible as textMuted.
  static const Color textPrimary = Color(0xFF0F172A); // label, 100%
  static const Color textSecondary = Color(0xFF475569); // secondaryLabel
  static const Color textMuted = Color(0xFF94A3B8); // tertiaryLabel (existing)
  static const Color tertiaryLabel = Color(0xFFCBD2DC); // quaternaryLabel, new

  // Brand: blue primary, teal accent
  static const Color primary = Color(0xFF0284C7);
  static const Color primaryHover = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFFF0F9FF);
  static const Color primaryBorder = Color(0xFFBAE6FD);

  static const Color liveTeal = Color(0xFF0D9488);
  static const Color liveTealLight = Color(0xFFF0FDF4);

  static const Color cyanAccent = Color(0xFF0284C7);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color driveBlue = Color(0xFF2563EB); // Google Drive brand blue

  // Restrained brand gradient, used sparingly on small icon chips only
  static const LinearGradient liquidSkyBlueGradient = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient ultraLiquidGlassGradient = LinearGradient(
    colors: [
      Colors.white.withValues(alpha: 0.42),
      Colors.white.withValues(alpha: 0.22),
      Colors.white.withValues(alpha: 0.15),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Real liquid glass surface: shader-backed refraction, chromatic dispersion,
/// and a specular highlight via `liquid_glass_widgets` (Impeller on iOS/Android/
/// macOS, automatic lightweight-shader fallback on Web/Windows/Linux).
///
/// [tint] is the one brand knob — everything else is a considered default
/// so call sites don't have to hand-tune shader parameters.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color tint;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.tint = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      // Shape.side is accepted by the shader shape but never painted by
      // either render path, so the visible rim comes from a real Flutter
      // border + a soft white glow drawn on top of the glass surface —
      // not from an inert shader parameter.
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: GlassContainer(
          useOwnLayer: true,
          padding: padding ?? const EdgeInsets.all(20),
          shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
          settings: LiquidGlassSettings(
            glassColor: tint.withValues(alpha: 0.10),
            blur: 14,
            thickness: 26,
            chromaticAberration: 0.02,
            lightIntensity: 0.8,
            refractiveIndex: 1.25,
            saturation: 1.35,
            glowIntensity: 1.0,
            specularSharpness: GlassSpecularSharpness.sharp,
            shadowElevation: 1.2,
            // Standard (Web/Windows) path only — controls how opaque the
            // compositing looks there, separate from glassColor's alpha.
            // Package docs suggest ~0.4 as the light-mode "magic number";
            // left at the 1.0 default this path looked far more solid than
            // the Premium shader ever would.
            standardOpacityMultiplier: 0.45,
          ),
          child: child,
        ),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.liveTeal,
        surface: AppColors.cardSurface,
        error: AppColors.dangerRed,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMd),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: AppShapes.button),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: AppShapes.button),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: AppShapes.button),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: AppShapes.input,
        enabledBorder: AppShapes.input.copyWith(
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: AppShapes.input.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceSecondary,
      ),
    );
  }
}
