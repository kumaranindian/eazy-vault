import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/services/loan_service.dart';

part 'loan_providers.g.dart';

@riverpod
LoanService loanService(LoanServiceRef ref) {
  return LoanService(firestore: FirebaseFirestore.instance);
}

@riverpod
Future<({List<TransactionModel> loansGiven, List<TransactionModel> loansTaken})>
    activeLoans(ActiveLoansRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return (loansGiven: <TransactionModel>[], loansTaken: <TransactionModel>[]);
  }

  final loanService = ref.watch(loanServiceProvider);
  return await loanService.getActiveLoans(user.uid);
}

@riverpod
Future<List<TransactionModel>> overdueLoans(OverdueLoansRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final loanService = ref.watch(loanServiceProvider);
  return await loanService.getOverdueLoans(user.uid);
}

@riverpod
Future<double> totalOwedToYou(TotalOwedToYouRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final loanService = ref.watch(loanServiceProvider);
  return await loanService.getTotalOwedToYou(user.uid);
}

@riverpod
Future<double> totalYouOwe(TotalYouOweRef ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final loanService = ref.watch(loanServiceProvider);
  return await loanService.getTotalYouOwe(user.uid);
}
