import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/account/account.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/screens/home/userScreens/About.dart';
import 'package:spectator/screens/home/userScreens/Data.dart';
import 'package:spectator/screens/home/userScreens/MainScouting.dart';
import 'package:spectator/screens/home/userScreens/PitScoutingFolder/PitScouting.dart';
import 'package:spectator/screens/home/userScreens/Students.dart';
import 'package:spectator/screens/login/login.dart';

class SettingsModel with ChangeNotifier {
  double _fontSize = 14.0;
  double get fontSize => _fontSize;

  void setFontSize(double newSize) {
    _fontSize = newSize;
    notifyListeners();
  }
}

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
  final dynamic colors = Colorings();
  final Functions backend = Functions();

  int _currentIndex = 0;

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

    final tabs = _visibleTabs(isAuthenticated);
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }
    final currentTitle = tabs[_currentIndex].title;

    return DefaultTabController(
      length: tabs.length,
      initialIndex: _currentIndex,
      child: Scaffold(
        backgroundColor: colors.baseColors[4],
        appBar: AppBar(
          backgroundColor: colors.mainColors[0],
          title: Text(
            'Spectator $currentTitle',
            style: TextStyle(
              fontSize: 24,
              color: colors.accentColors[0],
              fontFamily: 'Monospace',
              fontStyle: FontStyle.normal,
              fontFeatures: const [FontFeature.enable('smcp')],
              letterSpacing: 10.0,
            ),
          ),
          centerTitle: true,
        ),
        drawer: Drawer(
          backgroundColor: colors.baseColors[4],
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(color: colors.mainColors[0]),
                child: Text(
                  'Spectator Menu',
                  style: TextStyle(color: colors.accentColors[0], fontSize: 24),
                ),
              ),
              ListTile(
                leading: Icon(Icons.text_fields, color: colors.accentColors[0]),
                title: Text(
                  'Text Size',
                  style: TextStyle(
                    color: colors.accentColors[0],
                    fontSize: usedSettings.fontSize,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  settings.setFontSize(settings.fontSize == 14.0 ? 17.0 : 14.0);
                },
              ),
              ListTile(
                leading: Icon(
                  isAuthenticated ? Icons.account_circle : Icons.login,
                  color: colors.accentColors[0],
                ),
                title: Text(
                  isAuthenticated ? 'Account' : 'Login',
                  style: TextStyle(
                    color: colors.accentColors[0],
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
                  setState(() {});
                },
              ),
              if (isAuthenticated && backend.passkeysEnabled && kIsWeb)
                ListTile(
                  leading: Icon(Icons.password, color: colors.accentColors[0]),
                  title: Text(
                    'Register Passkey',
                    style: TextStyle(
                      color: colors.accentColors[0],
                      fontSize: usedSettings.fontSize,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await backend.registerPasskey(context);
                    if (!mounted) return;
                    setState(() {});
                  },
                ),
              if (isAuthenticated)
                ListTile(
                  leading: Icon(Icons.logout, color: colors.accentColors[0]),
                  title: Text(
                    'Sign Out',
                    style: TextStyle(
                      color: colors.accentColors[0],
                      fontSize: usedSettings.fontSize,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    backend.signOut();
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                ),
            ],
          ),
        ),
        body: tabs[_currentIndex].page,
        bottomNavigationBar: ConvexAppBar(
          backgroundColor: colors.mainColors[0],
          color: colors.accentColors[0],
          activeColor: colors.accentColors[0],
          style: _tabStyle,
          items: <TabItem>[
            for (final tab in tabs) TabItem(icon: tab.icon, title: tab.title),
          ],
          onTap: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
      ),
    );
  }
}
