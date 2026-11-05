# HyperDay — Phase Tracker

This file tracks implementation progress across all phases. Subsequent agents should read this file to determine where to pick up. Product vision, scope boundaries, and rationale live in [plan-hyperDay.prompt.md](plan-hyperDay.prompt.md) — this file is the actionable checklist only; do not duplicate design rationale here.

**Phases 1–9 are complete** and form the engine that the rebuild keeps. **Phases 10–15 are the Outcome-First rebuild.** The old Phases 10–13 (Live Tracking UI, Focus Now Screen, NL Quick Capture, Estimate Accuracy) are superseded and folded into the new phases below.

Every phase ends with a validation step: `flutter analyze` clean, `flutter test` green, and a review of the running app. Do not start the next phase until that is done.

---

## Completed — Engine (Phases 1–9)

Summarized; see git history for the full itemized checklists.

- **Architecture:** hybrid folders (`core/`, `models/`, `state/`, `services/`, `features/`), `main.dart` → `app.dart`.
- **Phases 1–3 — Shell & tasks:** theme tokens, day window constants, timeline screen, task CRUD via bottom sheet, input validation, swipe-to-delete with undo.
- **Phase 4 — Scheduler:** pure greedy `Scheduler.schedule()` → `DaySchedule` (`committed` + `overflow`).
- **Phase 5 — Complete & suggest:** `ScheduleSuggestion` diff, Accept/Dismiss banner.
- **Phase 6 — Persistence:** `DayRepository` / `LocalDayRepository`, JSON per day, atomic writes, 500 ms debounced saves, save on pause, corrupt-file handling.
- **Phase 7 — Multi-day:** prev/next navigation, automatic carry-forward (to be replaced in Phase 15).
- **Phase 8 — Status model:** `TaskStatus`, `startedAt`, `actualDurationMinutes`; in-progress tasks are fixed blocks.
- **Phase 9 — Adaptive replanning:** start/cancel/complete, suggestion diff on every mutation, overrun detection with periodic check.
  - Fix (2026-11-05): Dismiss now holds displaced tasks at their prior positions; the periodic overrun check no longer wipes a pending suggestion; in-progress tasks are excluded from suggestions.

---

## Phase 10 — Model & Engine Simplification
- [x] Remove `Priority` enum and `Task.priority`
- [x] Add `Task.isOutcome` (`bool`, default `false`) and `Task.isInterruption` (`bool`, default `false`); update `copyWith`, `toJson`, `fromJson`
- [x] Scheduler: order floating tasks by `isOutcome` desc, then duration asc (replaces priority ordering)
- [x] `DayPlannerModel`: enforce an outcome cap per day (`outcomeCap`, default 3) on add/update (throw `ArgumentError` with a clear message)
- [x] `DayPlannerModel`: include `isOutcome` in `_scheduleFieldsChanged`
- [x] Remove automatic carry-forward from `setViewedDate` (replaced by explicit Tomorrow/Drop in Phase 15); keep `carriedFromDate`
- [x] Add `DayPlannerModel.moveToDate(id, date)` — removes the task from the current day and appends it (new date, same fields, `carriedFromDate` set) to the target day's file
- [x] Update existing tests for the removed priority; add tests for outcome ordering, outcome cap, `moveToDate`
- [x] Validation: analyze clean, tests green (UI may be temporarily broken where it referenced priority — fix minimally, it is deleted in Phase 11)

## Phase 11 — Design System & App Shell
- [x] Bundle one OFL font (e.g. Inter) under `assets/fonts/` and register it in `pubspec.yaml` `fonts:` (asset only — no package)
- [x] Rewrite `core/theme.dart`: dark + light `ThemeData` from tokens; one accent color; neutral surfaces; hairline dividers; no elevation; tabular-figure numeral style
- [x] Add `SettingsRepository` (`hyperday/settings.json`, atomic write) and `SettingsModel` (`themeMode`: dark default / light / system; `outcomeCap`: default 3, range 1–5; `selectedCalendarIds`)
- [x] Wire `SettingsModel` into `main.dart` / `app.dart` (`themeMode`, dark default)
- [x] Delete `lib/features/day_view/` entirely
- [x] Create `features/day/day_screen.dart` skeleton: date header with prev/next, empty sections for load bar / Now / Outcomes / Agenda, bottom capture-bar placeholder
- [x] Create `features/settings/settings_screen.dart` with theme selector and outcome cap (calendar section added in Phase 14); wire `outcomeCap` into `DayPlannerModel`; reachable from Day header
- [x] Replace widget smoke test with one for the new `DayScreen`
- [x] Validation: review dark and light themes in the running app

