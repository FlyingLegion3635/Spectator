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

  late final Future<void> ready;

  Functions._internal() {
    ready = _bootstrap();
  }

  static String get _apiBaseUrl {
    // Set via: flutter run --dart-define=API_BASE_URL=https://example.com/api/v1
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;

    // Platform fallbacks (development defaults)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  String? _authToken;
  String? _selectedEventKey;
  String _matchesStatusMessage = '';
  String? _username;
  String? _email;
  String? _avatarUrl;
  String? _teamNumber;
  String _role = 'scouter';
  String _status = 'active';

  bool _bootstrapped = false;
  final Map<String, String> _eventNameToKey = {};
  static const _sessionTokenKey = 'spectator.auth.token';
  static const _sessionUsernameKey = 'spectator.auth.username';
  static const _sessionTeamNumberKey = 'spectator.auth.teamNumber';
  static const _sessionRoleKey = 'spectator.auth.role';
  static const _sessionEmailKey = 'spectator.auth.email';
  static const _sessionAvatarKey = 'spectator.auth.avatar';
  static const _sessionStatusKey = 'spectator.auth.status';
  static const _offlinePitQueueKey = 'spectator.offline.pitQueue';
  static const _offlineMatchQueueKey = 'spectator.offline.matchQueue';
  static const _cacheEventsListKey = 'spectator.cache.eventsList';
  static const _cacheEventNameToKeyKey = 'spectator.cache.eventNameToKey';
  static const _cacheTeamsListKey = 'spectator.cache.teamsList';
  static const _cacheSelectedEventKey = 'spectator.cache.selectedEventKey';
  static const _cachePitTemplateKey = 'spectator.cache.pitTemplate';
  static const _cacheDatasheetsKey = 'spectator.cache.datasheets';
  static const _cacheAboutProfileKey = 'spectator.cache.aboutProfile';
  static const _cacheMatchesStatusKey = 'spectator.cache.matchesStatus';
  static const _cachePitEntriesKey = 'spectator.cache.pitEntries';
  static const _cacheMatchEntriesKey = 'spectator.cache.matchEntries';
  static const _cacheTeamNamesKey = 'spectator.cache.teamNames';

  bool signupEnabled = true;
  bool passkeysEnabled = false;

  bool get isAuthenticated => _authToken != null;
  String? get currentUsername => _username;
  String? get currentEmail => _email;
  String get avatarUrl => _avatarUrl ?? '';
  String? get teamNumber => _teamNumber;
  String get role => _role;
  String get selectedEventKey => _selectedEventKey ?? '';
  String get matchesStatusMessage => _matchesStatusMessage;

  String get selectedEventName {
    final key = _selectedEventKey;
    if (key == null || key.isEmpty) {
      return '';
    }

    for (final entry in _eventNameToKey.entries) {
      if (entry.value == key) {
        return entry.key;
      }
    }

    return key.toUpperCase();
  }

  bool get isTeamManager => _role == 'team_manager';
  bool get isScoutManager => _role == 'scout_manager';
  bool get isScouter => _role == 'scouter';
  bool get isPending => _status == 'pending';
  bool get isApproved => !isPending;
  String get userStatus => _status;

  bool get canManagePitTemplate => isApproved && (isTeamManager || isScoutManager);
  bool get canEditAbout => isApproved && isTeamManager;
  bool get canInviteMembers => isApproved && (isTeamManager || isScoutManager);
  bool get canInviteStudents => canInviteMembers; // backwards compat
  bool get canAssignStudentTasks => isApproved && (isTeamManager || isScoutManager);
  bool get canApproveMembers => isApproved && (isTeamManager || isScoutManager);
  bool get canMarkStudentTasks => isAuthenticated && isApproved;
  bool get canCreateDatasheet => isApproved && isTeamManager;
  bool get canRestoreVersions => isApproved && isTeamManager;
  bool get canExportData => isApproved && (isTeamManager || isScoutManager);

  /// Set after submit calls — true when data was queued offline instead of sent.
  bool lastSubmitWasOffline = false;
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

  /// Cached team number → nickname for offline autofill.
  final Map<String, String> cachedTeamNames = {};

  Map<String, dynamic> aboutProfile = {};

  List<List<dynamic>> matchScoutingData = [];

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    try {
      await _restoreSession();
      await _restoreCache();
      await refreshAuthConfig();

      if (isAuthenticated) {
        await refreshCurrentUser();
      }

      await fetchMainEventsFromTba();
      await fetchPitEntries();
      await fetchMatchEntries();
      await fetchAboutProfile();
    } catch (_) {
      // Cache data already loaded — screens show stale data rather than empty.
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, _authToken ?? '');
    await prefs.setString(_sessionUsernameKey, _username ?? '');
    await prefs.setString(_sessionTeamNumberKey, _teamNumber ?? '');
    await prefs.setString(_sessionRoleKey, _role);
    await prefs.setString(_sessionStatusKey, _status);
    await prefs.setString(_sessionEmailKey, _email ?? '');
    await prefs.setString(_sessionAvatarKey, _avatarUrl ?? '');
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionUsernameKey);
    await prefs.remove(_sessionTeamNumberKey);
    await prefs.remove(_sessionRoleKey);
    await prefs.remove(_sessionStatusKey);
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
    _status = (prefs.getString(_sessionStatusKey) ?? 'active').trim();
    _email = (prefs.getString(_sessionEmailKey) ?? '').trim();
    _avatarUrl = (prefs.getString(_sessionAvatarKey) ?? '').trim();
    appSettings[2] = isTeamManager || isScoutManager;
    appSettings[3] = true;
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();

    final rawEvents = prefs.getString(_cacheEventsListKey);
    if (rawEvents != null) {
      try {
        final decoded = jsonDecode(rawEvents);
        if (decoded is List) {
          eventsList = decoded.map((e) => '$e').toList();
        }
      } catch (_) {}
    }

    final rawMap = prefs.getString(_cacheEventNameToKeyKey);
    if (rawMap != null) {
      try {
        final decoded = jsonDecode(rawMap);
        if (decoded is Map) {
          _eventNameToKey.clear();
          decoded.forEach((k, v) => _eventNameToKey['$k'] = '$v');
        }
      } catch (_) {}
    }

    final rawSelectedEvent = prefs.getString(_cacheSelectedEventKey) ?? '';
    if (rawSelectedEvent.isNotEmpty) {
      _selectedEventKey = rawSelectedEvent;
    }

    _matchesStatusMessage = prefs.getString(_cacheMatchesStatusKey) ?? '';

    final rawTeams = prefs.getString(_cacheTeamsListKey);
    if (rawTeams != null) {
      try {
        final decoded = jsonDecode(rawTeams);
        if (decoded is List) {
          teamsList = decoded
              .whereType<List>()
              .map((row) => row.map((e) => (e as num).toInt()).toList())
              .toList();
        }
      } catch (_) {}
    }

    final rawTemplate = prefs.getString(_cachePitTemplateKey);
    if (rawTemplate != null) {
      try {
        final decoded = jsonDecode(rawTemplate);
        if (decoded is List) {
          pitTemplateFields =
              decoded.whereType<Map<String, dynamic>>().toList();
        }
      } catch (_) {}
    }

    final rawSheets = prefs.getString(_cacheDatasheetsKey);
    if (rawSheets != null) {
      try {
        final decoded = jsonDecode(rawSheets);
        if (decoded is List) {
          datasheets = decoded.whereType<Map<String, dynamic>>().toList();
          if (datasheets.isNotEmpty && selectedDatasheetId == null) {
            selectedDatasheetId = '${datasheets.first['id']}';
          }
        }
      } catch (_) {}
    }

    final rawAbout = prefs.getString(_cacheAboutProfileKey);
    if (rawAbout != null) {
      try {
        final decoded = jsonDecode(rawAbout);
        if (decoded is Map<String, dynamic>) {
          aboutProfile = decoded;
        }
      } catch (_) {}
    }

    final rawPitEntries = prefs.getString(_cachePitEntriesKey);
    if (rawPitEntries != null) {
      try {
        final decoded = jsonDecode(rawPitEntries);
        if (decoded is List) {
          scoutingDataList = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => e.map((k, v) => MapEntry(k, '$v')))
              .toList();
        }
      } catch (_) {}
    }

    final rawMatchEntries = prefs.getString(_cacheMatchEntriesKey);
    if (rawMatchEntries != null) {
      try {
        final decoded = jsonDecode(rawMatchEntries);
        if (decoded is List) {
          matchDataList = decoded
              .whereType<Map<String, dynamic>>()
              .map((e) => e.map((k, v) => MapEntry(k, '$v')))
              .toList();
        }
      } catch (_) {}
    }

    final rawTeamNames = prefs.getString(_cacheTeamNamesKey);
    if (rawTeamNames != null) {
      try {
        final decoded = jsonDecode(rawTeamNames);
        if (decoded is Map) {
          cachedTeamNames.clear();
          decoded.forEach((k, v) => cachedTeamNames['$k'] = '$v');
        }
      } catch (_) {}
    }
  }

  Future<void> _persistEventsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheEventsListKey, jsonEncode(eventsList));
    await prefs.setString(
      _cacheEventNameToKeyKey,
      jsonEncode(_eventNameToKey),
    );
    await prefs.setString(_cacheSelectedEventKey, _selectedEventKey ?? '');
    await prefs.setString(_cacheTeamsListKey, jsonEncode(teamsList));
    await prefs.setString(_cacheMatchesStatusKey, _matchesStatusMessage);
  }

  Future<void> _persistEntriesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cachePitEntriesKey,
      jsonEncode(scoutingDataList),
    );
    await prefs.setString(
      _cacheMatchEntriesKey,
      jsonEncode(matchDataList),
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _cacheEventsListKey,
      _cacheEventNameToKeyKey,
      _cacheTeamsListKey,
      _cacheSelectedEventKey,
      _cachePitTemplateKey,
      _cacheDatasheetsKey,
      _cacheAboutProfileKey,
      _cacheMatchesStatusKey,
      _cachePitEntriesKey,
      _cacheMatchEntriesKey,
      _cacheTeamNamesKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> refreshCurrentUser() async {
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
      _status = '${user['status'] ?? _status}'.trim();
      _email = '${user['email'] ?? _email ?? ''}'.trim();
      _avatarUrl = '${user['avatarUrl'] ?? _avatarUrl ?? ''}'.trim();
      appSettings[2] = isTeamManager || isScoutManager;
      appSettings[3] = true;
      await _persistSession();
    } catch (_) {
      // Keep locally persisted session while offline/unreachable.
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
      final details = error['details'];

      if (details is Map<String, dynamic>) {
        final fieldErrors = details['fieldErrors'];
        if (fieldErrors is Map<String, dynamic> && fieldErrors.isNotEmpty) {
          final parts = fieldErrors.entries.map((e) {
            final msgs = e.value;
            final first = msgs is List && msgs.isNotEmpty ? '${msgs.first}' : '';
            return '${e.key}: $first';
          }).join(', ');
          if (message is String && message.isNotEmpty) {
            return '$message — $parts';
          }
          return parts;
        }
      }

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

  bool _shouldStoreOffline(Object error) {
    final lowered = _errorText(error).toLowerCase();
    return lowered.contains('failed host lookup') ||
        lowered.contains('socketexception') ||
        lowered.contains('xmlhttprequest') ||
        lowered.contains('failed to fetch') ||
        lowered.contains('network') ||
        lowered.contains('request failed. check backend url');
  }

  Future<List<Map<String, dynamic>>> _readOfflineQueue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(key) ?? const [];
    return rawItems
        .map((item) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
            return <String, dynamic>{};
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _writeOfflineQueue(
    String key,
    List<Map<String, dynamic>> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = entries.map((entry) => jsonEncode(entry)).toList();
    await prefs.setStringList(key, encoded);
  }

  /// Returns a signature for dedup: payload without timestamps/queue metadata.
  String _offlineEntrySignature(Map<String, dynamic> entry) {
    final cleaned = Map<String, dynamic>.from(entry)
      ..remove('queuedAt')
      ..remove('offlineOnly')
      ..remove('scoutedAt');
    final keys = cleaned.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in keys) {
      buf.write('$k=${cleaned[k]};');
    }
    return buf.toString();
  }

  Future<void> _enqueueOfflineEntry(
    String key,
    Map<String, dynamic> payload,
  ) async {
    final queue = await _readOfflineQueue(key);

    // Prevent duplicate entries with identical content.
    final newSig = _offlineEntrySignature(payload);
    final isDuplicate = queue.any((e) => _offlineEntrySignature(e) == newSig);
    if (isDuplicate) return;

    queue.add({...payload, 'queuedAt': DateTime.now().toIso8601String()});
    if (queue.length > 300) {
      queue.removeRange(0, queue.length - 300);
    }
    await _writeOfflineQueue(key, queue);
  }

  Future<int> getOfflinePitQueueCount() async {
    final queue = await _readOfflineQueue(_offlinePitQueueKey);
    return queue.length;
  }

  Future<int> getOfflineMatchQueueCount() async {
    final queue = await _readOfflineQueue(_offlineMatchQueueKey);
    return queue.length;
  }

  Future<int> syncOfflinePitData() async {
    if (!isAuthenticated) {
      throw Exception('Login required to sync offline pit data.');
    }

    final queued = await _readOfflineQueue(_offlinePitQueueKey);
    if (queued.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var sent = 0;

    for (final payload in queued) {
      final cleaned = Map<String, dynamic>.from(payload)
        ..remove('queuedAt')
        ..remove('offlineOnly');
      try {
        final response = await _request(
          method: 'POST',
          path: '/pit-entries',
          authenticated: true,
          body: cleaned,
        );
        final entry = response['entry'] as Map<String, dynamic>?;
        if (entry != null) {
          scoutingDataList.insert(0, _normalizePitEntry(entry));
        }
        sent++;
      } catch (_) {
        remaining.add(payload);
      }
    }

    await _writeOfflineQueue(_offlinePitQueueKey, remaining);
    return sent;
  }

  Future<int> syncOfflineMatchData() async {
    if (!isAuthenticated) {
      throw Exception('Login required to sync offline match data.');
    }

    final queued = await _readOfflineQueue(_offlineMatchQueueKey);
    if (queued.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    var sent = 0;

    for (final payload in queued) {
      final cleaned = Map<String, dynamic>.from(payload)
        ..remove('queuedAt')
        ..remove('offlineOnly');
      try {
        final response = await _request(
          method: 'POST',
          path: '/match-entries',
          authenticated: true,
          body: cleaned,
        );
        final entry = response['entry'] as Map<String, dynamic>?;
        if (entry != null) {
          matchDataList.insert(0, _normalizeMatchEntry(entry));
        }
        sent++;
      } catch (_) {
        remaining.add(payload);
      }
    }

    await _writeOfflineQueue(_offlineMatchQueueKey, remaining);
    return sent;
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
          signupInviteCode.length != 6) {
        throw Exception('Signup requires a 6-digit team invite key.');
      }

      final loginTeamNumber = loginInputs[2].trim();

      if (isLoginMode && loginTeamNumber.isEmpty) {
        throw Exception('Enter username@team_number to login.');
      }

      final payload = isLoginMode
          ? {
              'username': username,
              'password': password,
              'teamNumber': loginTeamNumber,
            }
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
        fetchMembers(),
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

  Future<void> loginWithPasskey(
    BuildContext context,
    String username,
    String teamNumber,
  ) async {
    loginOutputs[0] = true;
    loginOutputs[1] = '';

    try {
      await refreshAuthConfig();

      if (!passkeysEnabled) {
        throw Exception('Passkeys are disabled on this server.');
      }

      if (username.trim().isEmpty || teamNumber.trim().isEmpty) {
        throw Exception('Enter username@team_number for passkey login.');
      }

      final optionsResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/login/options',
        body: {
          'username': username.trim(),
          'teamNumber': teamNumber.trim(),
        },
      );

      final options = Map<String, dynamic>.from(
        optionsResponse['options'] as Map<String, dynamic>,
      );

      final credentialResponse = await getPasskeyCredential(options);

      final verifyResponse = await _request(
        method: 'POST',
        path: '/auth/passkeys/login/verify',
        body: {
          'username': username.trim(),
          'teamNumber': teamNumber.trim(),
          'response': credentialResponse,
        },
      );

      _applyAuthenticatedState(verifyResponse);

      await Future.wait([
        fetchMainEventsFromTba(),
        fetchPitTemplate(),
        fetchDatasheets(),
        fetchPitEntries(),
        fetchMatchEntries(),
        fetchStudents(),
        fetchMembers(),
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
    _status = 'active';
    _selectedEventKey = null;

    appSettings[2] = false;
    appSettings[3] = false;
    loginOutputs[1] = '';
    loginOutputs[2] = true;
    loginInputs = ['', '', '', '', ''];
    signupRole = 'student';

    studentsData = [];
    studentsList = [];
    membersData = [];
    datasheets = [];
    selectedDatasheetId = null;
    scoutingDataList = [];
    matchDataList = [];

    teamsList = [
      [0, 0, 0, 0, 0, 0],
    ];

    unawaited(_clearSession());
    unawaited(_clearCache());
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
      teamsList = [];
      _matchesStatusMessage = 'No events available for the selected team/year.';
      _selectedEventKey = null;
      return;
    }

    eventsList = loadedNames;
    _matchesStatusMessage = '';
    _selectedEventKey ??= _eventNameToKey[loadedNames.first];

    if (_selectedEventKey != null) {
      await _fetchMatchesForEventKey(_selectedEventKey!);
    }
    unawaited(_persistEventsCache());
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
    final normalized = _normalizeEventKeyInput(eventKey);
    if (normalized.isEmpty) {
      throw Exception('Event key is required.');
    }

    final event = await _request(method: 'GET', path: '/tba/event/$normalized');
    final eventData = event['event'] as Map<String, dynamic>? ?? {};
    final eventName = '${eventData['name'] ?? ''}'.trim();

    await _fetchMatchesForEventKey(normalized);

    _selectedEventKey = normalized;
    _upsertLoadedEvent(normalized, eventName);
  }

  Future<void> _fetchMatchesForEventKey(String eventKey) async {
    final response = await _request(
      method: 'GET',
      path: '/tba/event/$eventKey/matches',
    );

    final matches = response['matches'] as List<dynamic>? ?? [];
    if (matches.isEmpty) {
      teamsList = [];
      _matchesStatusMessage =
          'No matches are currently published in TBA for $eventKey.';
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

    teamsList = loadedTeams.isEmpty ? [] : loadedTeams;
    _matchesStatusMessage = teamsList.isEmpty
        ? 'No match schedule could be parsed for $eventKey.'
        : '';
    unawaited(_persistEventsCache());
  }

  String _normalizeEventKeyInput(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';

    var normalized = raw.toLowerCase();

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      final segments = uri.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList();
      final eventSegmentIndex = segments.indexOf('event');
      if (eventSegmentIndex != -1 && eventSegmentIndex + 1 < segments.length) {
        normalized = segments[eventSegmentIndex + 1].toLowerCase();
      } else {
        normalized = segments.last.toLowerCase();
      }
    }

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized;
  }

  void _upsertLoadedEvent(String eventKey, String eventName) {
    final resolvedName = eventName.isEmpty ? eventKey.toUpperCase() : eventName;

    final duplicateNames = _eventNameToKey.entries
        .where((entry) => entry.value == eventKey && entry.key != resolvedName)
        .map((entry) => entry.key)
        .toList();
    for (final name in duplicateNames) {
      _eventNameToKey.remove(name);
    }

    _eventNameToKey[resolvedName] = eventKey;

    final updatedEvents = <String>[resolvedName];
    for (final existing in eventsList) {
      if (existing == 'No Events Available' || existing == resolvedName) {
        continue;
      }
      final mappedKey = _eventNameToKey[existing];
      if (mappedKey == eventKey) {
        continue;
      }
      updatedEvents.add(existing);
    }

    eventsList = updatedEvents;
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
    unawaited(SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_cachePitTemplateKey, jsonEncode(pitTemplateFields)),
    ));
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

    final payload = <String, dynamic>{
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
    };

    if (_authToken == null) {
      await _enqueueOfflineEntry(_offlinePitQueueKey, {
        ...payload,
        'offlineOnly': true,
      });
      lastSubmitWasOffline = true;
      pitInputs = List.filled(7, '');
      customPitResponses = {};
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved pit data offline.'),
            action: SnackBarAction(
              label: 'Download CSV',
              onPressed: () => downloadOfflineQueuesCsv(),
            ),
          ),
        );
      }
      return true;
    }

    try {
      final response = await _request(
        method: 'POST',
        path: '/pit-entries',
        authenticated: true,
        body: payload,
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        scoutingDataList.insert(0, _normalizePitEntry(entry));
      }

      lastSubmitWasOffline = false;
      pitInputs = List.filled(7, '');
      customPitResponses = {};

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data submitted to backend.')),
        );
      }

      return true;
    } catch (error) {
      if (_shouldStoreOffline(error)) {
        await _enqueueOfflineEntry(_offlinePitQueueKey, {
          ...payload,
          'offlineOnly': true,
        });
        lastSubmitWasOffline = true;
        pitInputs = List.filled(7, '');
        customPitResponses = {};
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Backend unreachable. Pit data saved offline.'),
              action: SnackBarAction(
                label: 'Download CSV',
                onPressed: () => downloadOfflineQueuesCsv(),
              ),
            ),
          );
        }
        return true;
      }
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
      // Parse customResponses if provided as JSON string.
      dynamic customResponses;
      final rawCustom = updated['customResponses'];
      if (rawCustom != null && rawCustom.isNotEmpty) {
        try {
          customResponses = jsonDecode(rawCustom);
        } catch (_) {
          customResponses = null;
        }
      }

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
          if (customResponses != null) 'customResponses': customResponses,
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
      authenticated: true,
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
    unawaited(SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_cacheDatasheetsKey, jsonEncode(datasheets)),
    ));
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
    Rect? sharePositionOrigin,
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
      sharePositionOrigin: sharePositionOrigin,
    );
    final matchOk = await download_client.downloadTextFile(
      filename: 'spectator_match_${season}_$timestamp.csv',
      content: matchCsv,
      mimeType: 'text/csv',
      sharePositionOrigin: sharePositionOrigin,
    );

    return pitOk && matchOk;
  }

  Future<void> fetchPitEntries({
    String? teamNumber,
    String? teamName,
    bool includeAllTeams = false,
  }) async {
    final query = <String, String>{
      if (teamNumber != null && teamNumber.trim().isNotEmpty)
        'teamNumber': teamNumber.trim(),
      if (teamName != null && teamName.trim().isNotEmpty)
        'teamName': teamName.trim(),
      if (includeAllTeams) 'scope': 'all',
      if ((selectedDatasheetId ?? '').isNotEmpty)
        'datasheetId': selectedDatasheetId!,
    };

    final response = await _request(
      method: 'GET',
      path: '/pit-entries',
      query: query.isEmpty ? null : query,
      authenticated: isAuthenticated,
    );

    final entries = response['entries'] as List<dynamic>? ?? [];

    scoutingDataList = entries
        .whereType<Map<String, dynamic>>()
        .map(_normalizePitEntry)
        .toList();
    unawaited(_persistEntriesCache());
  }

  Future<void> fetchMatchEntries({
    String? teamNumber,
    String? matchNumber,
    bool includeAllTeams = false,
  }) async {
    final query = <String, String>{
      if (teamNumber != null && teamNumber.trim().isNotEmpty)
        'teamNumber': teamNumber.trim(),
      if (matchNumber != null && matchNumber.trim().isNotEmpty)
        'matchNumber': matchNumber.trim(),
      if (includeAllTeams) 'scope': 'all',
      if ((selectedDatasheetId ?? '').isNotEmpty)
        'datasheetId': selectedDatasheetId!,
      'limit': '150',
    };

    final response = await _request(
      method: 'GET',
      path: '/match-entries',
      query: query.isEmpty ? null : query,
      authenticated: isAuthenticated,
    );

    final entries = response['entries'] as List<dynamic>? ?? [];
    matchDataList = entries
        .whereType<Map<String, dynamic>>()
        .map(_normalizeMatchEntry)
        .toList();
    unawaited(_persistEntriesCache());
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

  List<Map<String, dynamic>> membersData = [];

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

  Future<void> fetchMembers() async {
    if (!isAuthenticated) {
      membersData = [];
      return;
    }

    final response = await _request(
      method: 'GET',
      path: '/students/members',
      authenticated: true,
    );

    membersData = (response['members'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, String>> inviteStudent({
    required String name,
    String? username,
    String? email,
  }) async {
    if (!canInviteMembers) {
      throw Exception('Only managers can invite members.');
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

    await fetchMembers();

    return {
      'inviteCode': '${response['inviteCode'] ?? ''}',
      'studentName': '${response['student']?['name'] ?? name}',
      'studentId': '${response['student']?['id'] ?? ''}',
    };
  }

  Future<void> approveMember(String studentId) async {
    if (!canApproveMembers) {
      throw Exception('Only managers can approve members.');
    }

    await _request(
      method: 'PATCH',
      path: '/students/$studentId/approve',
      authenticated: true,
    );

    await fetchMembers();
  }

  Future<void> rejectMember(String studentId) async {
    if (!canApproveMembers) {
      throw Exception('Only managers can reject members.');
    }

    await _request(
      method: 'PATCH',
      path: '/students/$studentId/reject',
      authenticated: true,
    );

    await fetchMembers();
  }

  Future<void> removeStudent(String studentId) async {
    if (!canInviteMembers) {
      throw Exception('Only managers can remove members.');
    }

    await _request(
      method: 'DELETE',
      path: '/students/$studentId',
      authenticated: true,
    );

    await fetchMembers();
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

    await fetchMembers();
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

    await fetchMembers();
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
    unawaited(SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_cacheAboutProfileKey, jsonEncode(aboutProfile)),
    ));
  }

  Future<void> saveAboutProfile({
    required String title,
    required String mission,
    String? missionMarkdown,
    List<String>? sponsors,
    String? website,
    Map<String, String>? uiTheme,
    String? dataVisibility,
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
        'missionMarkdown': missionMarkdown ?? mission,
        'sponsors': sponsors ?? const [],
        'website': website ?? '',
        if (uiTheme != null) 'uiTheme': uiTheme,
        if (dataVisibility != null) 'dataVisibility': dataVisibility,
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
      authenticated: true,
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
    final fireRate = double.tryParse('${data[3]}') ?? 0;
    final payload = <String, dynamic>{
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
    };

    if (_authToken == null) {
      await _enqueueOfflineEntry(_offlineMatchQueueKey, {
        ...payload,
        'offlineOnly': true,
      });
      lastSubmitWasOffline = true;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved match data offline.'),
            action: SnackBarAction(
              label: 'Download CSV',
              onPressed: () => downloadOfflineQueuesCsv(),
            ),
          ),
        );
      }
      return true;
    }

    try {
      final response = await _request(
        method: 'POST',
        path: '/match-entries',
        authenticated: true,
        body: payload,
      );

      final entry = response['entry'] as Map<String, dynamic>?;
      if (entry != null) {
        matchDataList.insert(0, _normalizeMatchEntry(entry));
      }
      matchScoutingData.add(List<dynamic>.from(data));
      lastSubmitWasOffline = false;

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
      if (_shouldStoreOffline(error)) {
        await _enqueueOfflineEntry(_offlineMatchQueueKey, {
          ...payload,
          'offlineOnly': true,
        });
        lastSubmitWasOffline = true;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Backend unreachable. Match data saved offline.'),
              action: SnackBarAction(
                label: 'Download CSV',
                onPressed: () => downloadOfflineQueuesCsv(),
              ),
            ),
          );
        }
        return true;
      }
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
    _status = (user['status']?.toString() ?? 'active').trim();
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

  // --------------- Offline CSV export ---------------

  String _queueToCsv(List<Map<String, dynamic>> queue) {
    if (queue.isEmpty) return '';

    final allKeys = <String>{};
    for (final entry in queue) {
      allKeys.addAll(entry.keys.where((k) => k != 'offlineOnly'));
    }
    final headers = allKeys.toList()..sort();

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final entry in queue) {
      buffer.writeln(
        headers.map((h) {
          final val = '${entry[h] ?? ''}'.replaceAll('"', '""');
          return '"$val"';
        }).join(','),
      );
    }
    return buffer.toString();
  }

  Future<String> offlinePitQueueToCsv() async {
    return _queueToCsv(await _readOfflineQueue(_offlinePitQueueKey));
  }

  Future<String> offlineMatchQueueToCsv() async {
    return _queueToCsv(await _readOfflineQueue(_offlineMatchQueueKey));
  }

  Future<bool> downloadOfflineQueuesCsv({Rect? sharePositionOrigin}) async {
    final pitCsv = await offlinePitQueueToCsv();
    final matchCsv = await offlineMatchQueueToCsv();
    if (pitCsv.isEmpty && matchCsv.isEmpty) return false;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var ok = true;

    if (pitCsv.isNotEmpty) {
      ok &= await download_client.downloadTextFile(
        filename: 'spectator_offline_pit_$timestamp.csv',
        content: pitCsv,
        mimeType: 'text/csv',
        sharePositionOrigin: sharePositionOrigin,
      );
    }
    if (matchCsv.isNotEmpty) {
      ok &= await download_client.downloadTextFile(
        filename: 'spectator_offline_match_$timestamp.csv',
        content: matchCsv,
        mimeType: 'text/csv',
        sharePositionOrigin: sharePositionOrigin,
      );
    }
    return ok;
  }

  // --------------- Unified offline sync ---------------

  Future<int> getTotalOfflineQueueCount() async {
    final pit = await getOfflinePitQueueCount();
    final match = await getOfflineMatchQueueCount();
    return pit + match;
  }

  Future<Map<String, int>> syncAllOfflineData() async {
    if (!isAuthenticated) {
      throw Exception('Login required to sync offline data.');
    }
    final pitSent = await syncOfflinePitData();
    final matchSent = await syncOfflineMatchData();
    return {'pit': pitSent, 'match': matchSent};
  }

  /// Fetch and cache all data for offline use.
  /// Returns a summary of what was saved.
  Future<Map<String, int>> syncForOffline() async {
    var eventCount = 0;
    var matchCount = 0;
    var teamNameCount = 0;

    // 1. Events + matches for the current event.
    try {
      await fetchMainEventsFromTba();
      eventCount = eventsList.where((e) => e != 'No Events Available').length;
      matchCount = teamsList.length;
    } catch (_) {}

    // 2. Pit template.
    try {
      await fetchPitTemplate();
    } catch (_) {}

    // 3. Datasheets.
    if (isAuthenticated) {
      try {
        await fetchDatasheets();
      } catch (_) {}
    }

    // 4. Pit & match entries.
    try {
      await fetchPitEntries();
    } catch (_) {}
    try {
      await fetchMatchEntries();
    } catch (_) {}

    // 5. About profile.
    try {
      await fetchAboutProfile();
    } catch (_) {}

    // 6. Fetch team names for every team appearing in cached matches.
    final teamNumbers = <int>{};
    for (final match in teamsList) {
      for (final t in match) {
        if (t != 0) teamNumbers.add(t);
      }
    }

    for (final num in teamNumbers) {
      if (cachedTeamNames.containsKey('$num')) continue;
      try {
        final info = await fetchTeamInfoFromBlueAlliance('$num');
        final nickname = info['nickname'] ?? '';
        if (nickname.isNotEmpty) {
          cachedTeamNames['$num'] = nickname;
          teamNameCount++;
        }
      } catch (_) {}
    }

    // Persist team names.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheTeamNamesKey, jsonEncode(cachedTeamNames));

    return {
      'events': eventCount,
      'matches': matchCount,
      'teamNames': cachedTeamNames.length,
      'newTeamNames': teamNameCount,
    };
  }

  /// Look up a team name from cache (no network call).
  String? getCachedTeamName(String teamNumber) {
    final normalized = teamNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return cachedTeamNames[normalized];
  }
}
