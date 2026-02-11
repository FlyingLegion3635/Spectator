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
  final publicKey = Map<String, dynamic>.from(options);
  publicKey['challenge'] = _decodeBase64Url(publicKey['challenge'] as String);

  final user = Map<String, dynamic>.from(publicKey['user'] as Map);
  user['id'] = _decodeBase64Url(user['id'] as String);
  publicKey['user'] = user;

  final excludeCredentials = (publicKey['excludeCredentials'] as List?) ?? [];
  publicKey['excludeCredentials'] = excludeCredentials.map((credential) {
    final mapped = Map<String, dynamic>.from(credential as Map);
    mapped['id'] = _decodeBase64Url(mapped['id'] as String);
    return mapped;
  }).toList();

  return publicKey;
}

Map<String, dynamic> _prepareAuthenticationOptions(Map<String, dynamic> options) {
  final publicKey = Map<String, dynamic>.from(options);
  publicKey['challenge'] = _decodeBase64Url(publicKey['challenge'] as String);

  final allowCredentials = (publicKey['allowCredentials'] as List?) ?? [];
  publicKey['allowCredentials'] = allowCredentials.map((credential) {
    final mapped = Map<String, dynamic>.from(credential as Map);
    mapped['id'] = _decodeBase64Url(mapped['id'] as String);
    return mapped;
  }).toList();

  return publicKey;
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
      'signature': _encodeBase64Url((response.signature as ByteBuffer).asUint8List()),
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
  return base64Encode(bytes)
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}
