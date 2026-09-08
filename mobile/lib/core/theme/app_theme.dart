import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark theme matching the Claude Design prototype (`docs/design-brief.md`,
/// section 1). Colors, radii, shadows and type scale are all lifted directly
/// from the design tokens table — this is not a generic Material dark theme.
///
/// Icons: the design uses Material Symbols Outlined (variable weight,
/// opsz 24 / weight ~200-300 / fill 0), which is a visually different family
/// from classic Material Icons (filled/rounded strokes vs. thin outlined
/// strokes). We use the `material_symbols_icons` package so screens can
/// reference `Symbols.search` etc. and get a close visual match to the
/// design; plain `Icons.*` remains available for anything not covered.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------
  // Color tokens (docs/design-brief.md, section 1)
  // ---------------------------------------------------------------------

  /// Fondo base del frame.
  static const Color background = Color(0xFF14151F);

  /// Fondo detrás del frame (glow radial). Not used as scaffold background
  /// (that's [background]) but exposed for screens that need the outer glow.
  static const Color backgroundOuter = Color(0xFF0E0F16);

  /// Superficie de cards.
  static const Color surface = Color(0xFF1F2130);

  /// Superficie secundaria.
  static const Color surfaceSecondary = Color(0xFF2A2C3D);

  /// Borde sutil.
  static const Color border = Color(0x17FFFFFF); // rgba(255,255,255,0.09)

  /// Texto principal.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Texto secundario.
  static const Color textSecondary = Color(0x9EFFFFFF); // rgba(255,255,255,0.62)

  /// Texto terciario / placeholders / eyebrows.
  static const Color textTertiary = Color(0x61FFFFFF); // rgba(255,255,255,0.38)

  /// Fondo de la bottom nav (usado con blur). No consumido todavía por
  /// ningún widget, pero se deja disponible para cuando se arme la bottom
  /// nav definitiva.
  static const Color navBackground = Color(0xEB1F2130); // rgba(31,33,48,0.92)

  /// Sombra estándar de card.
  static const Color shadow = Color(0x73000000); // rgba(0,0,0,0.45)

  /// Acento marca (naranja/rojo Fudo).
  static const Color accent = Color(0xFFFF5023);

  /// Hover del acento.
  static const Color accentHover = Color(0xFFD03F00);

  /// Gradiente CTA de los botones principales (buscar, delivery, filtros,
  /// gift). Un `ButtonStyle`/`ButtonThemeData` de Material no puede pintar un
  /// gradiente como background, así que este gradiente se expone acá para
  /// que las pantallas armen sus propios botones CTA como widgets custom
  /// (p.ej. un `Ink` o `DecoratedBox` con este gradiente + `InkWell`) en vez
  /// de intentar forzarlo vía `ElevatedButtonThemeData`.
  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFFFF6337), Color(0xFFE8431A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Verde reward/tag (dieta, premio disponible, DNI verificado).
  static const Color rewardGreen = Color(0xFF8FD46A);

  /// Fondo del tag verde.
  static const Color rewardGreenBackground = Color(0x248FD46A); // rgba(143,212,106,0.14)

  /// Fondo del chip de precio.
  static const Color priceChipBackground = Color(0x29FF5023); // rgba(255,80,35,0.16)

  /// Texto del chip de precio.
  static const Color priceChipText = Color(0xFFFF7A55);

  // ---------------------------------------------------------------------
  // Radii (docs/design-brief.md, section 1)
  // ---------------------------------------------------------------------

  static const double radiusCard = 16;
  static const double radiusCardLarge = 18;
  static const double radiusHero = 20;
  static const double radiusHeroLarge = 26;
  static const double radiusPhotoSmall = 12;
  static const double radiusPhotoSmallLarge = 13;
  static const double radiusPill = 999;
  static const double radiusBottomSheetTop = 26;

  // ---------------------------------------------------------------------
  // Typography
  //
  // Barlow (600/700/800/900, italic 900) for headlines, amounts and
  // merchant names. Inter (300-700) for body/inputs/buttons. Screens should
  // pull styles from `AppTheme.textTheme` (via `Theme.of(context).textTheme`)
  // rather than calling `GoogleFonts.*` directly, so the Barlow/Inter split
  // stays centralized here.
  // ---------------------------------------------------------------------

  static TextTheme get _baseTextTheme => GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      );

  static TextTheme? _cachedTextTheme;

  /// Full `TextTheme` for `ThemeData.textTheme`: Inter everywhere by
  /// default, with the large/display/headline/title roles overridden to
  /// Barlow (bold weights) to match the design's headline/amount/merchant
  /// name usage. Cached after the first build — `GoogleFonts.barlow`/
  /// `interTextTheme` rebuild a full `TextTheme` via `copyWith` each call,
  /// which is unnecessary work if `headline`/`title`/`body`/etc. below get
  /// called repeatedly from `build()`.
  static TextTheme get textTheme => _cachedTextTheme ??= _buildTextTheme();

  static TextTheme _buildTextTheme() {
    final base = _baseTextTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    TextStyle barlow(TextStyle? style, {FontWeight? weight}) =>
        GoogleFonts.barlow(textStyle: style, fontWeight: weight);

    return base.copyWith(
      displayLarge: barlow(base.displayLarge, weight: FontWeight.w900),
      displayMedium: barlow(base.displayMedium, weight: FontWeight.w800),
      displaySmall: barlow(base.displaySmall, weight: FontWeight.w800),
      headlineLarge: barlow(base.headlineLarge, weight: FontWeight.w800),
      headlineMedium: barlow(base.headlineMedium, weight: FontWeight.w700),
      headlineSmall: barlow(base.headlineSmall, weight: FontWeight.w700),
      titleLarge: barlow(base.titleLarge, weight: FontWeight.w700),
      titleMedium: barlow(base.titleMedium, weight: FontWeight.w600),
      titleSmall: barlow(base.titleSmall, weight: FontWeight.w600),
    );
  }

  /// Headline style (e.g. "Encontrá dónde comer.") — Barlow 800.
  static TextStyle get headline => textTheme.headlineLarge!;

  /// Merchant name / amount style — Barlow 700.
  static TextStyle get title => textTheme.titleLarge!;

  /// Body copy — Inter regular.
  static TextStyle get body => textTheme.bodyMedium!;

  /// Secondary/muted body copy — Inter regular, `textSecondary` color.
  static TextStyle get bodySecondary =>
      textTheme.bodyMedium!.copyWith(color: textSecondary);

  /// Button label style — Inter 600.
  static TextStyle get button =>
      textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600);

  // ---------------------------------------------------------------------
  // ColorScheme
  // ---------------------------------------------------------------------

  /// `error` and `onSecondary` below are NOT tokens from the design brief
  /// (the prototype has no error-state or gift-card-tier-independent
  /// on-secondary color documented) — they're reasonable choices derived
  /// from the existing palette (a standard Material dark-mode red for
  /// error, `backgroundOuter` for on-secondary contrast against
  /// `rewardGreen`). Don't treat them as "official" design values if a
  /// real error/toast design shows up later.
  static ColorScheme get _colorScheme => const ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: rewardGreen,
        onSecondary: Color(0xFF0E0F16),
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceSecondary,
        error: Color(0xFFFF5252),
        onError: Colors.white,
        outline: border,
      );

  // ---------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------

  static ThemeData get dark {
    final colorScheme = _colorScheme;
    final resolvedTextTheme = textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: resolvedTextTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      // Full-pill floating nav is built as a custom widget (blur + central
      // QR action) — this theme just sets sane defaults for the meantime.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: accent,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCardLarge),
          side: const BorderSide(color: border),
        ),
      ),
      // Gradient CTA buttons (search, delivery, filters, gift) can't be
      // expressed through ButtonStyle's flat background — those are built
      // as custom widgets using AppTheme.ctaGradient directly in screens.
      // This FilledButton/ElevatedButton theming covers secondary/solid
      // (non-gradient) buttons, e.g. the "Iniciar sesión" solid button.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle: button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle: button,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          textStyle: button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: body.copyWith(color: textTertiary),
        labelStyle: body.copyWith(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radiusBottomSheetTop),
            topRight: Radius.circular(radiusBottomSheetTop),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSecondary,
        labelStyle: body.copyWith(color: textSecondary, fontSize: 13),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : surfaceSecondary,
        ),
      ),
    );
  }
}
