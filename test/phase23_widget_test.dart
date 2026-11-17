import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/core/theme.dart';
import 'package:planner/models/day_schedule.dart';
import 'package:planner/models/schedule_suggestion.dart';
import 'package:planner/models/scheduled_task.dart';
import 'package:planner/models/task.dart';
import 'package:planner/features/day/widgets/interruption_sheet.dart';
import 'package:planner/features/day/widgets/missed_list.dart';
import 'package:planner/features/day/widgets/now_card.dart';
import 'package:planner/features/day/widgets/schedule_timeline.dart';
import 'package:planner/features/day/widgets/suggestion_banner.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

final _day = DateTime(2030, 1, 7);

/// [child] in the app's theme, on a phone-sized screen.
Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Task _task(
  String title, {
  TaskType type = TaskType.floating,
  TimeOfDay? at,
  int minutes = 30,
}) => Task(
  title: title,
  durationMinutes: minutes,
  type: type,
  startTime: at,
  date: _day,
);

/// The whole app on a day 10 days out, so nothing depends on the clock
/// ([today] for what is only offered today).
Future<DayPlannerModel> _app(
  WidgetTester tester,
  List<Task> tasks, {
  bool today = false,
}) async {
  final model = DayPlannerModel();
  await tester.runAsync(
    () => model.loadDate(DateTime.now().add(Duration(days: today ? 0 : 10))),
  );
  for (final t in tasks) {
    model.addTask(t.copyWith(date: model.viewedDate));
  }
  await tester.pumpWidget(
    SettingsProvider(
      model: SettingsModel(),
      child: DayPlannerProvider(model: model, child: const HyperDayApp()),
    ),
  );
  await tester.pump();
  return model;
}

