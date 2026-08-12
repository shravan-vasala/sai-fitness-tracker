import 'dart:io';
import 'package:hive/hive.dart';
import 'package:trufit_bodamma/models/hive_adapters.dart';

Future<void> setUpTestHive() async {
  final tempDir = Directory.systemTemp.createTempSync('hive_test_');
  Hive.init(tempDir.path);
  try {
    registerHiveAdapters();
  } catch (e) {
    // Ignore duplicate adapter registrations in tests
  }
}

Future<void> tearDownTestHive() async {
  await Hive.deleteFromDisk();
  await Hive.close();
}
