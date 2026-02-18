import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spectator/screens/home/color.dart';
import 'package:spectator/something.dart';
import 'package:spectator/theme/appearance.dart';
import 'package:spectator/widgets/color_picker_dialog.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  Future<void> _choosePersonalPrimary(SettingsModel settings) async {
    final picked = await showColorPickerDialog(
      context: context,
      title: 'Personal Primary Color',
      initialColor: settings.userPrimaryColor ?? settings.effectivePrimaryColor,
    );
    if (picked == null) return;
    await settings.setUserPrimaryColor(picked);
  }

  Future<void> _choosePersonalAccent(SettingsModel settings) async {
    final picked = await showColorPickerDialog(
      context: context,
      title: 'Personal Accent Color',
      initialColor: settings.userAccentColor ?? settings.effectiveAccentColor,
    );
    if (picked == null) return;
    await settings.setUserAccentColor(picked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final avatarUrl = backend.avatarUrl;
    final userLabel = backend.currentUsername ?? 'Unknown';
    final email = backend.currentEmail ?? '';
    final role = backend.role;
    final teamNumber = backend.teamNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: ListView(
        padding: EdgeInsets.all(measurements.largePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            userLabel.isNotEmpty
                                ? userLabel[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty) Text(email),
                        Text('Role: $role'),
                        if (teamNumber.isNotEmpty) Text('Team: $teamNumber'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_6),
                        label: Text('System'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      settings.setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<AppLayoutStyle>(
                    segments: const [
                      ButtonSegment<AppLayoutStyle>(
                        value: AppLayoutStyle.classic,
                        label: Text('Classic'),
                      ),
                      ButtonSegment<AppLayoutStyle>(
                        value: AppLayoutStyle.simple,
                        label: Text('Simple'),
                      ),
                    ],
                    selected: {settings.layoutStyle},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      settings.setLayoutStyle(selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Override Team Colors'),
                    subtitle: Text(
                      settings.hasTeamColors
                          ? 'Use personal colors instead of team colors.'
                          : 'No team colors found. Personal colors will be used when set.',
                    ),
                    value: settings.preferPersonalColors,
                    onChanged: (value) {
                      settings.setPreferPersonalColors(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _choosePersonalPrimary(settings),
                          icon: Icon(
                            Icons.square,
                            color:
                                settings.userPrimaryColor ??
                                settings.effectivePrimaryColor,
                          ),
                          label: const Text('Personal Primary'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _choosePersonalAccent(settings),
                          icon: Icon(
                            Icons.square,
                            color:
                                settings.userAccentColor ??
                                settings.effectiveAccentColor,
                          ),
                          label: const Text('Personal Accent'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor:
                              settings.userPrimaryColor ??
                              settings.effectivePrimaryColor,
                        ),
                        label: Text(
                          'Primary ${settings.userPrimaryColor == null ? "(default)" : ""}',
                        ),
                      ),
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor:
                              settings.userAccentColor ??
                              settings.effectiveAccentColor,
                        ),
                        label: Text(
                          'Accent ${settings.userAccentColor == null ? "(default)" : ""}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: settings.hasPersonalColors
                          ? () => settings.resetPersonalColors()
                          : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset Personal Colors'),
                    ),
                  ),
                  if (settings.teamThemeLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (settings.teamThemeError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        settings.teamThemeError,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (backend.canEditAbout)
            Card(
              child: ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Team Branding'),
                subtitle: const Text(
                  'Team managers can set team colors from About > Edit About Page.',
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (kIsWeb && backend.passkeysEnabled)
            FilledButton.icon(
              onPressed: () async {
                await backend.registerPasskey(context);
                if (!mounted) return;
                setState(() {});
              },
              icon: const Icon(Icons.password),
              label: const Text('Register Passkey'),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              backend.signOut();
              context.read<SettingsModel>().handleSignedOut();
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
