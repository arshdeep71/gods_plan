import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_common/sqlite_api.dart';

DatabaseFactory? _cachedWebFactory;

Future<Database> openSqliteDatabase(
  String path, {
  required int version,
  required Future<void> Function(Database, int) onCreate,
}) async {
  _cachedWebFactory ??= createDatabaseFactoryFfiWeb(
    options: SqfliteFfiWebOptions(
      sharedWorkerUri: Uri.parse('sqflite_sw.js'),
      forceAsBasicWorker: true,
    ),
  );
  return await _cachedWebFactory!.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, v) => onCreate(db, v),
    ),
  );
}

Future<String> getSqliteDatabasesPath() async {
  return '';
}