Future<void> _openItem(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('Missed list', () {
    testWidgets('offers Later today only when it still fits', (tester) async {
      final calls = <String>[];
      final call = _task(
        'Call Sam',
        type: TaskType.pinned,
        at: const TimeOfDay(hour: 9, minute: 0),
      );
      final report = _task(
        'Report',
        type: TaskType.pinned,
        at: const TimeOfDay(hour: 10, minute: 0),
        minutes: 60,
      );
      await tester.pumpWidget(
        _host(
          MissedList(
            tasks: [call, report],
            nextDayLabel: 'Tomorrow',
            fitsToday: (t) => t == call,
            onLaterToday: (t) => calls.add('later ${t.title}'),
            onNextDay: (t) => calls.add('next ${t.title}'),
            onDone: (t) => calls.add('done ${t.title}'),
          ),
        ),
      );
      expect(find.text('MISSED'), findsOneWidget);
      expect(find.text('Was at 9:00 AM · 30m'), findsOneWidget);
      expect(find.text('Later today'), findsOneWidget);
      expect(find.text('Tomorrow'), findsNWidgets(2));

      await tester.tap(find.text('Later today'));
      await tester.tap(find.text('Tomorrow').last);
      await tester.tap(find.text('Done').first);
      expect(calls, ['later Call Sam', 'next Report', 'done Call Sam']);
    });
  });

  group('"Your day shifted" banner', () {
    final schedule = DaySchedule(committed: const [], overflow: const []);

    testWidgets('lists what no longer fits; OK and Keep as it was', (
      tester,
    ) async {
      var ok = 0, undo = 0;
      await tester.pumpWidget(
        _host(
          SuggestionBanner(
            suggestion: ScheduleSuggestion(
              proposed: schedule,
              moves: const [],
              pushedOut: [_task('Hiring plan')],
            ),
            onAccept: () => ok++,
            onDismiss: () => undo++,
          ),
        ),
      );
      expect(find.text('YOUR DAY SHIFTED'), findsOneWidget);
      expect(find.text('Not enough time left today.'), findsOneWidget);
      expect(find.text('Hiring plan'), findsOneWidget);
      expect(find.text("Doesn't fit"), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.tap(find.text('Keep as it was'));
      expect((ok, undo), (1, 1));
    });

    testWidgets('a clock-driven shift shows the move, with OK only', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SuggestionBanner(
            suggestion: ScheduleSuggestion(
              proposed: schedule,
              moves: [
                TaskMove(
                  task: _task('Board deck'),
                  oldStart: const TimeOfDay(hour: 9, minute: 0),
                  newStart: const TimeOfDay(hour: 10, minute: 30),
                ),
              ],
              canUndo: false,
            ),
            onAccept: () {},
            onDismiss: () {},
          ),
        ),
      );
      expect(find.text('An outcome moved later.'), findsOneWidget);
      expect(find.text('9:00 AM → 10:30 AM'), findsOneWidget);
      expect(find.text('Keep as it was'), findsNothing);
    });
  });

  group('"Something came up" sheet', () {
    testWidgets('needs a description, then returns the choice', (tester) async {
      (String, InterruptionChoice)? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await InterruptionSheet.show(
                context,
                laterLabel: 'Monday',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Monday'), findsOneWidget);

      await tester.tap(find.text('Do it now'));
      await tester.pumpAndSettle();
      expect(find.text('Something came up'), findsOneWidget); // still open

      await tester.enterText(find.byType(TextField), '  Fix outage 45m ');
      await tester.tap(find.text('Later today'));
      await tester.pumpAndSettle();
      expect(result, ('Fix outage 45m', InterruptionChoice.laterToday));
    });

    testWidgets('from the day: "Came up" → Later today adds it as Anytime', (
      tester,
    ) async {
      final model = await _app(tester, [], today: true);
      await tester.tap(find.text('Came up'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(InterruptionSheet),
          matching: find.byType(TextField),
        ),
        'Server alert 15m at 3',
      );
      await tester.tap(find.text('Later today'));
      await tester.pumpAndSettle();

      final added = model.tasks.single;
      expect(added.title, 'Server alert');
      expect(added.durationMinutes, 15);
      expect(added.type, TaskType.floating);
      expect(added.isInterruption, isTrue);
      expect(find.text('Added "Server alert" for later today'), findsOneWidget);
      model.dispose();
    });
  });

  testWidgets(
    'Now card: a running task\'s actions fit a phone, one line each',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      // Real text widths: the app's font, not the test font's squares.
      await tester.runAsync(() async {
        final inter = FontLoader('Inter');
        for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
          inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
        }
        await inter.load();
      });
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = await _app(tester, [
        _task('Investor update', minutes: 60),
      ], today: true);
      model.startTask(model.tasks.single.id);
      await tester.pump();

      final card = find.byType(NowCard);
      Finder label(String s) =>
          find.descendant(of: card, matching: find.text(s));
      expect(label('Pause'), findsOneWidget);
      expect(
        tester.getSize(label('Pause')).height,
        tester.getSize(label('Done')).height,
      );
      expect(tester.takeException(), isNull);
      model.dispose();
    },
  );

  group('Item sheet', () {
    testWidgets('a running item can be paused from its sheet', (tester) async {
      final model = await _app(tester, [_task('Write spec', minutes: 60)]);
      model.startTask(model.tasks.single.id);
      await tester.pump();

      await _openItem(tester, 'Write spec');
      expect(find.text('Start'), findsNothing);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(model.tasks.single.status, TaskStatus.notStarted);
      expect(model.tasks.single.startedAt, isNull);
      expect(find.text('Paused "Write spec"'), findsOneWidget);
      model.dispose();
    });

    testWidgets('a not-started item has no Pause; delete is at the top', (
      tester,
    ) async {
      var model = await _app(tester, [_task('Tidy desk')]);
      await _openItem(tester, 'Tidy desk');
      expect(find.text('Pause'), findsNothing);
      expect(find.byTooltip('Delete'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(model.tasks, isEmpty);
      model.dispose();
    });

    testWidgets('closing a sheet does not bring the keyboard back', (
      tester,
    ) async {
      final model = await _app(tester, [_task('Tidy desk')]);
      // The add field had focus (e.g. something was just typed).
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.widget, isNotNull);

      await _openItem(tester, 'Tidy desk');
      await tester.tapAt(const Offset(10, 10)); // outside: closes the sheet
      await tester.pumpAndSettle();
      expect(find.text('Item'), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      model.dispose();
    });

    testWidgets('Pick a day… opens a date picker; cancel leaves it be', (
      tester,
    ) async {
      final model = await _app(tester, [_task('Tidy desk')]);
      await _openItem(tester, 'Tidy desk');
      await tester.tap(find.text('Pick a day…'));
      await tester.pumpAndSettle();
      expect(find.text('Move to'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(model.tasks.single.title, 'Tidy desk');
      model.dispose();
    });
  });

  testWidgets('a short block next to a meeting shows its title, no overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ScheduledTask at(Task t, int h, int m) => ScheduledTask(
      task: t,
      computedStartTime: TimeOfDay(hour: h, minute: m),
    );
    await tester.pumpWidget(
      _host(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ScheduleTimeline(
            entries: [
              at(
                _task(
                  'Work',
                  type: TaskType.hard,
                  at: const TimeOfDay(hour: 9, minute: 0),
                  minutes: 450,
                ),
                9,
                0,
              ),
              at(
                Task(
                  title: 'Server alert',
                  durationMinutes: 15,
                  type: TaskType.floating,
                  status: TaskStatus.inProgress,
                  startedAt: DateTime(2030, 1, 7, 14, 6),
                  date: _day,
                ),
                14,
                6,
              ),
            ],
            current: null,
            dayStartHour: 8,
            dayEndHour: 18,
            isToday: false,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final title = tester.getSize(find.text('Server alert'));
    expect(title.width, greaterThan(20));
  });
}
