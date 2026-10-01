/// Веб-заглушка записи файла экспорта.
///
/// В браузере нативная файловая система недоступна; демо-режим
/// переопределяет провайдер на in-memory реализацию.
Future<String> writeExportFile(String fileName, String content) async =>
    'demo://$fileName';
