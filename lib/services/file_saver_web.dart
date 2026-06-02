import 'dart:convert';
import 'dart:html' as html;

void saveTextFileImpl(String content, String fileName) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/markdown');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
