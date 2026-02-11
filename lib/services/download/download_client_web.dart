import 'dart:convert';
import 'dart:html' as html;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) async {
  final encoded = base64Encode(utf8.encode(content));
  final url = 'data:$mimeType;charset=utf-8;base64,$encoded';

  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
