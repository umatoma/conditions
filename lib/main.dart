// ignore_for_file: top_level_function_literal_block

import 'package:conditions/condition.dart';
import 'package:conditions/repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

final dbProvider = FutureProvider(
  (ref) => openDatabase(),
);

final conditionRepoProvider = FutureProvider((ref) async {
  final db = await ref.watch(dbProvider.future);
  return CondtionRepository(db);
});

final lastUpdateProvider = StateProvider((ref) {
  return DateTime.now();
});

final conditionsProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(lastUpdateProvider);
  final repo = await ref.read(conditionRepoProvider.future);
  return await repo.getList();
});

final conditionByDateProvider =
    FutureProvider.family.autoDispose((ref, DateTime date) async {
  final conditions = await ref.watch(conditionsProvider.future);
  final condition = conditions.firstWhere(
    (c) => c.date.isAtSameDayAs(date),
    orElse: () => Condition.create(date: date),
  );
  return condition;
});

final dialogConditionProvider =
    StateProvider.family.autoDispose((ref, Condition condition) {
  return condition;
});

final focusedDayProvider = StateProvider.autoDispose((ref) {
  return DateTime.now();
});

final focusedConditionsProvider = FutureProvider.autoDispose((ref) async {
  final focusedDay = ref.watch(focusedDayProvider).state;
  final conditions = await ref.watch(conditionsProvider.future);
  final focusedConditions = conditions
      .where((condition) => condition.date.isAtSameMonthAs(focusedDay))
      .toList();
  return focusedConditions;
});

final focusedConditionSummaryProvider = FutureProvider.autoDispose((ref) async {
  final conditions = await ref.watch(focusedConditionsProvider.future);
  final summary = ConditionSummary(conditions: conditions);
  return summary;
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ja_JP';
  runApp(
    ProviderScope(
      child: App(),
    ),
  );
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conditions',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ja', 'JP'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const ConditionCalendar(),
            const SizedBox(height: 16),
            Expanded(
              child: const ConditionSummaryView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final now = DateTime.now();
          final date = DateTime(now.year, now.month, now.day);
          final condition =
              await context.read(conditionByDateProvider(date).future);
          await showDialog(
            context: context,
            builder: (context) => ConditionDialog(condition: condition),
          );
        },
        child: Icon(CupertinoIcons.add),
      ),
    );
  }
}

class ConditionCalendar extends StatelessWidget {
  const ConditionCalendar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      final asyncConditions = watch(conditionsProvider);
      return asyncConditions.when(
        data: (conditions) {
          return TableCalendar<Condition>(
            eventLoader: (day) {
              return conditions
                  .where((c) => c.date.isAtSameDayAs(day))
                  .toList();
            },
            onDaySelected: (day, focusedDay) async {
              HapticFeedback.mediumImpact();
              final condition =
                  await context.read(conditionByDateProvider(day).future);
              await showDialog(
                context: context,
                builder: (context) => ConditionDialog(condition: condition),
              );
            },
            onPageChanged: (day) {
              context.read(focusedDayProvider).state = day;
            },
            availableCalendarFormats: {
              CalendarFormat.month: 'month',
            },
            firstDay: DateTime.utc(2010, 1, 1),
            lastDay: DateTime.utc(2099, 1, 1),
            focusedDay: DateTime.now(),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                return Align(
                  alignment: Alignment.bottomRight,
                  child: events.isEmpty
                      ? Icon(
                          CupertinoIcons.add,
                          size: 12,
                          color: Theme.of(context).unselectedWidgetColor,
                        )
                      : Image(
                          image: valueToIconData(events.first.value),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                );
              },
            ),
          );
        },
        loading: () {
          return SizedBox(
            height: 500,
            width: double.infinity,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        error: (error, stackTrace) {
          return SizedBox(
            height: 500,
            width: double.infinity,
            child: Center(
              child: Text(error.toString()),
            ),
          );
        },
      );
    });
  }
}

class ConditionDialog extends StatelessWidget {
  const ConditionDialog({
    Key? key,
    required this.condition,
  }) : super(key: key);

  final Condition condition;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, watch, child) {
        final controller = watch(dialogConditionProvider(condition));
        final state = controller.state;
        final primaryColor = Theme.of(context).primaryColor;
        return SimpleDialog(
          title: Text(
            DateFormat.yMd().format(state.date),
          ),
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final value in ConditionValue.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            controller.state = state.setValue(value);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                            side: state.value == value
                                ? BorderSide(color: primaryColor)
                                : null,
                          ),
                          child: Image(
                            image: valueToIconData(value),
                            height: 92,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await addCondition(context, state);
                  Navigator.of(context).pop();
                },
                child: Text('登録'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> addCondition(BuildContext context, Condition state) async {
    final repo = await context.read(conditionRepoProvider.future);
    final conditions = await context.read(conditionsProvider.future);
    final isSaved = conditions
        .where((condition) => condition.date.isAtSameDayAs(state.date))
        .isNotEmpty;

    if (isSaved) {
      await repo.update(state);
    } else {
      await repo.insert(state);
    }

    context.read(lastUpdateProvider).state = DateTime.now();
  }
}

class ConditionSummaryView extends StatelessWidget {
  const ConditionSummaryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      final asyncSummary = watch(focusedConditionSummaryProvider);
      return asyncSummary.when(
        data: (summary) {
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('サマリー'),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final value in ConditionValue.values)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AspectRatio(
                              aspectRatio: 1 / 1,
                              child: Image(
                                image: valueToIconData(value),
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${summary.countByValue(value)}',
                              style: Theme.of(context).textTheme.headline4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Text(error.toString()),
          );
        },
      );
    });
  }
}

ImageProvider valueToIconData(ConditionValue value) {
  switch (value) {
    case ConditionValue.excellent:
      return AssetImage('images/excellent.png');
    case ConditionValue.good:
      return AssetImage('images/good.png');
    case ConditionValue.poor:
      return AssetImage('images/poor.png');
  }
}

extension ExDateTime on DateTime {
  bool isAtSameMonthAs(DateTime other) {
    return year == other.year && month == other.month;
  }

  bool isAtSameDayAs(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}
