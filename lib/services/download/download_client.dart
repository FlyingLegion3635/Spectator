import 'download_client_stub.dart'
    if (dart.library.html) 'download_client_web.dart'
    as impl;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}
