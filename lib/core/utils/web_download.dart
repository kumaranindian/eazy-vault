import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download of [bytes] as [filename]. Web-only, matching
/// this app's single supported platform (no android/ios targets).
void downloadFile(Uint8List bytes, String filename, {required String mimeType}) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
