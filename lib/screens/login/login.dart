import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();

  @override
  void initState() {
    super.initState();
    _loadAuthConfig();
  }

  Future<void> _loadAuthConfig() async {
    await backend.refreshAuthConfig();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = backend.loginOutputs[2] as bool;
    final loading = backend.loginOutputs[0] as bool;
    final error = backend.loginOutputs[1] as String;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.baseColors[4],
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(measurements.extraLargePadding),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'SPECTATOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: colors.baseColors[0],
                      ),
                    ),
                    SizedBox(height: measurements.largePadding),
                    TextFormField(
                      style: TextStyle(color: colors.baseColors[2]),
                      decoration: _inputDecoration(
                        'Name (Username)',
                        Icons.person,
                      ),
                      onChanged: (val) => backend.loginInputs[0] = val,
                      validator: (val) => val!.isEmpty ? 'Enter name' : null,
                    ),
                    SizedBox(height: measurements.mediumPadding),
                    TextFormField(
                      obscureText: true,
                      style: TextStyle(color: colors.baseColors[2]),
                      decoration: _inputDecoration('Password', Icons.lock),
                      onChanged: (val) => backend.loginInputs[1] = val,
                      validator: (val) =>
                          val!.length < 6 ? '6+ chars required' : null,
                    ),
                    if (!isLogin) ...[
                      SizedBox(height: measurements.mediumPadding),
                      DropdownButtonFormField<String>(
                        initialValue: backend.signupRole,
                        decoration: _inputDecoration(
                          'Signup Role',
                          Icons.badge,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Student'),
                          ),
                          DropdownMenuItem(
                            value: 'team_manager',
                            child: Text('Team Manager'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            backend.signupRole = value ?? 'student';
                          });
                        },
                      ),
                      SizedBox(height: measurements.mediumPadding),
                      TextFormField(
                        style: TextStyle(color: colors.baseColors[2]),
                        decoration: _inputDecoration(
                          'Team Number',
                          Icons.numbers,
                        ),
                        onChanged: (val) => backend.loginInputs[2] = val,
                        validator: (val) {
                          if (isLogin) return null;
                          return (val == null || val.trim().isEmpty)
                              ? 'Team number required'
                              : null;
                        },
                      ),
                      SizedBox(height: measurements.mediumPadding),
                      TextFormField(
                        style: TextStyle(color: colors.baseColors[2]),
                        decoration: _inputDecoration('Email', Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (val) => backend.loginInputs[3] = val,
                        validator: (val) {
                          if (isLogin) return null;
                          final email = (val ?? '').trim();
                          if (email.isEmpty) return 'Email required';
                          if (!email.contains('@')) return 'Enter valid email';
                          return null;
                        },
                      ),
                      if (backend.signupRole == 'student') ...[
                        SizedBox(height: measurements.mediumPadding),
                        TextFormField(
                          style: TextStyle(color: colors.baseColors[2]),
                          decoration: _inputDecoration(
                            'Student Invite Code (64 chars)',
                            Icons.vpn_key,
                          ),
                          onChanged: (val) => backend.loginInputs[4] = val,
                          validator: (val) {
                            if (isLogin || backend.signupRole != 'student') {
                              return null;
                            }
                            return (val == null || val.trim().length != 64)
                                ? '64-char invite code required'
                                : null;
                          },
                        ),
                      ],
                    ],
                    SizedBox(height: measurements.extraLargePadding),
                    SizedBox(
                      height: measurements.clickHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accentColors[0],
                        ),
                        onPressed: loading
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  setState(() {});
                                  await backend.handleAuth(context);
                                  if (!mounted) return;
                                  setState(() {});
                                }
                              },
                        child: loading
                            ? CircularProgressIndicator(
                                color: colors.baseColors[0],
                              )
                            : Text(
                                isLogin ? 'LOGIN' : 'SIGN UP',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: colors.baseColors[0],
                                ),
                              ),
                      ),
                    ),
                    if (kIsWeb && backend.passkeysEnabled && isLogin) ...[
                      SizedBox(height: measurements.mediumPadding),
                      SizedBox(
                        height: measurements.clickHeight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.password),
                          label: const Text('LOGIN WITH PASSKEY'),
                          onPressed: loading
                              ? null
                              : () async {
                                  setState(() {});
                                  await backend.loginWithPasskey(
                                    context,
                                    backend.loginInputs[0],
                                  );
                                  if (!mounted) return;
                                  setState(() {});
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accentColors[0],
                            side: BorderSide(color: colors.accentColors[0]),
                          ),
                        ),
                      ),
                    ],
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (backend.signupEnabled)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            backend.toggleAuthMode();
                          });
                        },
                        child: Text(
                          isLogin
                              ? 'New here? Sign Up'
                              : 'Have an account? Login',
                          style: TextStyle(color: colors.baseColors[1]),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Signup is disabled by the server.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.baseColors[1]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.baseColors[2]),
      prefixIcon: Icon(icon, color: colors.accentColors[0]),
      filled: true,
      fillColor: colors.mainColors[2].withOpacity(0.5),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.mainColors[1]),
        borderRadius: BorderRadius.circular(15.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.accentColors[0], width: 2.0),
        borderRadius: BorderRadius.circular(15.0),
      ),
    );
  }
}
