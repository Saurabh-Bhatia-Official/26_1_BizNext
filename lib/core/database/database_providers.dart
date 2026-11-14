// lib/core/database/database_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_helper.dart';

final databaseChangeProvider = StreamProvider<String>((ref) {
  return DatabaseHelper.instance.changeStream;
});

class DatabaseVersionNotifier extends StateNotifier<int> {
  DatabaseVersionNotifier() : super(0);
  void increment() => state++;
}

final databaseVersionProvider = StateNotifierProvider<DatabaseVersionNotifier, int>((ref) {
  final notifier = DatabaseVersionNotifier();
  // Listen to database changes and increment version
  ref.listen(databaseChangeProvider, (prev, next) {
    notifier.increment();
  });
  return notifier;
});
