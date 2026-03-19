import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
  Rect? sharePositionOrigin,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);

  // iPad requires a non-zero sharePositionOrigin for the share popover.
  final origin = sharePositionOrigin ?? const Rect.fromLTWH(100, 100, 200, 50);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    sharePositionOrigin: origin,
  );
  return true;
}
