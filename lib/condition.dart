import 'package:uuid/uuid.dart';

enum ConditionValue {
  excellent,
  good,
  poor,
}

class Condition {
  const Condition({
    required this.id,
    required this.date,
    required this.value,
  });

  Condition.create({
    required this.date,
    this.value = ConditionValue.good,
  }) : id = Uuid().v4();

  final String id;
  final DateTime date;
  final ConditionValue value;

  Condition setDate(DateTime v) {
    return Condition(
      id: id,
      date: v,
      value: value,
    );
  }

  Condition setValue(ConditionValue v) {
    return Condition(
      id: id,
      date: date,
      value: v,
    );
  }
}

class ConditionSummary {
  ConditionSummary({
    required this.conditions,
  });

  final List<Condition> conditions;

  int countByValue(ConditionValue value) {
    return conditions.where((condition) => condition.value == value).length;
  }
}
