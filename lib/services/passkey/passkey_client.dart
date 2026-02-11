import 'passkey_client_stub.dart'
    if (dart.library.html) 'passkey_client_web.dart' as impl;

Future<Map<String, dynamic>> createPasskeyCredential(
  Map<String, dynamic> options,
) {
  return impl.createPasskeyCredential(options);
}

Future<Map<String, dynamic>> getPasskeyCredential(
  Map<String, dynamic> options,
) {
  return impl.getPasskeyCredential(options);
}
