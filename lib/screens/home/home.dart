import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
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

class _TabConfig {
  const _TabConfig(this.title, this.icon, this.page);

  final String title;
  final IconData icon;
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
        _TabConfig('Main', Icons.view_list, MainScouting()),
        _TabConfig('About', Icons.public, About()),
        _TabConfig('Data', Icons.analytics, DataPage()),
      ];
    }

    return const [
      _TabConfig('Main', Icons.view_list, MainScouting()),
      _TabConfig('Pit', Icons.edit_attributes, PitScouting()),
      _TabConfig('About', Icons.public, About()),
      _TabConfig('Students', Icons.group, Students()),
      _TabConfig('Data', Icons.analytics, DataPage()),
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

    Widget buildDrawer() {
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
                settings.setFontSize(settings.fontSize == 14.0 ? 17.0 : 14.0);
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
              onTap: () {
                settings.cycleThemeMode();
              },
            ),
            SwitchListTile(
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
              onTap: () async {
                Navigator.pop(context);
                if (isAuthenticated) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountPage(),
                    ),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                }
                if (!mounted) return;
                await settings.syncAuthThemeState();
                await _loadOfflineCount();
                setState(() {});
              },
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
                onTap: _syncing
                    ? null
                    : () async {
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
                                error
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _syncing = false);
                        }
                      },
              ),
              ListTile(
                leading: Icon(Icons.download, color: drawerIconColor),
                title: Text(
                  'Download Offline CSV',
                  style: TextStyle(
                    color: drawerIconColor,
                    fontSize: usedSettings.fontSize,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await backend.downloadOfflineQueuesCsv();
                },
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
              onTap: _savingForOffline
                  ? null
                  : () async {
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
                              error
                                  .toString()
                                  .replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _savingForOffline = false);
                        }
                      }
                    },
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
                    builder: (context) => const AboutAppPage(),
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
                onTap: () {
                  Navigator.pop(context);
                  backend.signOut();
                  settings.handleSignedOut();
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      initialIndex: _currentIndex,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(color: appBarForeground),
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
        ),
        drawer: buildDrawer(),
        body: tabs[_currentIndex].page,
        bottomNavigationBar: ConvexAppBar(
          backgroundColor: navBackground,
          color: navForeground.withValues(alpha: 0.7),
          activeColor: navForeground,
          style: _tabStyle,
          height: 56,
          items: <TabItem>[
            for (final tab in tabs) TabItem(icon: tab.icon, title: tab.title),
          ],
          onTap: (int index) {
            setState(() {
              _currentIndex = index;
            });
            _loadOfflineCount();
          },
        ),
      ),
    );
  }
}
