import 'dart:io' show Platform;
import 'dart:ui';

import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';
import 'package:provider/provider.dart';
import 'package:spectator/bridge.dart';
import 'package:spectator/screens/account/account.dart';
import 'package:spectator/screens/about_app/about_app.dart';
import 'package:spectator/screens/home/userScreens/About.dart';
import 'package:spectator/screens/home/userScreens/Data.dart';
import 'package:spectator/screens/home/userScreens/MainScouting.dart';
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/PitScouting.dart';
import 'package:spectator/screens/home/userScreens/Students.dart';
import 'package:spectator/screens/login/login.dart';
import 'package:spectator/theme/appearance.dart';
import 'package:spectator/widgets/liquid_glass.dart';

bool get _isApplePlatform =>
    !kIsWeb && (Platform.isIOS || Platform.isMacOS);

class _TabConfig {
  const _TabConfig(this.title, this.icon, this.sfSymbol, this.page);

  final String title;
  final IconData icon;
  final String sfSymbol;
  final Widget page;
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  final TabStyle _tabStyle = TabStyle.reactCircle;
  final Functions backend = Functions();

  int _currentIndex = 0;
  int _offlineCount = 0;
  bool _syncing = false;
  bool _savingForOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsModel>().syncAuthThemeState();
    });
    _loadOfflineCount();
  }

  Future<void> _loadOfflineCount() async {
    final count = await backend.getTotalOfflineQueueCount();
    if (mounted) setState(() => _offlineCount = count);
  }

  List<_TabConfig> _visibleTabs(bool isAuthenticated) {
    if (!isAuthenticated) {
      return const [
        _TabConfig('Main', Icons.view_list, 'list.bullet', MainScouting()),
        _TabConfig('About', Icons.public, 'globe', About()),
        _TabConfig('Data', Icons.analytics, 'chart.bar', DataPage()),
      ];
    }

    return const [
      _TabConfig('Main', Icons.view_list, 'list.bullet', MainScouting()),
      _TabConfig('Pit', Icons.edit_attributes, 'wrench', PitScouting()),
      _TabConfig('About', Icons.public, 'globe', About()),
      _TabConfig('Students', Icons.group, 'person.2', Students()),
      _TabConfig('Data', Icons.analytics, 'chart.bar', DataPage()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    final usedSettings = Provider.of<SettingsModel>(context);
    final isAuthenticated = backend.isAuthenticated;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSimple = usedSettings.layoutStyle == AppLayoutStyle.simple;
    final appBarBackground =
        theme.appBarTheme.backgroundColor ?? scheme.primary;
    final appBarForeground =
        theme.appBarTheme.foregroundColor ?? scheme.onPrimary;
    final drawerIconColor = scheme.onSurface;
    final drawerMuted = scheme.onSurface.withValues(alpha: 0.7);

    final tabs = _visibleTabs(isAuthenticated);
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }
    final currentTitle = tabs[_currentIndex].title;
    final navBackground = isSimple ? scheme.surface : scheme.primary;
    final navForeground = isSimple ? scheme.onSurface : scheme.onPrimary;
    final appleGlass = _isApplePlatform;

    Widget buildDrawer() {
      // --- Shared callbacks & data ---
      Future<void> onAccountTap() async {
        Navigator.pop(context);
        if (isAuthenticated) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        if (!mounted) return;
        await settings.syncAuthThemeState();
        await _loadOfflineCount();
        setState(() {});
      }

      Future<void> onSyncTap() async {
        setState(() => _syncing = true);
        try {
          final result = await backend.syncAllOfflineData();
          await _loadOfflineCount();
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Synced ${result['pit']} pit + ${result['match']} match entries',
              ),
            ),
          );
        } catch (error) {
          await _loadOfflineCount();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        } finally {
          if (mounted) setState(() => _syncing = false);
        }
      }

      Future<void> onSaveOfflineTap() async {
        setState(() => _savingForOffline = true);
        try {
          final result = await backend.syncForOffline();
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saved ${result['events']} events, '
                '${result['matches']} matches, '
                '${result['teamNames']} team names',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().replaceFirst('Exception: ', ''),
              ),
            ),
          );
        } finally {
          if (mounted) setState(() => _savingForOffline = false);
        }
      }

      void onSignOut() {
        Navigator.pop(context);
        backend.signOut();
        settings.handleSignedOut();
        setState(() => _currentIndex = 0);
      }

      // ============================================================
      // Apple Liquid Glass sidebar (Landmarks-style)
      // ============================================================
      if (appleGlass) {
        final isDark = theme.brightness == Brightness.dark;
        final labelColor =
            isDark ? Colors.white : const Color(0xFF1C1C1E);
        final mutedColor =
            isDark ? Colors.white54 : const Color(0xFF8E8E93);
        final iconColor =
            isDark ? Colors.white70 : const Color(0xFF636366);
        final selectedBg =
            isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06);
        final separatorColor =
            isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04);
        final sidebarBg =
            isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                : const Color(0xFFF2F2F7).withValues(alpha: 0.88);

        Widget sidebarRow({
          required IconData icon,
          required String label,
          VoidCallback? onTap,
          Widget? leadingOverride,
          Widget? trailing,
          bool badge = false,
          String? badgeText,
        }) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                splashColor: selectedBg,
                highlightColor: selectedBg,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      leadingOverride ??
                          Icon(icon, size: 20, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: usedSettings.fontSize,
                            fontWeight: FontWeight.w400,
                            color: labelColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (trailing != null) trailing,
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget separator() {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 6,
            ),
            child: Divider(height: 1, thickness: 0.5, color: separatorColor),
          );
        }

        final sidebarContent = ListView(
          padding: EdgeInsets.zero,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Spectator',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),

            sidebarRow(
              icon: Icons.text_fields_rounded,
              label: 'Text Size',
              trailing: Text(
                settings.fontSize == 14.0 ? 'Default' : 'Large',
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
              onTap: () {
                settings.setFontSize(
                  settings.fontSize == 14.0 ? 17.0 : 14.0,
                );
              },
            ),
            sidebarRow(
              icon: settings.themeMode == ThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : settings.themeMode == ThemeMode.light
                      ? Icons.light_mode_rounded
                      : Icons.brightness_6_rounded,
              label: 'Theme',
              trailing: Text(
                settings.themeModeLabel,
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
              onTap: () => settings.cycleThemeMode(),
            ),
            sidebarRow(
              icon: Icons.palette_rounded,
              label: 'Personal Colors',
              trailing: Switch.adaptive(
                value: settings.preferPersonalColors,
                onChanged: isAuthenticated
                    ? (v) => settings.setPreferPersonalColors(v)
                    : null,
                activeTrackColor: scheme.primary,
                activeThumbColor: Colors.white,
              ),
            ),

            separator(),

            sidebarRow(
              icon: isAuthenticated
                  ? Icons.person_rounded
                  : Icons.login_rounded,
              label: isAuthenticated ? 'Account' : 'Login',
              onTap: onAccountTap,
            ),
            if (isAuthenticated)
              sidebarRow(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                onTap: onSignOut,
              ),

            if (_offlineCount > 0) ...[
              separator(),
              sidebarRow(
                icon: Icons.cloud_sync_rounded,
                label: 'Sync Offline Data',
                badgeText: '$_offlineCount',
                leadingOverride: _syncing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : null,
                onTap: _syncing ? null : onSyncTap,
              ),
              Builder(
                builder: (tileContext) => sidebarRow(
                  icon: Icons.download_rounded,
                  label: 'Download CSV',
                  onTap: () async {
                    final box =
                        tileContext.findRenderObject() as RenderBox?;
                    final origin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : const Rect.fromLTWH(100, 100, 200, 50);
                    Navigator.pop(context);
                    await backend.downloadOfflineQueuesCsv(
                      sharePositionOrigin: origin,
                    );
                  },
                ),
              ),
            ],

            separator(),

            sidebarRow(
              icon: Icons.offline_pin_rounded,
              label: 'Save for Offline',
              leadingOverride: _savingForOffline
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : null,
              onTap: _savingForOffline ? null : onSaveOfflineTap,
            ),
            sidebarRow(
              icon: Icons.info_outline_rounded,
              label: 'About App',
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutAppPage()),
                );
              },
            ),
          ],
        );

        return Drawer(
          backgroundColor: Colors.transparent,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: sidebarBg,
                child: sidebarContent,
              ),
            ),
          ),
        );
      }

      // ============================================================
      // Standard Material drawer (non-Apple)
      // ============================================================
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: appBarBackground),
              child: Text(
                'Spectator Menu',
                style: TextStyle(color: appBarForeground, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.text_fields, color: drawerIconColor),
              title: Text(
                'Text Size',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              onTap: () {
                settings.setFontSize(
                  settings.fontSize == 14.0 ? 17.0 : 14.0,
                );
              },
            ),
            ListTile(
              leading: Icon(
                settings.themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : settings.themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.brightness_6,
                color: drawerIconColor,
              ),
              title: Text(
                'Theme: ${settings.themeModeLabel}',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              subtitle: Text(
                'Tap to cycle System, Light, Dark',
                style: TextStyle(color: drawerMuted),
              ),
              onTap: () => settings.cycleThemeMode(),
            ),
            GlassSwitchListTile(
              activeThumbColor: scheme.secondary,
              title: Text(
                'Use Personal Colors',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              subtitle: Text(
                isAuthenticated
                    ? 'Overrides team colors when your personal colors are set.'
                    : 'Set your own colors after login in Account.',
                style: TextStyle(color: drawerMuted),
              ),
              value: settings.preferPersonalColors,
              onChanged: isAuthenticated
                  ? (value) => settings.setPreferPersonalColors(value)
                  : null,
            ),
            ListTile(
              leading: Icon(
                isAuthenticated ? Icons.account_circle : Icons.login,
                color: drawerIconColor,
              ),
              title: Text(
                isAuthenticated ? 'Account' : 'Login',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              onTap: onAccountTap,
            ),
            if (_offlineCount > 0) ...[
              const Divider(height: 18),
              ListTile(
                leading: _syncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.cloud_sync, color: drawerIconColor),
                title: Text(
                  'Send Offline Data ($_offlineCount)',
                  style: TextStyle(
                    color: drawerIconColor,
                    fontSize: usedSettings.fontSize,
                  ),
                ),
                subtitle: Text(
                  'Sync queued pit & match entries',
                  style: TextStyle(color: drawerMuted),
                ),
                onTap: _syncing ? null : onSyncTap,
              ),
              Builder(
                builder: (tileContext) => ListTile(
                  leading: Icon(Icons.download, color: drawerIconColor),
                  title: Text(
                    'Download Offline CSV',
                    style: TextStyle(
                      color: drawerIconColor,
                      fontSize: usedSettings.fontSize,
                    ),
                  ),
                  onTap: () async {
                    final box =
                        tileContext.findRenderObject() as RenderBox?;
                    final origin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : const Rect.fromLTWH(100, 100, 200, 50);
                    Navigator.pop(context);
                    await backend.downloadOfflineQueuesCsv(
                      sharePositionOrigin: origin,
                    );
                  },
                ),
              ),
            ],
            const Divider(height: 18),
            ListTile(
              leading: _savingForOffline
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.offline_pin, color: drawerIconColor),
              title: Text(
                'Save for Offline',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              subtitle: Text(
                'Download all data for offline scouting',
                style: TextStyle(color: drawerMuted),
              ),
              onTap: _savingForOffline ? null : onSaveOfflineTap,
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: drawerIconColor),
              title: Text(
                'About App',
                style: TextStyle(
                  color: drawerIconColor,
                  fontSize: usedSettings.fontSize,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AboutAppPage(),
                  ),
                );
              },
            ),
            if (isAuthenticated)
              ListTile(
                leading: Icon(Icons.logout, color: drawerIconColor),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: drawerIconColor,
                    fontSize: usedSettings.fontSize,
                  ),
                ),
                onTap: onSignOut,
              ),
          ],
        ),
      );
    }

    final appBar = AppBar(
      iconTheme: IconThemeData(color: appBarForeground),
      flexibleSpace: appleGlass
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.transparent),
              ),
            )
          : null,
      title: Text(
        'Spectator $currentTitle',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: appBarForeground,
          letterSpacing: 0.4,
        ),
      ),
      centerTitle: true,
    );

    void onNavTap(int index) {
      setState(() {
        _currentIndex = index;
      });
      _loadOfflineCount();
    }

    Widget bottomNav;
    if (appleGlass) {
      bottomNav = NativeGlassNavBar(
        currentIndex: _currentIndex,
        onTap: onNavTap,
        tabs: <NativeGlassNavBarItem>[
          for (final tab in tabs)
            NativeGlassNavBarItem(label: tab.title, symbol: tab.sfSymbol),
        ],
        fallback: ConvexAppBar(
          backgroundColor: navBackground,
          color: navForeground.withValues(alpha: 0.7),
          activeColor: navForeground,
          style: _tabStyle,
          height: 56,
          items: <TabItem>[
            for (final tab in tabs)
              TabItem(icon: tab.icon, title: tab.title),
          ],
          onTap: onNavTap,
        ),
      );
    } else {
      bottomNav = ConvexAppBar(
        backgroundColor: navBackground,
        color: navForeground.withValues(alpha: 0.7),
        activeColor: navForeground,
        style: _tabStyle,
        height: 56,
        items: <TabItem>[
          for (final tab in tabs)
            TabItem(icon: tab.icon, title: tab.title),
        ],
        onTap: onNavTap,
      );
    }

    return DefaultTabController(
      length: tabs.length,
      initialIndex: _currentIndex,
      child: Scaffold(
        appBar: appBar,
        drawer: buildDrawer(),
        body: tabs[_currentIndex].page,
        bottomNavigationBar: bottomNav,
      ),
    );
  }
}
