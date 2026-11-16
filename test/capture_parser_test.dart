import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/services/capture_parser.dart';

void main() {
  group('Phase 13 — CaptureParser', () {
    test('plain title only', () {
      final p = CaptureParser.parse('  Reply to board  ');
      expect(p.title, 'Reply to board');
      expect(p.durationMinutes, isNull);
      expect(p.startTime, isNull);
      expect(p.isOutcome, isFalse);
    });

    test('all tokens combined', () {
      final p = CaptureParser.parse('Call Bob 20m 3pm *');
      expect(p.title, 'Call Bob');
      expect(p.durationMinutes, 20);
      expect(p.startTime, const TimeOfDay(hour: 15, minute: 0));
      expect(p.isOutcome, isTrue);
    });

    test('duration forms', () {
      expect(CaptureParser.parse('x 45m').durationMinutes, 45);
      expect(CaptureParser.parse('x 45min').durationMinutes, 45);
      expect(CaptureParser.parse('x 1h').durationMinutes, 60);
      expect(CaptureParser.parse('x 2hrs').durationMinutes, 120);
      expect(CaptureParser.parse('x 1h30m').durationMinutes, 90);
      expect(CaptureParser.parse('x 1.5h').durationMinutes, 90);
    });

    test('time forms; "at" is dropped', () {
      expect(CaptureParser.parse('x 3:30pm').startTime,
          const TimeOfDay(hour: 15, minute: 30));
      expect(CaptureParser.parse('x 15:00').startTime,
          const TimeOfDay(hour: 15, minute: 0));
      expect(CaptureParser.parse('x 12pm').startTime,
          const TimeOfDay(hour: 12, minute: 0));
      expect(CaptureParser.parse('x 12am').startTime,
          const TimeOfDay(hour: 0, minute: 0));
      final p = CaptureParser.parse('Lunch at 1pm');
      expect(p.title, 'Lunch');
      expect(p.startTime, const TimeOfDay(hour: 13, minute: 0));
    });

    test('outcome star attached to a word', () {
      final p = CaptureParser.parse('Ship the memo*');
      expect(p.title, 'Ship the memo');
      expect(p.isOutcome, isTrue);
    });

    test('non-tokens stay in the title; first of each kind wins', () {
      final p = CaptureParser.parse('Q1 plan for 3 teams 30m 1h 25:00 13pm');
      expect(p.title, 'Q1 plan for 3 teams 1h 25:00 13pm');
      expect(p.durationMinutes, 30);
      expect(p.startTime, isNull);
    });

    test('out-of-window values are parsed, not validated', () {
      expect(CaptureParser.parse('x 00:30').startTime,
          const TimeOfDay(hour: 0, minute: 30));
      expect(CaptureParser.parse('x 600m').durationMinutes, 600);
    });
  });
}
