import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/exceptions/app_exception.dart';

/// Uploads a receipt/photo attachment to the Storage path
/// `transactions/{uid}/{transactionId}/{fileName}` that `storage.rules`
/// already reserves for this (owner-only, <=5 MB, image or PDF).
class AttachmentUploadService {
  AttachmentUploadService({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;

  /// Mirrors `storage.rules`' `isValidFileSize()` — kept in sync with it.
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Mirrors `storage.rules`' `isValidDocumentType()`.
  static bool isAllowedContentType(String contentType) =>
      contentType.startsWith('image/') || contentType == 'application/pdf';

  /// Uploads [bytes] and returns its download URL. [onProgress] receives a
  /// 0.0-1.0 value as the upload proceeds.
  Future<String> upload({
    required String userId,
    required String transactionId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.length > maxFileSizeBytes) {
      throw const ValidationException('File must be 5 MB or smaller');
    }
    if (!isAllowedContentType(contentType)) {
      throw const ValidationException('Only images and PDF files can be attached');
    }

    final path =
        'transactions/$userId/$transactionId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = _storage.ref(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));

    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    try {
      await task;
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Upload failed', e.code);
    } finally {
      await subscription.cancel();
    }

    return ref.getDownloadURL();
  }

  /// Best-effort delete — the attachment reference is removed from the
  /// transaction regardless of whether the underlying file could be deleted.
  Future<void> delete(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Ignore: an already-missing or unparseable file isn't fatal here.
    }
  }
}
