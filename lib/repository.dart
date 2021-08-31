import 'package:conditions/condition.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

Future<sqflite.Database> openDatabase() async {
  await sqflite.Sqflite.setDebugModeOn(true);
  final path = join(await sqflite.getDatabasesPath(), 'app.db');
  final db = await sqflite.openDatabase(
    path,
    version: 20210830,
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE conditions ('
        '  id TEXT PRIMARY KEY,'
        '  date INTEGER NOT NULL UNIQUE,'
        '  value TEXT NOT NULL'
        ')',
      );
    },
  );
  return db;
}

class CondtionRepository {
  const CondtionRepository(this.db);

  final sqflite.Database db;
  final String table = 'conditions';

  Future<List<Condition>> getList() async {
    final list = await db.query(table, orderBy: 'date DESC');
    final conditions = list
        .map((row) => Condition(
              id: row['id'] as String,
              date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
              value: stringToValue(row['value'] as String)!,
            ))
        .toList();
    return conditions;
  }

  Future<void> insert(Condition condition) async {
    await db.insert(table, {
      'id': condition.id,
      'date': condition.date.millisecondsSinceEpoch,
      'value': valueToString(condition.value),
    });
  }

  Future<void> update(Condition condition) async {
    await db.update(
      table,
      {
        'date': condition.date.millisecondsSinceEpoch,
        'value': valueToString(condition.value),
      },
      where: 'id = ?',
      whereArgs: [condition.id],
    );
  }
}

ConditionValue? stringToValue(String text) {
  switch (text) {
    case 'excellent':
      return ConditionValue.excellent;
    case 'good':
      return ConditionValue.good;
    case 'poor':
      return ConditionValue.poor;
    default:
      return null;
  }
}

String valueToString(ConditionValue value) {
  switch (value) {
    case ConditionValue.excellent:
      return 'excellent';
    case ConditionValue.good:
      return 'good';
    case ConditionValue.poor:
      return 'poor';
  }
}
