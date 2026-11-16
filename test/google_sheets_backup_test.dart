import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifesync_tracker/services/apps_script_template.dart';
import 'package:lifesync_tracker/services/google_sheets_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Google Sheets Universal Backup Tests', () {
    test('AppsScriptTemplate contains universal dynamic table sync functions', () {
      final code = AppsScriptTemplate.code;
      expect(code.isNotEmpty, isTrue);
      expect(code.contains('function doPost(e)'), isTrue);
      expect(code.contains('function doGet(e)'), isTrue);
      expect(code.contains('Sync_Overview'), isTrue);
      expect(code.contains('allData'), isTrue);
    });

    test('GoogleSheetsBackupService handles empty Web App URL gracefully', () async {
      final service = GoogleSheetsBackupService.instance;
      await service.setWebAppUrl('');
      final result = await service.backupNow();
      expect(result['success'], isFalse);
      expect(result['message'], contains('not configured'));
    });

    test('GoogleSheetsBackupService saves and retrieves Web App URL', () async {
      final service = GoogleSheetsBackupService.instance;
      const testUrl = 'https://script.google.com/macros/s/test_123/exec';
      await service.setWebAppUrl(testUrl);
      expect(await service.getWebAppUrl(), equals(testUrl));
      await service.setWebAppUrl(null);
      expect(await service.getWebAppUrl(), isNull);
    });

    test('AppsScriptTemplate automatically maps table names into formatted Google Sheet tabs', () {
      final template = AppsScriptTemplate.code;
      expect(template.contains('formatSheetTitle'), isTrue);
      expect(template.contains('headerRange.setBackground'), isTrue);
      expect(template.contains('Sync_Overview'), isTrue);
    });
  });
}
