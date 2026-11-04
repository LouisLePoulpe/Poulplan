import 'package:flutter_test/flutter_test.dart';
import 'package:poulplan/features/storage/storage_report.dart';

void main() {
  const mb = 1024 * 1024;

  StorageReport report({int? free, int freeable = 0, int oldBackups = 0}) =>
      StorageReport(
        databaseBytes: 2 * mb,
        attachmentBytes: 40 * mb,
        freeableAttachmentBytes: freeable,
        backupBytes: 10 * mb,
        oldBackupBytes: oldBackups,
        freeBytes: free,
      );

  test('cleanup is proposed only when space is low and something can go', () {
    expect(report(free: 100 * mb, freeable: 30 * mb).proposeCleanup, isTrue);
    expect(report(free: 100 * mb, oldBackups: 8 * mb).proposeCleanup, isTrue);
    expect(report(free: 100 * mb).proposeCleanup, isFalse);
    expect(report(free: 5000 * mb, freeable: 30 * mb).proposeCleanup, isFalse);
    expect(report(freeable: 30 * mb).proposeCleanup, isFalse);
  });

  test('totals', () {
    final r = report(free: 100 * mb, freeable: 30 * mb, oldBackups: 8 * mb);
    expect(r.reclaimableBytes, 38 * mb);
    expect(r.totalBytes, 52 * mb);
  });
}
