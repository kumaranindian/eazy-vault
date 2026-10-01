import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../categories/presentation/providers/categories_providers.dart';
import '../../../transactions/presentation/providers/loan_providers.dart';
import '../../../transactions/presentation/providers/transactions_providers.dart';
import '../../data/services/excel_report_service.dart';
import '../../data/services/pdf_report_service.dart';
import '../../domain/services/report_calculation_service.dart';

part 'reports_providers.g.dart';

@Riverpod(keepAlive: true)
ReportCalculationService reportCalculationService(ReportCalculationServiceRef ref) {
  return ReportCalculationService(
    transactionsRepository: ref.watch(transactionsRepositoryProvider),
    accountsRepository: ref.watch(accountsRepositoryProvider),
    categoriesRepository: ref.watch(categoriesRepositoryProvider),
    loanService: ref.watch(loanServiceProvider),
  );
}

@Riverpod(keepAlive: true)
PdfReportService pdfReportService(PdfReportServiceRef ref) {
  return const PdfReportService();
}

@Riverpod(keepAlive: true)
ExcelReportService excelReportService(ExcelReportServiceRef ref) {
  return const ExcelReportService();
}
