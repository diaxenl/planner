import 'package:flutter_test/flutter_test.dart';

import 'package:planner/models/task.dart';
import 'package:planner/state/day_planner_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'work refilled after a finish is never planned before the finish',
    () async {
      final model = DayPlannerModel();
      await model.loadDate(DateTime.now());
      model.setWorkday(0, 24); // plan floating work at any hour the test runs

      final done = Task(
        title: 'Done early',
        durationMinutes: 30,
        type: TaskType.floating,
        date: model.viewedDate,
      );
      final next = Task(
        title: 'Next',
        durationMinutes: 5,
        type: TaskType.floating,
        date: model.viewedDate,
      );
      model
        ..addTask(done)
        ..addTask(next);
      final finishedAt = DateTime.now();
      model.markComplete(done.id, finishedAt);

      final planned = model.schedule.committed
          .where((st) => st.task.id == next.id)
          .toList();
      if (planned.isEmpty) return; // too close to midnight to fit
      // Previously "now" was floored to 5 minutes, so at 8:12 this was 8:10.
      expect(
        planned.first.startMinutes,
        greaterThanOrEqualTo(finishedAt.hour * 60 + finishedAt.minute),
      );
    },
  );
}
