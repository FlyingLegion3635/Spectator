import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spectator/something.dart';

enum AppLayoutStyle { classic, simple }

class ThemePaletteBridge {
  static ThemePalette _palette = ThemePalette(
    brightness: Brightness.dark,
    primary: const Color(0xFF1242F1),
    accent: const Color(0xFFFCA10F),
    layoutStyle: AppLayoutStyle.classic,
  );

  static List<Color> get mainColors => _palette.mainColors;
  static List<Color> get accentColors => _palette.accentColors;
  static List<Color> get baseColors => _palette.baseColors;
}

class ThemePalette {
  const ThemePalette({
    required this.brightness,
    required this.primary,
    required this.accent,
    required this.layoutStyle,
  });

  final Brightness brightness;
  final Color primary;
  final Color accent;
  final AppLayoutStyle layoutStyle;

  static Color onColor(Color background) {
    final isDark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF0F172A);
  }

  List<Color> get mainColors {
    if (brightness == Brightness.dark) {
      switch (layoutStyle) {
        case AppLayoutStyle.classic:
          return [
            primary,
            _mix(primary, Colors.white, 0.18),
            _mix(primary, Colors.black, 0.28),
          ];
        case AppLayoutStyle.simple:
          return const [
            Color(0xFF111827),
            Color(0xFF1F2937),
            Color(0xFF0B1220),
          ];
      }
    }

    switch (layoutStyle) {
      case AppLayoutStyle.classic:
        return [
          _mix(primary, Colors.white, 0.1),
          _mix(primary, Colors.white, 0.34),
          _mix(primary, Colors.white, 0.78),
        ];
      case AppLayoutStyle.simple:
        return const [
          Color(0xFFF8FAFC),
          Color(0xFFE2E8F0),
          Color(0xFFF1F5F9),
        ];
    }
  }

  List<Color> get accentColors {
    if (brightness == Brightness.dark) {
      switch (layoutStyle) {
        case AppLayoutStyle.classic:
          return [
            accent,
            _mix(accent, Colors.white, 0.18),
            _mix(accent, Colors.black, 0.32),
          ];
        case AppLayoutStyle.simple:
          return [
            _mix(accent, const Color(0xFF64748B), 0.58),
            _mix(accent, const Color(0xFF94A3B8), 0.68),
            _mix(accent, const Color(0xFF334155), 0.7),
          ];
      }
    }

    switch (layoutStyle) {
      case AppLayoutStyle.classic:
        return [
          _mix(accent, Colors.white, 0.14),
          _mix(accent, Colors.white, 0.36),
          _mix(accent, Colors.white, 0.78),
        ];
      case AppLayoutStyle.simple:
        return [
          _mix(accent, const Color(0xFFD1D5DB), 0.74),
          _mix(accent, const Color(0xFFE5E7EB), 0.86),
          _mix(accent, const Color(0xFFF9FAFB), 0.92),
        ];
    }
  }

  List<Color> get baseColors {
    if (brightness == Brightness.dark) {
      switch (layoutStyle) {
        case AppLayoutStyle.classic:
          return const [
            Color(0xFFFFFFFF),
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E1),
            Color(0xFF64748B),
            Color(0xFF0B1220),
          ];
        case AppLayoutStyle.simple:
          return const [
            Color(0xFFE5E7EB),
            Color(0xFFD1D5DB),
            Color(0xFF9CA3AF),
            Color(0xFF6B7280),
            Color(0xFF111827),
          ];
      }
    }

    switch (layoutStyle) {
      case AppLayoutStyle.classic:
        return const [
          Color(0xFF0F172A),
          Color(0xFF334155),
          Color(0xFF1E293B),
          Color(0xFF64748B),
          Color(0xFFF8FAFC),
        ];
      case AppLayoutStyle.simple:
        return const [
          Color(0xFF111827),
          Color(0xFF374151),
          Color(0xFF4B5563),
          Color(0xFF6B7280),
          Color(0xFFFFFFFF),
        ];
    }
  }

  static Color _mix(Color a, Color b, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final aRed = (a.r * 255.0).round().clamp(0, 255);
    final aGreen = (a.g * 255.0).round().clamp(0, 255);
    final aBlue = (a.b * 255.0).round().clamp(0, 255);
    final bRed = (b.r * 255.0).round().clamp(0, 255);
    final bGreen = (b.g * 255.0).round().clamp(0, 255);
    final bBlue = (b.b * 255.0).round().clamp(0, 255);
    return Color.fromARGB(
      255,
      (aRed + ((bRed - aRed) * clamped)).round().clamp(0, 255),
      (aGreen + ((bGreen - aGreen) * clamped)).round().clamp(0, 255),
      (aBlue + ((bBlue - aBlue) * clamped)).round().clamp(0, 255),
    );
  }
}

class SettingsModel extends ChangeNotifier with WidgetsBindingObserver {
  SettingsModel() {
    WidgetsBinding.instance.addObserver(this);
    _applyPalette();
    unawaited(_hydrate());
    unawaited(syncAuthThemeState());
  }

