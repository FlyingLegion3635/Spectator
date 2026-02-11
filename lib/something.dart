import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spectator/services/download/download_client.dart'
    as download_client;
import 'package:spectator/services/passkey/passkey_client.dart';

class Functions {
  static final Functions _instance = Functions._internal();
  factory Functions() => _instance;

  Functions._internal() {
    _bootstrap();
  }

  static String get _apiBaseUrl {
    const configured = String.fromEnvironment('SPECTATOR_API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:4000/api/v1';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }

    return 'http://localhost:4000/api/v1';
  }

  String? _authToken;
  String? _selectedEventKey;
  String? _username;
  String? _email;
  String? _avatarUrl;
  String? _teamNumber;
  String _role = 'scouter';

  bool _bootstrapped = false;
  final Map<String, String> _eventNameToKey = {};
  static const _sessionTokenKey = 'spectator.auth.token';
  static const _sessionUsernameKey = 'spectator.auth.username';
  static const _sessionTeamNumberKey = 'spectator.auth.teamNumber';
  static const _sessionRoleKey = 'spectator.auth.role';
  static const _sessionEmailKey = 'spectator.auth.email';
  static const _sessionAvatarKey = 'spectator.auth.avatar';

  bool signupEnabled = true;
  bool passkeysEnabled = false;

  bool get isAuthenticated => _authToken != null;
  String? get currentUsername => _username;
  String? get currentEmail => _email;
  String get avatarUrl => _avatarUrl ?? '';
  String? get teamNumber => _teamNumber;
  String get role => _role;

  bool get isTeamManager => _role == 'team_manager';
  bool get isScoutManager => _role == 'scout_manager';
  bool get isScouter => _role == 'scouter';

  bool get canManagePitTemplate => isTeamManager || isScoutManager;
  bool get canEditAbout => isTeamManager;
  bool get canInviteStudents => isTeamManager;
  bool get canAssignStudentTasks => isTeamManager || isScoutManager;
  bool get canMarkStudentTasks => isAuthenticated;
  bool get canCreateDatasheet => isTeamManager;
  bool get canRestoreVersions => isTeamManager;
  bool get canExportData => isTeamManager || isScoutManager;
  bool get canMakeRevisions => isAuthenticated;

  List<dynamic> appSettings = [14.0, false, false, false];

  void setFontSize(double size) => appSettings[0] = size;

  // [0]: username, [1]: password, [2]: teamNumber, [3]: email, [4]: inviteCode
  List<String> loginInputs = ['', '', '', '', ''];
  String signupRole = 'student';

  // [0]: loading, [1]: error, [2]: isLoginMode
  List<dynamic> loginOutputs = [false, '', true];

  List<String> pitInputs = ['', '', '', '', '', '', ''];
  Map<String, dynamic> customPitResponses = {};
  List<Map<String, dynamic>> pitTemplateFields = [];

  List<String> eventsList = ['No Events Available'];
  List<List<int>> teamsList = [
    [0, 0, 0, 0, 0, 0],
  ];

  List<String> dataSearchInput = [''];
  List<Map<String, String>> scoutingDataList = [];
  List<Map<String, String>> matchDataList = [];

  List<Map<String, dynamic>> studentsData = [];
  List<String> studentsList = [];

  List<Map<String, dynamic>> datasheets = [];
  String? selectedDatasheetId;

  Map<String, dynamic> aboutProfile = {};

