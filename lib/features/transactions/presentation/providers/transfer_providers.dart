import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/services/transfer_service.dart';

part 'transfer_providers.g.dart';

@riverpod
TransferService transferService(TransferServiceRef ref) {
  return TransferService(firestore: FirebaseFirestore.instance);
}
