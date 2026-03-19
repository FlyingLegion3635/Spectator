import 'package:flutter/widgets.dart';

import 'download_client_stub.dart'
    if (dart.library.html) 'download_client_web.dart'
    if (dart.library.io) 'download_client_native.dart'
    as impl;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
  Rect? sharePositionOrigin,
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
    sharePositionOrigin: sharePositionOrigin,
  );
}
