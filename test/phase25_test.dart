import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app.dart';
import 'package:planner/features/day/widgets/capture_bar.dart';
import 'package:planner/features/day/widgets/item_sheet.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/capture_parser.dart';
import 'package:planner/services/scheduler.dart';
import 'package:planner/state/day_planner_model.dart';
import 'package:planner/state/day_planner_provider.dart';
import 'package:planner/state/settings_model.dart';
import 'package:planner/state/settings_provider.dart';

final _day = DateTime(2026, 11, 24);

Task _meeting(String title, int h, int m, int minutes) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.hard,
  startTime: TimeOfDay(hour: h, minute: m),
  date: _day,
);

Task _outcome(String title, int minutes) => Task(
  title: title,
  durationMinutes: minutes,
  type: TaskType.floating,
  isOutcome: true,
  date: _day,
);

String _clock(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

void main() {
  group('Outcomes fill the earliest free time', () {
    test('a 30m window before a meeting is used by splitting an Outcome', () {
      final pmn = _outcome('Finish PMN', 60);
      final qa = _outcome('QA item', 60);
      final swarms = _outcome('Check swarms', 45);
      final s = Scheduler.schedule(
        [
          pmn,
          qa,
          _meeting('New AI tool', 9, 30, 30),
          swarms,
          _meeting('1 on 1', 11, 0, 30),
        ],
        dayStartHour: 8,
        dayEndHour: 18,
        nowMinutes: 7 * 60 + 30,
      );
      String plan(Task t) => [
        for (final st in s.committed.where((st) => st.task.id == t.id))
          '${_clock(st.startMinutes)}-${_clock(st.endMinutes)}',
      ].join(', ');

      expect(plan(pmn), '8:00-9:00');
      expect(plan(qa), '9:00-9:30, 10:00-10:30');
      expect(plan(swarms), '10:30-11:00, 11:30-11:45');
      expect(s.overflow, isEmpty);
      expect(s.unplanned, isEmpty);
    });
  });

  group('Capture: meetings in plain language', () {
    ParsedCapture parse(String raw) =>
        CaptureParser.parse(raw, today: _day, workdayStartHour: 8);

    test('a meeting word first and a time make a Meeting', () {
      final p = parse('Meeting - new AI tool 9:30');
      expect(p.isMeeting, isTrue);
      expect(p.title, 'Meeting - new AI tool');
      expect(p.startTime, const TimeOfDay(hour: 9, minute: 30));
      expect(parse('Call with Bob at 2pm').isMeeting, isTrue);
      expect(parse('mtg: budget 3pm 45m').isMeeting, isTrue);
      expect(parse('1:1 Priya at 11').isMeeting, isTrue);
      expect(parse('Meeting - 1 on 1 at 11').isMeeting, isTrue);
      expect(parse('1 on 1 with Sam 2pm').isMeeting, isTrue);
    });

    test('no time, or the word not first: not a Meeting', () {
      expect(parse('Meeting notes').isMeeting, isFalse);
      expect(parse('Prep for meeting at 2pm').isMeeting, isFalse);
      expect(parse('Recall the order 3pm').isMeeting, isFalse);
    });
  });

  group('Capture: "45 min" with a space', () {
    test('a number then a unit word is a duration', () {
      final p = CaptureParser.parse('check new swarms 45 min');
      expect(p.title, 'check new swarms');
      expect(p.durationMinutes, 45);
      expect(CaptureParser.parse('Deck 2 hours *').durationMinutes, 120);
      expect(CaptureParser.parse('Deck 1.5 hrs').durationMinutes, 90);
      expect(CaptureParser.parse('Read 3 chapters').durationMinutes, isNull);
    });
  });

  testWidgets('closing the item sheet leaves the keyboard down', (
    tester,
  ) async {
    final model = DayPlannerModel();
    await tester.pumpWidget(
      SettingsProvider(
        model: SettingsModel(),
        child: DayPlannerProvider(model: model, child: const HyperDayApp()),
      ),
    );
    final field = find.descendant(
      of: find.byType(CaptureBar),
      matching: find.byType(TextField),
    );
    await tester.tap(field);
    await tester.pump();
    bool focused() => tester.widget<TextField>(field).focusNode!.hasFocus;
    expect(focused(), isTrue);

    final context = tester.element(find.byType(CaptureBar));
    ItemSheet.show(
      context,
      model: model,
      draft: Task(
        title: 'x',
        durationMinutes: 30,
        type: TaskType.floating,
        date: model.viewedDate,
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ItemSheet))).pop();
    await tester.pumpAndSettle();

    expect(focused(), isFalse);
    model.dispose();
  });
}
