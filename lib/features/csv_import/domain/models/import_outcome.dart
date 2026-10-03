/// Result of running the import step over the previewed rows.
class ImportOutcome {
  const ImportOutcome({
    required this.imported,
    required this.skippedDuplicates,
    required this.invalid,
    required this.failed,
  });

  final int imported;
  final int skippedDuplicates;
  final int invalid;

  /// Rows that were valid, included and not a duplicate, but whose write
  /// still failed (e.g. a transient Firestore error).
  final int failed;

  bool get isFullSuccess => failed == 0 && imported > 0;
  bool get isPartialSuccess => imported > 0 && (skippedDuplicates > 0 || invalid > 0 || failed > 0);
}