  static const _defaultPrimary = Color(0xFF1242F1);
  static const _defaultAccent = Color(0xFFFCA10F);

  static const _fontSizeKey = 'spectator.ui.fontSize';
  static const _themeModeKey = 'spectator.ui.themeMode';
  static const _preferPersonalColorsKey = 'spectator.ui.preferPersonalColors';
  static const _userPrimaryColorKey = 'spectator.ui.userPrimaryColor';
  static const _userAccentColorKey = 'spectator.ui.userAccentColor';
  static const _layoutStyleKey = 'spectator.ui.layoutStyle';

  final Functions _backend = Functions();

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 14.0;
  bool _preferPersonalColors = false;
  AppLayoutStyle _layoutStyle = AppLayoutStyle.classic;

  Color? _userPrimaryColor;
  Color? _userAccentColor;

  Color? _teamPrimaryColor;
  Color? _teamAccentColor;

  bool _teamThemeLoading = false;
  String _teamThemeError = '';

  Brightness _systemBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  double get fontSize => _fontSize;
  ThemeMode get themeMode => _themeMode;
  bool get preferPersonalColors => _preferPersonalColors;
  AppLayoutStyle get layoutStyle => _layoutStyle;

  bool get hasTeamColors =>
      _teamPrimaryColor != null || _teamAccentColor != null;
  bool get hasPersonalColors =>
      _userPrimaryColor != null || _userAccentColor != null;

  Color? get userPrimaryColor => _userPrimaryColor;
  Color? get userAccentColor => _userAccentColor;
  Color? get teamPrimaryColor => _teamPrimaryColor;
  Color? get teamAccentColor => _teamAccentColor;

  bool get teamThemeLoading => _teamThemeLoading;
  String get teamThemeError => _teamThemeError;

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String get layoutStyleLabel {
    switch (_layoutStyle) {
      case AppLayoutStyle.classic:
        return 'Classic';
      case AppLayoutStyle.simple:
        return 'Simple';
    }
  }

