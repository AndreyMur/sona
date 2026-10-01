import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Нативная реализация записи файла экспорта (документы приложения).
Future<String> writeExportFile(String fileName, String content) async {
  final directory = await getApplicationDocumentsDirectory();
  final separator = Platform.pathSeparator;
  final file = File('${directory.path}$separator$fileName');
  await file.writeAsString(content, flush: true);
  return file.path;
}
