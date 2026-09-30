import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/app_database.dart';
import 'data/local/connection.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/services/database_key_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const storage = FlutterSecureStorage();
  final encryptionKey = await DatabaseKeyProvider(storage).getOrCreate();
  final database = AppDatabase(
    openEncryptedDatabase(encryptionKey: encryptionKey),
  );
  await DriftCategoryRepository(database).seedIfEmpty();

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const SonaApp(),
    ),
  );
}