## Phase 12 — Day Screen
- [ ] `services/day_stats.dart`: pure `loadBreakdown(schedule, now)` → minutes of Meetings / Outcomes / Other / Free across the remaining day window
- [ ] `widgets/load_bar.dart`: single segmented bar from `loadBreakdown`, with a compact legend
- [ ] `DayPlannerModel.currentItem` getter: in-progress task, else committed task whose window contains now, else next upcoming (pure function of schedule + now)
- [ ] `widgets/now_card.dart`: title, large live timer (elapsed when in progress, "starts in" otherwise), Start / Done / Cancel gated by status rules; overrun state in accent warning color; hidden when not viewing today
- [ ] `widgets/outcomes_list.dart`: outcomes up to the cap with check state; empty prompt "What would make today a win?"
- [ ] `widgets/agenda_list.dart`: remaining committed items, one line each (time · title · duration); meetings visually muted; completed/cancelled shown muted/struck; overflow section at end with "Outcome doesn't fit today" callout when applicable
- [ ] `widgets/suggestion_banner.dart`: restyled; same Accept/Dismiss wiring
- [ ] `widgets/item_sheet.dart`: title, duration, kind (Meeting / At a set time / Anytime), time picker when needed, Outcome toggle; same validation rules; delete action
- [ ] Tap any agenda/outcome item to open the item sheet
- [ ] Tests: `loadBreakdown`, `currentItem`
- [ ] Validation: review full Day screen in the running app (phone-sized)

## Phase 13 — Capture & Triage
- [ ] `services/capture_parser.dart`: parse duration (`30m`, `1h`, `1h30m`; default 30m), time (`3pm`, `15:00` → At a set time), `*` → Outcome; remainder is the title
- [ ] `widgets/capture_bar.dart`: pinned bottom text field; submit opens `item_sheet` pre-filled with the parsed draft (never saves directly)
- [ ] "Something came up" button beside the capture bar → enter text → choose **Now** (add + start immediately) / **Later today** (Anytime) / **Tomorrow** (`moveToDate`); sets `isInterruption = true`
- [ ] Tests: parser cases (each token alone, combined, none, edge cases like `1h30m`, `12pm`, `00:30` outside window)
- [ ] Validation: review capture + interruption flows in the running app

## Phase 14 — Calendar Import
- [ ] **Prerequisite:** Android SDK installed and `flutter doctor` Android toolchain green
- [ ] **Stop and confirm with the owner** the exact calendar package and version (candidate: `device_calendar`) before touching `pubspec.yaml`
- [ ] Add the confirmed package; add Android calendar read permission (and iOS usage description)
- [ ] `models/calendar_event.dart`: read-only (id, calendarId, title, start, end, isAllDay)
- [ ] `services/calendar_source.dart`: `CalendarSource` interface (`listCalendars()`, `eventsFor(date, calendarIds)`); `DeviceCalendarSource`; `NoCalendarSource` for desktop/web/tests
- [ ] Request permission on first use with a plain explanation; handle denial gracefully (app works without calendars)
- [ ] `DayPlannerModel`: load events for the viewed date on load / refresh / day change; convert timed events to fixed Meeting blocks for the scheduler only (not persisted); skip declined events where exposed
- [ ] Overlap validation includes imported meetings
- [ ] All-day events shown as a one-line label under the date header
- [ ] Pull-to-refresh on the Day screen re-reads events
- [ ] Settings: calendar picker (all selected by default) + note about syncing accounts to the phone
- [ ] Tests: event → fixed-block conversion and overlap validation using a fake `CalendarSource`
- [ ] Validation: on a real Android device with Google, Microsoft, and iCloud accounts synced

## Phase 15 — End-of-Day Review
- [ ] `day_stats.dart`: `timeSplit(tasks, schedule)` → planned vs actual minutes for Meetings / Outcomes / Other / Interruptions; `estimateAccuracy(tasks)` → % over/under (excludes cancelled and zero-tracked tasks); `outcomesHit(tasks)`
- [ ] `features/review/review_screen.dart`: outcomes hit (e.g. 2 / 3), time split bars, accuracy line
- [ ] Unfinished items list: each resolved via **Tomorrow** (`moveToDate`) or **Drop** (cancel)
- [ ] Entry point from the Day screen (always available; emphasized after the last committed item ends)
- [ ] Tests: `timeSplit`, `estimateAccuracy`, `outcomesHit`
- [ ] Validation: review a full simulated day end-to-end in the running app

---

**Current status:** Engine (Phases 1–9) complete, including the 2026-11-05 Phase 9 fixes. Phases 10–11 complete. **Next: Phase 12.**
