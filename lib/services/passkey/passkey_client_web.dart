import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, dynamic>> createPasskeyCredential(
  Map<String, dynamic> options,
) async {
  final preparedPublicKey = _prepareCreationOptions(options);

  final credential = await html.window.navigator.credentials?.create({
    'publicKey': preparedPublicKey,
  });

  if (credential == null) {
    throw Exception('Passkey registration was cancelled.');
  }

  return _serializeRegistrationCredential(credential);
}

Future<Map<String, dynamic>> getPasskeyCredential(
  Map<String, dynamic> options,
) async {
  final preparedPublicKey = _prepareAuthenticationOptions(options);

  final credential = await html.window.navigator.credentials?.get({
    'publicKey': preparedPublicKey,
  });

  if (credential == null) {
    throw Exception('Passkey login was cancelled.');
  }

  return _serializeAuthenticationCredential(credential);
}

Map<String, dynamic> _prepareCreationOptions(Map<String, dynamic> options) {
  final publicKey = _extractPublicKeyOptions(options);
  publicKey['challenge'] = _toBuffer(publicKey['challenge']);

  final user = Map<String, dynamic>.from(publicKey['user'] as Map);
  user['id'] = _toBuffer(user['id']);
  publicKey['user'] = user;

  final excludeCredentials = (publicKey['excludeCredentials'] as List?) ?? [];
  publicKey['excludeCredentials'] = excludeCredentials.map((credential) {
    final mapped = Map<String, dynamic>.from(credential as Map);
    mapped['id'] = _toBuffer(mapped['id']);
    return mapped;
  }).toList();

  return publicKey;
}

Map<String, dynamic> _prepareAuthenticationOptions(
  Map<String, dynamic> options,
) {
  final publicKey = _extractPublicKeyOptions(options);
  publicKey['challenge'] = _toBuffer(publicKey['challenge']);

  final allowCredentials = (publicKey['allowCredentials'] as List?) ?? [];
  publicKey['allowCredentials'] = allowCredentials.map((credential) {
    final mapped = Map<String, dynamic>.from(credential as Map);
    mapped['id'] = _toBuffer(mapped['id']);
    return mapped;
  }).toList();

  return publicKey;
}

Map<String, dynamic> _extractPublicKeyOptions(Map<String, dynamic> options) {
  final wrapped = options['publicKey'];
  if (wrapped is Map) {
    return Map<String, dynamic>.from(wrapped);
  }
  return Map<String, dynamic>.from(options);
}

Map<String, dynamic> _serializeRegistrationCredential(dynamic credential) {
  final dynamic response = credential.response;

  List<String> transports = [];
  try {
    final dynamic raw = response.getTransports();
    transports = List<String>.from(raw as List);
  } catch (_) {
    transports = [];
  }

  return {
    'id': credential.id,
    'rawId': _encodeBase64Url((credential.rawId as ByteBuffer).asUint8List()),
    'type': credential.type,
    'response': {
      'clientDataJSON': _encodeBase64Url(
        (response.clientDataJSON as ByteBuffer).asUint8List(),
      ),
      'attestationObject': _encodeBase64Url(
        (response.attestationObject as ByteBuffer).asUint8List(),
      ),
      'transports': transports,
    },
    'clientExtensionResults': credential.getClientExtensionResults(),
  };
}

Map<String, dynamic> _serializeAuthenticationCredential(dynamic credential) {
  final dynamic response = credential.response;
  final dynamic userHandle = response.userHandle;

  return {
    'id': credential.id,
    'rawId': _encodeBase64Url((credential.rawId as ByteBuffer).asUint8List()),
    'type': credential.type,
    'response': {
      'clientDataJSON': _encodeBase64Url(
        (response.clientDataJSON as ByteBuffer).asUint8List(),
      ),
      'authenticatorData': _encodeBase64Url(
        (response.authenticatorData as ByteBuffer).asUint8List(),
      ),
      'signature': _encodeBase64Url(
        (response.signature as ByteBuffer).asUint8List(),
      ),
      'userHandle': userHandle == null
          ? null
          : _encodeBase64Url((userHandle as ByteBuffer).asUint8List()),
    },
    'clientExtensionResults': credential.getClientExtensionResults(),
  };
}

Uint8List _decodeBase64Url(String value) {
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  switch (normalized.length % 4) {
    case 0:
      break;
    case 2:
      normalized = '$normalized==';
      break;
    case 3:
      normalized = '$normalized=';
      break;
    default:
      throw Exception('Invalid base64url value');
  }

  return base64Decode(normalized);
}

String _encodeBase64Url(Uint8List bytes) {
  return base64Encode(
    bytes,
  ).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

Uint8List _toBytes(dynamic raw) {
  if (raw == null) {
    throw Exception('Missing passkey binary field.');
  }

  if (raw is Uint8List) {
    return raw;
  }

  if (raw is ByteBuffer) {
    return raw.asUint8List();
  }

  if (raw is ByteData) {
    return raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
  }

  if (raw is List<int>) {
    return Uint8List.fromList(raw);
  }

  if (raw is List) {
    return Uint8List.fromList(raw.map((e) => (e as num).toInt()).toList());
  }

  if (raw is String) {
    return _decodeBase64Url(raw);
  }

  if (raw is Map) {
    final type = raw['type'];
    final data = raw['data'];
    if (type == 'Buffer' && data is List) {
      return Uint8List.fromList(data.map((e) => (e as num).toInt()).toList());
    }

    final numericKeys =
        raw.keys
            .whereType<String>()
            .where((entry) => int.tryParse(entry) != null)
            .toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    if (numericKeys.isNotEmpty) {
      return Uint8List.fromList(
        numericKeys.map((entry) => (raw[entry] as num).toInt()).toList(),
      );
    }
  }

  throw Exception('Unsupported passkey binary value: ${raw.runtimeType}');
}

ByteBuffer _toBuffer(dynamic raw) {
  final bytes = _toBytes(raw);
  return Uint8List.fromList(bytes).buffer;
}
