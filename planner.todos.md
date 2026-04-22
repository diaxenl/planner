# HyperDay — Phase Tracker

This file tracks implementation progress across all phases. Subsequent agents should read this file to determine where to pick up.

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
- [ ] Define `TaskType` and `Priority` enums
- [ ] Implement immutable `Task` class with `final` fields and `copyWith`
- [ ] Implement ID generation (16-char hex via `Random.secure()`)
- [ ] Define `ScheduledTask` wrapper class
- [ ] Implement `DayPlannerModel extends ChangeNotifier` with CRUD methods
- [ ] Add overlap validation in `addTask` / `updateTask` for hard/pinned tasks
- [ ] Wire `InheritedNotifier<DayPlannerModel>` above `MaterialApp`

## Phase 3 — Task UI: Create, Edit & Remove
- [ ] Build add/edit task bottom sheet (title, duration, type toggle, time picker, priority)
- [ ] Add input validation (title 1–100 chars, duration 5–480 min, start time in window, overlap check)
- [ ] Connect FAB to open add-task bottom sheet
- [ ] Build task card widget (title, time range, duration, priority badge, type icon)
- [ ] Add hard task visual treatment (lock icon, tint)
- [ ] Add tap-to-edit on task cards
- [ ] Add swipe-to-delete with undo SnackBar
- [ ] Render hard/pinned tasks at fixed positions on timeline
- [ ] Render floating tasks in "Unscheduled" section below timeline

## Phase 4 — Scheduling Engine
- [ ] Implement `schedule()` pure function (greedy slot-fill algorithm)
- [ ] Handle fixed block extraction (hard + pinned + completed tasks)
- [ ] Compute free gaps within day window
- [ ] Sort floating tasks by priority desc, duration asc
- [ ] Assign floating tasks to earliest fitting gap
- [ ] Return `DaySchedule` with `committed` and `overflow` lists
- [ ] Integrate scheduler into `DayPlannerModel` with performance guard (skip title-only edits)
- [ ] Move floating tasks from "Unscheduled" section onto timeline at computed positions
- [ ] Show overflow tasks at bottom with warning badge

## Phase 5 — Complete & Smart Suggest
- [ ] Add complete button (check icon) to task cards
- [ ] Implement `markComplete` — freeze completed task as fixed block
- [ ] Run scheduler on remaining incomplete floating tasks after completion
- [ ] Generate `ScheduleSuggestion` diff (task, oldStart, newStart)
- [ ] Build `SuggestionBanner` UI below day header (summary + Accept/Dismiss)
- [ ] Wire Accept → commit proposed schedule
- [ ] Wire Dismiss → discard proposal
- [ ] Handle pinned task suggestions with "(pinned)" label

## Phase 6 — Persistence
- [ ] Add `path_provider` to `pubspec.yaml`
- [ ] Define `DayRepository` abstract interface
- [ ] Implement `LocalDayRepository` (JSON read/write in `hyperday/` subdirectory)
- [ ] Implement `Task.toJson()` / `Task.fromJson()`
- [ ] Implement atomic writes (write to `.tmp`, then rename)
- [ ] Implement debounced saves (500ms) in `DayPlannerModel`
- [ ] Implement immediate save on `AppLifecycleState.paused`
- [ ] Add corrupt file handling (rename to `.corrupt`, return empty list)
- [ ] Wire `DayPlannerModel` to load from repository on init

## Phase 7 — Multi-day & Carry-forward
- [ ] Make prev/next day header buttons functional
- [ ] Implement `setViewedDate` (save if dirty, then load new date)
- [ ] Implement carry-forward: scan previous day for incomplete non-hard tasks
- [ ] Set `carriedFromDate` on carried tasks
- [ ] Add idempotency check (skip if already carried)
- [ ] Display "Carried from [date]" label on carried task cards

---

**Current status:** Phase 1 complete — begin with Phase 2.
