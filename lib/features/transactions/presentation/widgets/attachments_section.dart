import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/attachment_utils.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_notifier.dart';
import '../providers/transactions_providers.dart';

const Map<String, String> _contentTypesByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

/// Shown on both transaction detail surfaces (modal + page) so upload/view/
/// remove behavior is identical and defined only once.
class AttachmentsSection extends ConsumerStatefulWidget {
  const AttachmentsSection({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _removingUrl;

  Future<void> _pickAndUpload() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.showErrorSnackBar('Your session has expired. Please sign in again.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _contentTypesByExtension.keys.toList(),
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      context.showErrorSnackBar("Couldn't read the selected file. Please try again.");
      return;
    }

    final extension = file.extension?.toLowerCase() ?? '';
    final contentType = _contentTypesByExtension[extension];
    if (contentType == null) {
      context.showErrorSnackBar('Only images and PDF files can be attached');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final uploadService = ref.read(attachmentUploadServiceProvider);
      final url = await uploadService.upload(
        userId: user.uid,
        transactionId: widget.transaction.id,
        fileName: file.name,
        bytes: bytes,
        contentType: contentType,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );

      final failure = await ref
          .read(transactionsRepositoryProvider)
          .addAttachment(user.uid, widget.transaction.id, url);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (failure == null) {
        ref.invalidate(transactionProvider(widget.transaction.id));
        context.showSuccessSnackBar('Attachment uploaded successfully');
      } else {
        context.showErrorSnackBar(failure.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      context.showErrorSnackBar('Attachment upload failed. Please try again.');
    }
  }

  Future<void> _remove(String url) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Remove Attachment',
      message: 'Remove this attachment from the transaction?',
      confirmText: 'Remove',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _removingUrl = url);
    final failure = await ref
        .read(transactionsRepositoryProvider)
        .removeAttachment(user.uid, widget.transaction.id, url);

    if (!mounted) return;
    setState(() => _removingUrl = null);

    if (failure == null) {
      await ref.read(attachmentUploadServiceProvider).delete(url);
      if (!mounted) return;
      ref.invalidate(transactionProvider(widget.transaction.id));
      context.showSuccessSnackBar('Attachment removed');
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.transaction.attachments ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachments',
              style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: _isUploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(
                _isUploading ? 'Uploading ${(_uploadProgress * 100).round()}%' : 'Add Attachment',
              ),
            ),
          ],
        ),
        if (attachments.isEmpty && !_isUploading)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No attachments yet',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final url in attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.attach_file),
            title: InkWell(
              onTap: () => AttachmentUtils.openAttachment(context, url),
              child: const Text(
                'View Attachment',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
            trailing: _removingUrl == url
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Remove',
                    onPressed: () => _remove(url),
                  ),
          ),
      ],
    );
  }
}
