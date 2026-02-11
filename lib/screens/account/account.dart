import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  @override
  Widget build(BuildContext context) {
    final avatarUrl = backend.avatarUrl;
    final userLabel = backend.currentUsername ?? 'Unknown';
    final email = backend.currentEmail ?? '';
    final role = backend.role;
    final teamNumber = backend.teamNumber ?? '';

    return Scaffold(
      backgroundColor: colors.baseColors[4],
      appBar: AppBar(
        backgroundColor: colors.mainColors[0],
        title: const Text('Account'),
      ),
      body: ListView(
        padding: EdgeInsets.all(measurements.largePadding),
        children: [
          CircleAvatar(
            radius: 38,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    userLabel.isNotEmpty ? userLabel[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 28),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text('Username: $userLabel'),
          if (email.isNotEmpty) Text('Email: $email'),
          Text('Role: $role'),
          if (teamNumber.isNotEmpty) Text('Team: $teamNumber'),
          const SizedBox(height: 20),
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
