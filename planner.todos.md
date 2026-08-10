# HyperDay — Phase Tracker

This file tracks implementation progress across all phases. Subsequent agents should read this file to determine where to pick up. Product vision and detailed rationale for Phases 8+ live in [plan-hyperDay.prompt.md](plan-hyperDay.prompt.md) — this file is the actionable checklist only; do not duplicate design rationale here.

**Phases 1–7 below are the completed v1 foundation** (static timeline planner). **Phases 8–13 are the new Adaptive Focus Planner overhaul** — see the PRD for why each phase exists.

---

## Architecture — Folder Structure
- [x] Establish hybrid folder architecture (core/, models/, state/, services/, features/)
- [x] Create `lib/main.dart` — minimal entry point (`runApp()` only)
- [x] Create `lib/app.dart` — `HyperDayApp` widget (MaterialApp config)
- [x] Create `lib/core/theme.dart` — `AppTheme` (colors, text styles, ThemeData)
- [x] Create `lib/core/constants.dart` — `AppConstants` (day window, dimensions, validation bounds)
- [x] Create `lib/core/utils.dart` — `AppUtils` (time↔pixel mapping, date formatting)
- [x] Move day_view widgets into `lib/features/day_view/`
- [x] Remove old `lib/screens/` and `lib/theme.dart`
- [x] Update test import to reference `app.dart`

## Phase 1 — Visual Shell
- [x] Configure `MaterialApp` with app-wide theme (color scheme, typography, light mode)
- [x] Create `AppTheme` class with design tokens (colors, text styles, spacing constants)
- [x] Define day window constant (6 AM – 11 PM) and hour pixel height constant
- [x] Build `DayScreen` with day header (date display + placeholder prev/next buttons)
- [x] Build timeline scaffold with slot-based absolute positioning (`Stack` + `Positioned`)
- [x] Add hour marker labels and horizontal dividers
- [x] Add empty state overlay ("No tasks yet — tap + to get started")
- [x] Add FAB placeholder (`+` icon, non-functional)

## Phase 2 — Task Data Model & State
- [x] Define `TaskType` and `Priority` enums
- [x] Implement immutable `Task` class with `final` fields and `copyWith`
- [x] Implement ID generation (16-char hex via `Random.secure()`)
- [x] Define `ScheduledTask` wrapper class
- [x] Implement `DayPlannerModel extends ChangeNotifier` with CRUD methods
- [x] Add overlap validation in `addTask` / `updateTask` for hard/pinned tasks
- [x] Wire `InheritedNotifier<DayPlannerModel>` above `MaterialApp`

## Phase 3 — Task UI: Create, Edit & Remove
- [x] Build add/edit task bottom sheet (title, duration, type toggle, time picker, priority)
- [x] Add input validation (title 1–100 chars, duration 5–480 min, start time in window, overlap check)
- [x] Connect FAB to open add-task bottom sheet
- [x] Build task card widget (title, time range, duration, priority badge, type icon)
- [x] Add hard task visual treatment (lock icon, tint)
- [x] Add tap-to-edit on task cards
- [x] Add swipe-to-delete with undo SnackBar
- [x] Render hard/pinned tasks at fixed positions on timeline
- [x] Render floating tasks in "Unscheduled" section below timeline

## Phase 4 — Scheduling Engine
- [x] Implement `schedule()` pure function (greedy slot-fill algorithm)
- [x] Handle fixed block extraction (hard + pinned + completed tasks)
- [x] Compute free gaps within day window
- [x] Sort floating tasks by priority desc, duration asc
- [x] Assign floating tasks to earliest fitting gap
- [x] Return `DaySchedule` with `committed` and `overflow` lists
- [x] Integrate scheduler into `DayPlannerModel` with performance guard (skip title-only edits)
- [x] Move floating tasks from "Unscheduled" section onto timeline at computed positions
- [x] Show overflow tasks at bottom with warning badge

## Phase 5 — Complete & Smart Suggest
- [x] Add complete button (check icon) to task cards
- [x] Implement `markComplete` — freeze completed task as fixed block
- [x] Run scheduler on remaining incomplete floating tasks after completion
- [x] Generate `ScheduleSuggestion` diff (task, oldStart, newStart)
- [x] Build `SuggestionBanner` UI below day header (summary + Accept/Dismiss)
- [x] Wire Accept → commit proposed schedule
- [x] Wire Dismiss → discard proposal
- [x] Handle pinned task suggestions with "(pinned)" label

## Phase 6 — Persistence
- [x] Add `path_provider` to `pubspec.yaml`
- [x] Define `DayRepository` abstract interface
- [x] Implement `LocalDayRepository` (JSON read/write in `hyperday/` subdirectory)
- [x] Implement `Task.toJson()` / `Task.fromJson()`
- [x] Implement atomic writes (write to `.tmp`, then rename)
- [x] Implement debounced saves (500ms) in `DayPlannerModel`
- [x] Implement immediate save on `AppLifecycleState.paused`
- [x] Add corrupt file handling (rename to `.corrupt`, return empty list)
- [x] Wire `DayPlannerModel` to load from repository on init

