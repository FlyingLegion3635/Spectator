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
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    sharePositionOrigin: sharePositionOrigin,
  );
  return true;
}
