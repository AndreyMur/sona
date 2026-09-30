import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Открывает локальную БД с шифрованием SQLCipher.
///
/// [encryptionKey] передаётся в `PRAGMA key` до первого обращения drift к БД.
DatabaseConnection openEncryptedDatabase({required String encryptionKey}) {
  return driftDatabase(
    name: 'sona',
    native: DriftNativeOptions(
      setup: (db) {
        db.execute("PRAGMA key = '$encryptionKey';");
      },
    ),
  );
}