## Phase 7 — Multi-day & Carry-forward
- [x] Make prev/next day header buttons functional
- [x] Implement `setViewedDate` (save if dirty, then load new date)
- [x] Implement carry-forward: scan previous day for incomplete non-hard tasks
- [x] Set `carriedFromDate` on carried tasks
- [x] Add idempotency check (skip if already carried)
- [x] Display "Carried from [date]" label on carried task cards

---

## Phase 8 — Data Model & State Overhaul
- [ ] Add `TaskStatus` enum (`notStarted`, `inProgress`, `complete`, `cancelled`) to `models/task.dart`
- [ ] Replace `Task.isComplete` (bool) with `Task.status` (`TaskStatus`); keep `completedAt`
- [ ] Add `Task.startedAt` (`DateTime?`) and `Task.actualDurationMinutes` (`int?`)
- [ ] Update `Task.copyWith`, `toJson`, `fromJson` for the new fields/enum
- [ ] Update every `isComplete` read/write site across `state/`, `services/`, `features/` to use `status`
- [ ] Update `Scheduler.schedule()`: treat `inProgress` tasks as fixed blocks (like hard tasks); `cancelled` tasks are excluded like completed ones
- [ ] Update `_scheduleFieldsChanged` in `DayPlannerModel` to include `status`/`startedAt` transitions

## Phase 9 — Adaptive Replanning Everywhere
- [ ] Add `DayPlannerModel.startTask(id)` — sets `status = inProgress`, `startedAt = now`, reschedules
- [ ] Add `DayPlannerModel.cancelTask(id)` — sets `status = cancelled`, reschedules
- [ ] Update `markComplete` — compute `actualDurationMinutes` from `startedAt`/`completedAt` (fallback: `startedAt = completedAt` if never started)
- [ ] Extend suggestion-diff generation (currently only in `markComplete`) to run after `addTask`, `updateTask`, `removeTask`, `startTask`, `cancelTask`
- [ ] Define "silent vs. suggested" rule: auto-commit reschedules that don't move an already-committed task or change overflow membership; otherwise populate `_suggestion` for the banner
- [ ] Add overrun detection: while a task is `inProgress` and elapsed time (`now - startedAt`) exceeds `durationMinutes`, mark it overrunning and reschedule using elapsed time as the effective duration for downstream placement
- [ ] Add a lightweight recurring check (e.g. periodic `Timer` while an `inProgress` task exists) to detect overruns without requiring a user action

## Phase 10 — Live Time Tracking UI
- [ ] Add Start / Complete / Cancel actions to `TaskCard` (replacing the single complete-only check icon), gated by allowed status transitions
- [ ] Add a live elapsed-time readout on the `inProgress` task's card (ticking label, e.g. "12m elapsed")
- [ ] Add a visual overrun state (color/border change) once elapsed time exceeds the estimate
- [ ] Add a variance badge on completed cards: "Est 30m · Actual 42m (+12m)"
- [ ] Add a "Cancelled" visual treatment (struck-through, muted) distinct from "Complete"

## Phase 11 — Focus Now Screen
- [ ] Create `lib/features/focus/focus_screen.dart` — new primary screen
- [ ] Implement "current task" selection: `inProgress` task if any, else the committed task whose window contains now, else the next upcoming committed task
- [ ] Create `widgets/focus_card.dart` — current task detail, live timer, Start/Complete/Cancel controls
- [ ] Create `widgets/up_next_strip.dart` — preview of the next 1–2 committed tasks
- [ ] Create `widgets/day_health_chip.dart` — comfortable/tight/overloaded indicator from remaining committed + overflow duration vs. remaining day window
- [ ] Add a nav affordance from Focus Screen to the existing Timeline (`DayScreen`) view and back
- [ ] Update `app.dart` — `home:` becomes `FocusScreen` (was `DayScreen`)

## Phase 12 — Natural-Language Quick Capture
- [ ] Create `lib/services/task_text_parser.dart` — pure Dart parser, no new dependency
- [ ] Parse duration shorthand (`30m`, `1h`, `1h30m`), clock time (`3pm`, `15:00` → pinned type), explicit lock markers (`!!`, `locked` → hard type), priority markers (`!`, `high`, `low`)
- [ ] Apply smart defaults for unparsed fields (duration 30 min if floating, priority medium)
- [ ] Create `widgets/quick_capture_bar.dart` — free-text field that opens the existing `TaskBottomSheet` pre-filled with parsed fields as a confirmation/adjustment step before saving
- [ ] Add a "Something came up" shortcut that opens the same quick-capture flow pre-set to high priority
- [ ] Wire quick capture entry points into the Focus Screen

## Phase 13 — Estimate Accuracy Surfacing
- [ ] Add per-task variance display on completed `TaskCard`s (reuses data added in Phase 10)
- [ ] Add a `DayPlannerModel` getter for a same-day aggregate accuracy stat (e.g. average overrun % across today's completed tasks, excluding cancelled)
- [ ] Surface the aggregate stat subtly on the Focus Screen (e.g. small footer text)

---

**Current status:** Phase 7 (v1 foundation) complete. Phases 8–13 (Adaptive Focus Planner overhaul) not started — see [plan-hyperDay.prompt.md](plan-hyperDay.prompt.md) for the full product spec.
