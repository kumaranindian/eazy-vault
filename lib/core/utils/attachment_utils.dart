import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../extensions/context_extensions.dart';

/// Opens an attachment URL stored on a transaction. Shared by every place
/// that renders a "View Attachment" link so the validation/error handling
/// behavior stays identical.
class AttachmentUtils {
  const AttachmentUtils._();

  static Future<void> openAttachment(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    final isValid = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https');

    if (!isValid) {
      context.showErrorSnackBar('Unable to open attachment');
      return;
    }

    try {
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!launched && context.mounted) {
        context.showErrorSnackBar('Unable to open attachment');
      }
    } catch (_) {
      if (context.mounted) {
        context.showErrorSnackBar('Unable to open attachment');
      }
    }
  }
}