  List<List<dynamic>> matchScoutingData = [];

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    try {
      await refreshAuthConfig();
      await _restoreSession();

      if (isAuthenticated) {
        await _refreshCurrentUser();
      }

      await fetchMainEventsFromTba();
      await fetchPitEntries();
      await fetchMatchEntries();
      await fetchAboutProfile();
    } catch (_) {
      // Screen-level handlers display fallback errors.
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, _authToken ?? '');
    await prefs.setString(_sessionUsernameKey, _username ?? '');
    await prefs.setString(_sessionTeamNumberKey, _teamNumber ?? '');
    await prefs.setString(_sessionRoleKey, _role);
    await prefs.setString(_sessionEmailKey, _email ?? '');
    await prefs.setString(_sessionAvatarKey, _avatarUrl ?? '');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionUsernameKey);
    await prefs.remove(_sessionTeamNumberKey);
    await prefs.remove(_sessionRoleKey);
    await prefs.remove(_sessionEmailKey);
    await prefs.remove(_sessionAvatarKey);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_sessionTokenKey) ?? '';
    if (token.isEmpty) {
      return;
    }

    _authToken = token;
    _username = (prefs.getString(_sessionUsernameKey) ?? '').trim();
    _teamNumber = (prefs.getString(_sessionTeamNumberKey) ?? '').trim();
    _role = (prefs.getString(_sessionRoleKey) ?? 'scouter').trim();
    _email = (prefs.getString(_sessionEmailKey) ?? '').trim();
    _avatarUrl = (prefs.getString(_sessionAvatarKey) ?? '').trim();
    appSettings[2] = isTeamManager || isScoutManager;
    appSettings[3] = true;
  }

  Future<void> _refreshCurrentUser() async {
    if (!isAuthenticated) return;

    try {
      final response = await _request(
        method: 'GET',
        path: '/auth/me',
        authenticated: true,
      );
      final user = response['user'] as Map<String, dynamic>? ?? {};
      _username = '${user['username'] ?? _username ?? ''}'.trim();
      _teamNumber = '${user['teamNumber'] ?? _teamNumber ?? ''}'.trim();
      _role = '${user['role'] ?? _role}'.trim();
      _email = '${user['email'] ?? _email ?? ''}'.trim();
      _avatarUrl = '${user['avatarUrl'] ?? _avatarUrl ?? ''}'.trim();
      appSettings[2] = isTeamManager || isScoutManager;
      appSettings[3] = true;
      await _persistSession();
    } catch (_) {
      signOut();
    }
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final base = _apiBaseUrl.endsWith('/')
        ? _apiBaseUrl.substring(0, _apiBaseUrl.length - 1)
        : _apiBaseUrl;

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool authenticated = false}) {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authenticated && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path, query: query);
    late final http.Response response;

    switch (method) {
      case 'GET':
        response = await http.get(
          uri,
          headers: _headers(authenticated: authenticated),
        );
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'PATCH':
        response = await http.patch(
          uri,
          headers: _headers(authenticated: authenticated),
          body: body == null ? null : jsonEncode(body),
        );
        break;
      case 'DELETE':
        response = await http.delete(
          uri,
          headers: _headers(authenticated: authenticated),
        );
        break;
      default:
        throw Exception('Unsupported request method: $method');
    }

    final raw = response.body.trim();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final asMap = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(asMap));
    }

    return asMap;
  }

  String _extractErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }

    return 'Request failed. Check backend URL and credentials.';
  }

  String _errorText(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.replaceFirst('Exception: ', '');
    }
    return text;
  }

  Future<void> refreshAuthConfig() async {
    try {
      final response = await _request(method: 'GET', path: '/auth/config');
      final config = response['config'] as Map<String, dynamic>? ?? {};
      signupEnabled = config['signupEnabled'] == true;
      passkeysEnabled = config['passkeysEnabled'] == true;

      if (!signupEnabled && !(loginOutputs[2] as bool)) {
        loginOutputs[2] = true;
      }
    } catch (_) {
      // Keep defaults.
    }
  }

  Future<void> handleAuth(BuildContext context) async {
    loginOutputs[0] = true;
    loginOutputs[1] = '';

    try {
      await refreshAuthConfig();

      final username = loginInputs[0].trim();
      final password = loginInputs[1].trim();
      final signupTeamNumber = loginInputs[2].trim();
      final signupEmail = loginInputs[3].trim();
      final signupInviteCode = loginInputs[4].trim();
      final selectedSignupRole = signupRole == 'team_manager'
          ? 'team_manager'
          : 'scouter';

      if (username.isEmpty || password.length < 6) {
        throw Exception('Please enter valid credentials.');
      }

      final isLoginMode = loginOutputs[2] as bool;
      if (!isLoginMode && !signupEnabled) {
        throw Exception('Signup is currently disabled.');
      }

      if (!isLoginMode && signupTeamNumber.isEmpty) {
        throw Exception('Team number is required for signup.');
      }

      if (!isLoginMode && signupEmail.isEmpty) {
        throw Exception('Email is required for signup.');
      }

      if (!isLoginMode &&
          selectedSignupRole == 'scouter' &&
          signupInviteCode.length != 64) {
        throw Exception('Student signup requires a 64-character invite code.');
      }

      final payload = isLoginMode
          ? {'username': username, 'password': password}
          : {
              'username': username,
              'teamNumber': signupTeamNumber,
              'email': signupEmail,
              'role': selectedSignupRole,
              if (selectedSignupRole == 'scouter')
                'inviteCode': signupInviteCode,
              'password': password,
            };

      final response = await _request(
        method: 'POST',
        path: isLoginMode ? '/auth/login' : '/auth/signup',
        body: payload,
      );

      _applyAuthenticatedState(response);

      await Future.wait([
        fetchMainEventsFromTba(),
        fetchPitTemplate(),
        fetchDatasheets(),
        fetchPitEntries(),
        fetchMatchEntries(),
        fetchStudents(),
        fetchAboutProfile(),
      ]);

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome ${_username ?? username}!')),
      );
    } catch (error) {
      loginOutputs[1] = _errorText(error);
      appSettings[3] = false;
    } finally {
      loginOutputs[0] = false;
    }
  }

  Future<void> loginWithPasskey(BuildContext context, String username) async {
    loginOutputs[0] = true;
    loginOutputs[1] = '';

    try {
      await refreshAuthConfig();

      if (!passkeysEnabled) {
        throw Exception('Passkeys are disabled on this server.');
      }

      if (username.trim().isEmpty) {
        throw Exception('Enter your username for passkey login.');
      }

      final optionsResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/login/options',
        body: {'username': username.trim()},
      );

      final options = Map<String, dynamic>.from(
        optionsResponse['options'] as Map<String, dynamic>,
      );

      final credentialResponse = await getPasskeyCredential(options);

      final verifyResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/login/verify',
        body: {'username': username.trim(), 'response': credentialResponse},
      );

      _applyAuthenticatedState(verifyResponse);

      await Future.wait([
        fetchMainEventsFromTba(),
        fetchPitTemplate(),
        fetchDatasheets(),
        fetchPitEntries(),
        fetchMatchEntries(),
        fetchStudents(),
        fetchAboutProfile(),
      ]);

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome ${_username ?? username}!')),
      );
    } catch (error) {
      loginOutputs[1] = _errorText(error);
      appSettings[3] = false;
    } finally {
      loginOutputs[0] = false;
    }
  }

  Future<void> registerPasskey(BuildContext context) async {
    try {
      await refreshAuthConfig();

      if (!passkeysEnabled) {
        throw Exception('Passkeys are disabled on this server.');
      }

      if (!isAuthenticated) {
        throw Exception('Login before registering a passkey.');
      }

      final optionsResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/register/options',
        authenticated: true,
        body: {'username': _username},
      );

      final options = Map<String, dynamic>.from(
        optionsResponse['options'] as Map<String, dynamic>,
      );

      final credentialResponse = await createPasskeyCredential(options);

      final verifyResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/register/verify',
        authenticated: true,
        body: {'response': credentialResponse},
      );

      if (!context.mounted) return;
      final passkeyId = verifyResponse['passkeyId'] ?? 'new passkey';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Passkey registered: $passkeyId')));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
    }
  }

  void toggleAuthMode() {
    if (!signupEnabled) {
      loginOutputs[2] = true;
      loginOutputs[1] = 'Signup is currently disabled.';
      return;
    }

    loginOutputs[2] = !(loginOutputs[2] as bool);
    loginOutputs[1] = '';
    if (loginOutputs[2] == true) {
      loginInputs[2] = '';
      loginInputs[3] = '';
      loginInputs[4] = '';
      signupRole = 'student';
    }
  }

  void signOut() {
    _authToken = null;
    _username = null;
    _email = null;
    _avatarUrl = null;
    _teamNumber = null;
    _role = 'scouter';
    _selectedEventKey = null;

    appSettings[2] = false;
    appSettings[3] = false;
    loginOutputs[1] = '';
    loginOutputs[2] = true;
    loginInputs = ['', '', '', '', ''];
    signupRole = 'student';

    studentsData = [];
    studentsList = [];
    datasheets = [];
    selectedDatasheetId = null;
    scoutingDataList = [];
    matchDataList = [];

    teamsList = [
      [0, 0, 0, 0, 0, 0],
    ];

    unawaited(_clearSession());
  }

  Future<void> fetchMainEventsFromTba({int? year}) async {
    final usedYear = year ?? DateTime.now().year;
    final selectedTeam = isAuthenticated && (_teamNumber ?? '').isNotEmpty
        ? _teamNumber!
        : '3635';

    final response = await _request(
      method: 'GET',
      path: '/tba/team/$selectedTeam/events/$usedYear',
    );

    final events = response['events'] as List<dynamic>? ?? [];

    _eventNameToKey.clear();
    final loadedNames = <String>[];

    for (final event in events) {
      if (event is! Map<String, dynamic>) continue;
      final key = '${event['key'] ?? ''}'.trim();
      final name = '${event['name'] ?? ''}'.trim();
      if (key.isEmpty || name.isEmpty) continue;

      _eventNameToKey[name] = key;
      loadedNames.add(name);
    }

    if (loadedNames.isEmpty) {
      eventsList = ['No Events Available'];
      teamsList = [
        [0, 0, 0, 0, 0, 0],
      ];
      _selectedEventKey = null;
      return;
    }

    eventsList = loadedNames;
    _selectedEventKey ??= _eventNameToKey[loadedNames.first];

    if (_selectedEventKey != null) {
      await _fetchMatchesForEventKey(_selectedEventKey!);
    }
  }

  Future<void> updateMatches(String eventName) async {
    final eventKey = _eventNameToKey[eventName];
    if (eventKey == null || eventKey.isEmpty) {
      return;
    }

    _selectedEventKey = eventKey;
    await _fetchMatchesForEventKey(eventKey);
  }

  Future<void> fetchMatchesByEventKey(String eventKey) async {
    final normalized = eventKey.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Event key is required.');
    }

    _selectedEventKey = normalized;
    await _fetchMatchesForEventKey(normalized);
  }

  Future<void> _fetchMatchesForEventKey(String eventKey) async {
    final response = await _request(
      method: 'GET',
      path: '/tba/event/$eventKey/matches',
    );

    final matches = response['matches'] as List<dynamic>? ?? [];
    if (matches.isEmpty) {
      teamsList = [
        [0, 0, 0, 0, 0, 0],
      ];
      return;
    }

    final loadedTeams = <List<int>>[];

    for (final match in matches) {
      if (match is! Map<String, dynamic>) continue;
      final teams = match['teams'] as List<dynamic>? ?? [];

      final parsedTeams = teams
          .map((team) => int.tryParse('$team') ?? 0)
          .take(6)
          .toList();
      while (parsedTeams.length < 6) {
        parsedTeams.add(0);
      }

      loadedTeams.add(parsedTeams);
    }

    teamsList = loadedTeams.isEmpty
        ? [
            [0, 0, 0, 0, 0, 0],
          ]
        : loadedTeams;
  }

  Future<void> fetchPitTemplate() async {
    final query = <String, String>{};
    if ((_teamNumber ?? '').isNotEmpty) {
      query['teamNumber'] = _teamNumber!;
    }

    final response = await _request(
      method: 'GET',
      path: '/pit-template',
      query: query.isEmpty ? null : query,
    );

    final template = response['template'] as Map<String, dynamic>? ?? {};
    pitTemplateFields = (template['fields'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> savePitTemplate(List<Map<String, dynamic>> fields) async {
    if (!canManagePitTemplate) {
      throw Exception('Insufficient permissions to update pit template.');
    }

    await _request(
      method: 'PUT',
      path: '/pit-template',
      authenticated: true,
      body: {'teamNumber': _teamNumber, 'fields': fields},
    );

    pitTemplateFields = fields;
  }

  Future<bool> submitPitData(BuildContext context) async {
    if (pitInputs[0].isEmpty || pitInputs[1].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Team Number and Name')),
      );
      return false;
    }

    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before submitting data.')),
      );
      return false;
    }

    try {
      final response = await _request(
        method: 'POST',
        path: '/pit-entries',
        authenticated: true,
        body: {
          'eventId': _selectedEventKey,
          'datasheetId': selectedDatasheetId,
          'teamNumber': pitInputs[0],
          'teamName': pitInputs[1],
          'humanPlayerConfidence': pitInputs[2],
          'driveTrain': pitInputs[3],
          'mainScoringPotential': pitInputs[4],
          'pointsInAutonomous': pitInputs[5],
          'teleOperatedCapabilities': pitInputs[6],
          'customResponses': customPitResponses,
        },
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        scoutingDataList.insert(0, _normalizePitEntry(entry));
      }

      pitInputs = List.filled(7, '');
      customPitResponses = {};

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data submitted to backend.')),
        );
      }

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  Future<bool> updatePitEntry(
    BuildContext context, {
    required String id,
    required Map<String, String> updated,
  }) async {
    if (!canMakeRevisions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to edit entries.')),
      );
      return false;
    }

    try {
      final response = await _request(
        method: 'PUT',
        path: '/pit-entries/$id',
        authenticated: true,
        body: {
          'eventId': _selectedEventKey,
          'datasheetId': selectedDatasheetId,
          'teamNumber': updated['teamNumber'] ?? '',
          'teamName': updated['teamName'] ?? '',
          'humanPlayerConfidence': updated['humanPlayerConfidence'] ?? '',
          'driveTrain': updated['driveTrain'] ?? '',
          'mainScoringPotential': updated['mainScoringPotential'] ?? '',
          'pointsInAutonomous': updated['pointsInAutonomous'] ?? '',
          'teleOperatedCapabilities': updated['teleOperatedCapabilities'] ?? '',
        },
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        final normalized = _normalizePitEntry(entry);
        final index = scoutingDataList.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          scoutingDataList[index] = normalized;
        } else {
          scoutingDataList.insert(0, normalized);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry revised.')));
      }

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPitEntryVersions(String id) async {
    final response = await _request(
      method: 'GET',
      path: '/pit-entries/$id/versions',
    );
    return (response['versions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<bool> restorePitEntryVersion(
    BuildContext context, {
    required String id,
    required int version,
  }) async {
    if (!canRestoreVersions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team Manager role required.')),
      );
      return false;
    }

    try {
      final response = await _request(
        method: 'POST',
        path: '/pit-entries/$id/restore',
        authenticated: true,
        body: {'version': version},
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        final normalized = _normalizePitEntry(entry);
        final index = scoutingDataList.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          scoutingDataList[index] = normalized;
        } else {
          scoutingDataList.insert(0, normalized);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restored version $version.')));
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  Future<void> fetchDatasheets() async {
    if (!isAuthenticated) {
      datasheets = [];
      selectedDatasheetId = null;
      return;
    }

    final query = <String, String>{
      if ((_teamNumber ?? '').isNotEmpty) 'teamNumber': _teamNumber!,
    };

    final response = await _request(
      method: 'GET',
      path: '/datasheets',
      query: query,
      authenticated: true,
    );

    datasheets = (response['datasheets'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (datasheets.isNotEmpty && selectedDatasheetId == null) {
      selectedDatasheetId = '${datasheets.first['id']}';
    }
  }

  Future<void> createDatasheet({
    required int season,
    required String name,
  }) async {
    if (!canCreateDatasheet) {
      throw Exception('Team Manager role required to create datasheets.');
    }

    final response = await _request(
      method: 'POST',
      path: '/datasheets',
      authenticated: true,
      body: {'season': season, 'name': name},
    );

    final created = response['datasheet'] as Map<String, dynamic>?;
    if (created != null) {
      datasheets.insert(0, created);
      selectedDatasheetId = '${created['id']}';
    }
  }

  Future<Map<String, String>> exportSelectedDatasheetCsv() async {
    if (!canExportData) {
      throw Exception(
        'Scout Manager or Team Manager role required for CSV export.',
      );
    }

    if ((selectedDatasheetId ?? '').isEmpty) {
      throw Exception('Select a datasheet before exporting.');
    }

    final response = await _request(
      method: 'GET',
      path: '/datasheets/$selectedDatasheetId/export',
      authenticated: true,
    );

    final export = response['export'] as Map<String, dynamic>? ?? {};
    return {
      'pitCsv': '${export['pitCsv'] ?? ''}',
      'matchCsv': '${export['matchCsv'] ?? ''}',
    };
  }

  Future<bool> downloadCsvFiles({
    required String pitCsv,
    required String matchCsv,
  }) async {
    final seasonTag = (datasheets).firstWhere(
      (sheet) => '${sheet['id']}' == (selectedDatasheetId ?? ''),
      orElse: () => const <String, dynamic>{},
    );
    final season = '${seasonTag['season'] ?? DateTime.now().year}';

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pitOk = await download_client.downloadTextFile(
      filename: 'spectator_pit_${season}_$timestamp.csv',
      content: pitCsv,
      mimeType: 'text/csv',
    );
    final matchOk = await download_client.downloadTextFile(
      filename: 'spectator_match_${season}_$timestamp.csv',
      content: matchCsv,
      mimeType: 'text/csv',
    );

    return pitOk && matchOk;
  }

  Future<void> fetchPitEntries({String? teamNumber, String? teamName}) async {
    final query = <String, String>{
      if (teamNumber != null && teamNumber.trim().isNotEmpty)
        'teamNumber': teamNumber.trim(),
      if (teamName != null && teamName.trim().isNotEmpty)
        'teamName': teamName.trim(),
      if ((selectedDatasheetId ?? '').isNotEmpty)
        'datasheetId': selectedDatasheetId!,
    };

    final response = await _request(
      method: 'GET',
      path: '/pit-entries',
      query: query.isEmpty ? null : query,
    );

    final entries = response['entries'] as List<dynamic>? ?? [];

    scoutingDataList = entries
        .whereType<Map<String, dynamic>>()
        .map(_normalizePitEntry)
        .toList();
  }

  Future<void> fetchMatchEntries({
    String? teamNumber,
    String? matchNumber,
  }) async {
    final query = <String, String>{
      if (teamNumber != null && teamNumber.trim().isNotEmpty)
        'teamNumber': teamNumber.trim(),
      if (matchNumber != null && matchNumber.trim().isNotEmpty)
        'matchNumber': matchNumber.trim(),
      if ((selectedDatasheetId ?? '').isNotEmpty)
        'datasheetId': selectedDatasheetId!,
    };

    final response = await _request(
      method: 'GET',
      path: '/match-entries',
      query: query.isEmpty ? null : query,
    );

    final entries = response['entries'] as List<dynamic>? ?? [];
    matchDataList = entries
        .whereType<Map<String, dynamic>>()
        .map(_normalizeMatchEntry)
        .toList();
  }

  List<Map<String, String>> getFilteredData() {
    final query = dataSearchInput[0].trim().toLowerCase();
    if (query.isEmpty) {
      return scoutingDataList;
    }

    return scoutingDataList.where((entry) {
      final teamNumber = (entry['teamNumber'] ?? '').toLowerCase();
      final teamName = (entry['teamName'] ?? '').toLowerCase();
      return teamNumber.contains(query) || teamName.contains(query);
    }).toList();
  }

  List<Map<String, String>> getFilteredMatchData() {
    final query = dataSearchInput[0].trim().toLowerCase();
    if (query.isEmpty) {
      return matchDataList;
    }

    return matchDataList.where((entry) {
      final teamNumber = (entry['teamNumber'] ?? '').toLowerCase();
      final matchNumber = (entry['matchNumber'] ?? '').toLowerCase();
      return teamNumber.contains(query) || matchNumber.contains(query);
    }).toList();
  }

  Future<void> fetchStudents() async {
    if (!isAuthenticated) {
      studentsData = [];
      studentsList = [];
      return;
    }

    final response = await _request(
      method: 'GET',
      path: '/students',
      authenticated: true,
    );

    studentsData = (response['students'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    studentsList = studentsData
        .map((entry) => '${entry['name'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>> inviteStudent({
    required String name,
    String? username,
    String? email,
  }) async {
    if (!canInviteStudents) {
      throw Exception('Only Team Managers can invite students.');
    }

    final response = await _request(
      method: 'POST',
      path: '/students/invite',
      authenticated: true,
      body: {
        'name': name,
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    await fetchStudents();

    return {
      'inviteCode': '${response['inviteCode'] ?? ''}',
      'studentName': '${response['student']?['name'] ?? name}',
      'studentId': '${response['student']?['id'] ?? ''}',
    };
  }

  Future<void> removeStudent(String studentId) async {
    if (!canInviteStudents) {
      throw Exception('Only Team Managers can remove students.');
    }

    await _request(
      method: 'DELETE',
      path: '/students/$studentId',
      authenticated: true,
    );

    await fetchStudents();
  }

  Future<void> assignStudentTask({
    required String studentId,
    required String title,
    String? description,
  }) async {
    if (!canAssignStudentTasks) {
      throw Exception('Only managers can assign tasks.');
    }

    await _request(
      method: 'POST',
      path: '/students/tasks',
      authenticated: true,
      body: {
        'studentId': studentId,
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

    await fetchStudents();
  }

  Future<void> markStudentTaskStatus({
    required String taskId,
    required String status,
  }) async {
    if (!canMarkStudentTasks) {
      throw Exception('Login required to update tasks.');
    }

    await _request(
      method: 'PATCH',
      path: '/students/tasks/$taskId/status',
      authenticated: true,
      body: {'status': status},
    );

    await fetchStudents();
  }

  Future<void> fetchAboutProfile({String? teamNumber}) async {
    final query = <String, String>{
      if ((teamNumber ?? '').trim().isNotEmpty)
        'teamNumber': teamNumber!.trim(),
      if ((teamNumber == null || teamNumber.isEmpty) &&
          (_teamNumber ?? '').isNotEmpty)
        'teamNumber': _teamNumber!,
    };

    final response = await _request(
      method: 'GET',
      path: '/about/profile',
      query: query.isEmpty ? null : query,
    );

    aboutProfile = response['profile'] as Map<String, dynamic>? ?? {};
  }

  Future<void> saveAboutProfile({
    required String title,
    required String mission,
    List<String>? sponsors,
    String? website,
  }) async {
    if (!canEditAbout) {
      throw Exception('Only Team Managers can edit About content.');
    }

    final response = await _request(
      method: 'PUT',
      path: '/about/profile',
      authenticated: true,
      body: {
        'teamNumber': _teamNumber,
        'title': title,
        'mission': mission,
        'sponsors': sponsors ?? const [],
        'website': website ?? '',
      },
    );

    aboutProfile = response['profile'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, String>> fetchTeamInfoFromBlueAlliance(
    String teamNumber,
  ) async {
    final normalized = teamNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      throw Exception('Enter a numeric team number.');
    }

    final response = await _request(
      method: 'GET',
      path: '/tba/team/$normalized',
    );

    final team = response['team'] as Map<String, dynamic>? ?? {};

    final translationResponse = await _request(
      method: 'GET',
      path: '/tba/translate',
      query: {
        'districtKey': '${team['districtKey'] ?? ''}',
        'teamKey': '${team['key'] ?? ''}',
      },
    );

    final translation =
        translationResponse['translation'] as Map<String, dynamic>? ?? {};

    return {
      'teamNumber': '${team['teamNumber'] ?? normalized}',
      'key': '${team['key'] ?? ''}',
      'nickname': '${team['nickname'] ?? ''}',
      'name': '${team['name'] ?? ''}',
      'schoolName': '${team['schoolName'] ?? ''}',
      'city': '${team['city'] ?? ''}',
      'state': '${team['state'] ?? ''}',
      'country': '${team['country'] ?? ''}',
      'website': '${team['website'] ?? ''}',
      'rookieYear': '${team['rookieYear'] ?? ''}',
      'logoUrl': '${team['logoUrl'] ?? ''}',
      'districtKey': '${team['districtKey'] ?? ''}',
      'districtLabel': '${translation['districtLabel'] ?? ''}',
      'teamLabel': '${translation['teamLabel'] ?? ''}',
    };
  }

  Future<bool> updateMatchEntry(
    BuildContext context, {
    required String id,
    required Map<String, dynamic> updated,
  }) async {
    if (!canMakeRevisions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to edit entries.')),
      );
      return false;
    }

    try {
      final response = await _request(
        method: 'PUT',
        path: '/match-entries/$id',
        authenticated: true,
        body: {
          'eventId': _selectedEventKey,
          'datasheetId': selectedDatasheetId,
          'matchNumber': '${updated['matchNumber'] ?? ''}',
          'teamNumber': '${updated['teamNumber'] ?? ''}',
          'allianceColor': '${updated['allianceColor'] ?? 'Red'}',
          'fireRate': updated['fireRate'] ?? 0,
          'shotsAttempted': updated['shotsAttempted'] ?? 0,
          'accuracy': updated['accuracy'] ?? 0,
          'calculatedPoints': updated['calculatedPoints'] ?? 0,
          'autoClimb': updated['autoClimb'] ?? false,
          'climbLevel': '${updated['climbLevel'] ?? 'None'}',
          'scoutedAt':
              '${updated['scoutedAt'] ?? DateTime.now().toIso8601String()}',
        },
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        final normalized = _normalizeMatchEntry(entry);
        final index = matchDataList.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          matchDataList[index] = normalized;
        } else {
          matchDataList.insert(0, normalized);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Match entry revised.')));
      }

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMatchEntryVersions(String id) async {
    final response = await _request(
      method: 'GET',
      path: '/match-entries/$id/versions',
    );
    return (response['versions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<bool> restoreMatchEntryVersion(
    BuildContext context, {
    required String id,
    required int version,
  }) async {
    if (!canRestoreVersions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team Manager role required.')),
      );
      return false;
    }

    try {
      final response = await _request(
        method: 'POST',
        path: '/match-entries/$id/restore',
        authenticated: true,
        body: {'version': version},
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        final normalized = _normalizeMatchEntry(entry);
        final index = matchDataList.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          matchDataList[index] = normalized;
        } else {
          matchDataList.insert(0, normalized);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restored version $version.')));
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  int calculatePoints(int shots, double accuracy) {
    final madeShots = (shots * accuracy).round();
    return madeShots;
  }

  Future<bool> submitMatchData(List<dynamic> data, BuildContext context) async {
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before submitting data.')),
      );
      return false;
    }

    try {
      final fireRate = double.tryParse('${data[3]}') ?? 0;

      final response = await _request(
        method: 'POST',
        path: '/match-entries',
        authenticated: true,
        body: {
          'eventId': _selectedEventKey,
          'datasheetId': selectedDatasheetId,
          'matchNumber': '${data[0]}',
          'teamNumber': '${data[1]}',
          'allianceColor': '${data[2]}',
          'fireRate': fireRate,
          'shotsAttempted': data[4],
          'accuracy': data[5],
          'calculatedPoints': data[6],
          'autoClimb': data[7],
          'climbLevel': '${data[8]}',
          'scoutedAt': '${data[9]}',
        },
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        matchDataList.insert(0, _normalizeMatchEntry(entry));
      }
      matchScoutingData.add(List<dynamic>.from(data));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match data submitted to backend.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorText(error))));
      }
      return false;
    }
  }

  void _applyAuthenticatedState(Map<String, dynamic> response) {
    final token = response['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Authentication token missing from server response.');
    }

    final user = response['user'] as Map<String, dynamic>? ?? {};
    _authToken = token;
    _username = user['username']?.toString();
    _email = user['email']?.toString();
    _avatarUrl = user['avatarUrl']?.toString();
    _teamNumber = user['teamNumber']?.toString();
    _role = (user['role']?.toString() ?? 'scouter').trim();
    appSettings[2] = isTeamManager || isScoutManager;
    appSettings[3] = true;
    unawaited(_persistSession());
  }

  Map<String, String> _normalizePitEntry(Map<String, dynamic> entry) {
    final versions = entry['versions'];
    final versionCount = versions is List ? versions.length : 0;

    return {
      'id': '${entry['id'] ?? ''}',
      'teamNumber': '${entry['teamNumber'] ?? ''}',
      'teamName': '${entry['teamName'] ?? ''}',
      'humanPlayerConfidence': '${entry['humanPlayerConfidence'] ?? ''}',
      'driveTrain': '${entry['driveTrain'] ?? ''}',
      'mainScoringPotential': '${entry['mainScoringPotential'] ?? ''}',
      'pointsInAutonomous': '${entry['pointsInAutonomous'] ?? ''}',
      'teleOperatedCapabilities': '${entry['teleOperatedCapabilities'] ?? ''}',
      'customResponses': jsonEncode(entry['customResponses'] ?? {}),
      'datasheetId': '${entry['datasheetId'] ?? ''}',
      'createdByUsername': '${entry['createdByUsername'] ?? ''}',
      'createdAt': '${entry['createdAt'] ?? ''}',
      'updatedAt': '${entry['updatedAt'] ?? ''}',
      'version': '${entry['version'] ?? 1}',
      'versionCount': '$versionCount',
    };
  }

  Map<String, String> _normalizeMatchEntry(Map<String, dynamic> entry) {
    final versions = entry['versions'];
    final versionCount = versions is List ? versions.length : 0;

    return {
      'id': '${entry['id'] ?? ''}',
      'eventId': '${entry['eventId'] ?? ''}',
      'datasheetId': '${entry['datasheetId'] ?? ''}',
      'matchNumber': '${entry['matchNumber'] ?? ''}',
      'teamNumber': '${entry['teamNumber'] ?? ''}',
      'allianceColor': '${entry['allianceColor'] ?? ''}',
      'fireRate': '${entry['fireRate'] ?? 0}',
      'shotsAttempted': '${entry['shotsAttempted'] ?? 0}',
      'accuracy': '${entry['accuracy'] ?? 0}',
      'calculatedPoints': '${entry['calculatedPoints'] ?? 0}',
      'autoClimb': '${entry['autoClimb'] ?? false}',
      'climbLevel': '${entry['climbLevel'] ?? 'None'}',
      'scoutedAt': '${entry['scoutedAt'] ?? ''}',
      'createdByUsername': '${entry['createdByUsername'] ?? ''}',
      'createdAt': '${entry['createdAt'] ?? ''}',
      'updatedAt': '${entry['updatedAt'] ?? ''}',
      'version': '${entry['version'] ?? 1}',
      'versionCount': '$versionCount',
    };
  }
}