  Brightness get effectiveBrightness {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return _systemBrightness;
    }
  }

  Color get effectivePrimaryColor {
    if (_preferPersonalColors && _userPrimaryColor != null) {
      return _userPrimaryColor!;
    }
    if (_teamPrimaryColor != null) {
      return _teamPrimaryColor!;
    }
    if (_userPrimaryColor != null) {
      return _userPrimaryColor!;
    }
    return _defaultPrimary;
  }

  Color get effectiveAccentColor {
    if (_preferPersonalColors && _userAccentColor != null) {
      return _userAccentColor!;
    }
    if (_teamAccentColor != null) {
      return _teamAccentColor!;
    }
    if (_userAccentColor != null) {
      return _userAccentColor!;
    }
    return _defaultAccent;
  }

  ThemeData get lightTheme => _buildTheme(Brightness.light);
  ThemeData get darkTheme => _buildTheme(Brightness.dark);

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = (prefs.getString(_themeModeKey) ?? 'system').trim();
    final fontRaw = prefs.getDouble(_fontSizeKey);

    _themeMode = _fromThemeModeString(modeRaw);
    _fontSize = fontRaw ?? _fontSize;
    _preferPersonalColors = prefs.getBool(_preferPersonalColorsKey) ?? false;
    _userPrimaryColor = _parseHexColor(prefs.getString(_userPrimaryColorKey));
    _userAccentColor = _parseHexColor(prefs.getString(_userAccentColorKey));
    _layoutStyle = _fromLayoutStyleString(
      (prefs.getString(_layoutStyleKey) ?? 'classic').trim(),
    );

    _applyPalette();
    notifyListeners();
  }

  ThemeData _buildTheme(Brightness brightness) {
    final primary = effectivePrimaryColor;
    final accent = effectiveAccentColor;
    final seed = Color.lerp(primary, accent, 0.35) ?? primary;
    final onPrimary = ThemePalette.onColor(primary);
    final onSecondary = ThemePalette.onColor(accent);
    final isSimple = _layoutStyle == AppLayoutStyle.simple;
    final surfaceBase = brightness == Brightness.dark
        ? (isSimple ? const Color(0xFF0F172A) : const Color(0xFF162238))
        : Colors.white;
    final surfaceHigh = brightness == Brightness.dark
        ? const Color(0xFF1C2A45)
        : const Color(0xFFE2E8F0);

    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
      primary: primary,
      secondary: accent,
      tertiary: accent,
      onPrimary: onPrimary,
      onSecondary: onSecondary,
      surface: surfaceBase,
      surfaceContainerHighest: surfaceHigh,
      onSurface: brightness == Brightness.dark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF0F172A),
      outline: brightness == Brightness.dark
          ? const Color(0xFF334155)
          : const Color(0xFFCBD5E1),
    );
    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final appBarBackground =
        isSimple ? scheme.surface : primary;
    final appBarForeground =
        isSimple ? scheme.onSurface : onPrimary;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0B1220)
          : const Color(0xFFF1F5F9),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: appBarForeground,
        elevation: isSimple ? 0.0 : 0.6,
        scrolledUnderElevation: isSimple ? 0.0 : 0.8,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isSimple
            ? scheme.surface
            : (brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFF8FAFC)),
      ),
      cardTheme: CardThemeData(
        elevation: isSimple ? 0 : 1.2,
        color: isSimple ? scheme.surface : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isSimple ? 10 : 18,
          ),
          side: isSimple
              ? BorderSide(color: scheme.outline.withValues(alpha: 0.4))
              : BorderSide.none,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isSimple
            ? scheme.surface
            : (brightness == Brightness.dark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.42)
                  : Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isSimple ? 8 : 14,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isSimple ? 8 : 14,
          ),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            isSimple ? 8 : 14,
          ),
          borderSide: BorderSide(color: accent, width: 2.0),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onSecondary,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.secondary,
        textColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: isSimple ? 0.4 : 0.2),
      ),
    );
  }

  void _applyPalette() {
    ThemePaletteBridge._palette = ThemePalette(
      brightness: effectiveBrightness,
      primary: effectivePrimaryColor,
      accent: effectiveAccentColor,
      layoutStyle: _layoutStyle,
    );
  }

  ThemeMode _fromThemeModeString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _toThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setFontSize(double newSize) async {
    _fontSize = newSize;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _applyPalette();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _toThemeModeString(mode));
  }

  AppLayoutStyle _fromLayoutStyleString(String value) {
    switch (value) {
      case 'simple':
        return AppLayoutStyle.simple;
      default:
        return AppLayoutStyle.classic;
    }
  }

  String _toLayoutStyleString(AppLayoutStyle style) {
    switch (style) {
      case AppLayoutStyle.classic:
        return 'classic';
      case AppLayoutStyle.simple:
        return 'simple';
    }
  }

  Future<void> setLayoutStyle(AppLayoutStyle style) async {
    _layoutStyle = style;
    _applyPalette();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutStyleKey, _toLayoutStyleString(style));
  }

  Future<void> cycleThemeMode() async {
    switch (_themeMode) {
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
    }
  }

  Future<void> setPreferPersonalColors(bool prefer) async {
    _preferPersonalColors = prefer;
    _applyPalette();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferPersonalColorsKey, _preferPersonalColors);
  }

  Future<void> setUserPrimaryColor(Color? color) async {
    _userPrimaryColor = color;
    _applyPalette();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_userPrimaryColorKey);
      return;
    }
    await prefs.setString(_userPrimaryColorKey, toHex(color));
  }

  Future<void> setUserAccentColor(Color? color) async {
    _userAccentColor = color;
    _applyPalette();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_userAccentColorKey);
      return;
    }
    await prefs.setString(_userAccentColorKey, toHex(color));
  }

  Future<void> resetPersonalColors() async {
    _userPrimaryColor = null;
    _userAccentColor = null;
    _preferPersonalColors = false;
    _applyPalette();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrimaryColorKey);
    await prefs.remove(_userAccentColorKey);
    await prefs.setBool(_preferPersonalColorsKey, false);
  }

  Future<void> syncAuthThemeState() async {
    await _backend.ready;

    if (!_backend.isAuthenticated || (_backend.teamNumber ?? '').isEmpty) {
      final hadTeamColors = hasTeamColors || _teamThemeError.isNotEmpty;
      _teamPrimaryColor = null;
      _teamAccentColor = null;
      _teamThemeError = '';
      if (hadTeamColors) {
        _applyPalette();
        notifyListeners();
      }
      return;
    }

    await refreshTeamBranding();
  }

  Future<void> refreshTeamBranding() async {
    if (!_backend.isAuthenticated || (_backend.teamNumber ?? '').isEmpty) {
      return;
    }

    _teamThemeLoading = true;
    _teamThemeError = '';
    notifyListeners();

    try {
      await _backend.fetchAboutProfile(teamNumber: _backend.teamNumber);
      final profile = _backend.aboutProfile;
      final uiTheme = profile['uiTheme'] as Map<String, dynamic>? ?? {};

      _teamPrimaryColor = _parseHexColor('${uiTheme['primaryColor'] ?? ''}');
      _teamAccentColor = _parseHexColor('${uiTheme['accentColor'] ?? ''}');
      _teamThemeError = '';
    } catch (error) {
      final text = error.toString();
      _teamThemeError = text.startsWith('Exception: ')
          ? text.replaceFirst('Exception: ', '')
          : text;
    } finally {
      _teamThemeLoading = false;
      _applyPalette();
      notifyListeners();
    }
  }

  void handleSignedOut() {
    _teamPrimaryColor = null;
    _teamAccentColor = null;
    _teamThemeError = '';
    _applyPalette();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    _systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (_themeMode == ThemeMode.system) {
      _applyPalette();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  static Color? _parseHexColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
      return null;
    }
    return Color(int.parse('FF${normalized.toUpperCase()}', radix: 16));
  }

  static String toHex(Color color) {
    final rgb = color.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
