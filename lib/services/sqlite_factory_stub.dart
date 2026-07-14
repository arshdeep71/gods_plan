import 'package:sqflite_common/database.dart';

Future<Database> openSqliteDatabase(
  String path, {
  required int version,
  required Future<void> Function(Database, int) onCreate,
}) {
  throw UnimplementedError('openSqliteDatabase is not implemented on this platform');
}

Future<String> getSqliteDatabasesPath() {
  throw UnimplementedError('getSqliteDatabasesPath is not implemented on this platform');
}
