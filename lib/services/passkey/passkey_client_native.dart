import 'package:flutter/services.dart';

const _channel = MethodChannel('spectator/passkeys');

Future<Map<String, dynamic>> createPasskeyCredential(
  Map<String, dynamic> options,
) async {
  try {
    final result = await _channel.invokeMethod<Map>('createCredential', options);
    if (result == null) throw Exception('Passkey registration was cancelled.');
    return Map<String, dynamic>.from(result);
  } on PlatformException catch (e) {
    if (e.code == 'CANCELLED') throw Exception('Passkey registration was cancelled.');
    throw Exception(e.message ?? 'Passkey registration failed.');
  }
}

Future<Map<String, dynamic>> getPasskeyCredential(
  Map<String, dynamic> options,
) async {
  try {
    final result = await _channel.invokeMethod<Map>('getCredential', options);
    if (result == null) throw Exception('Passkey login was cancelled.');
    return Map<String, dynamic>.from(result);
  } on PlatformException catch (e) {
    if (e.code == 'CANCELLED') throw Exception('Passkey login was cancelled.');
    throw Exception(e.message ?? 'Passkey login failed.');
  }
}
