# PRD: HyperDay — Flutter Day Planner

**Vision:** A focused, single-screen productivity app that turns your day into an optimized, living schedule. Tasks are placed on a timeline and the app intelligently suggests reschedules when reality diverges from the plan.

---

## Core Concepts

**Task types:**
- **Hard tasks** — immovable anchors (meetings, appointments). Have a fixed start time and duration. The scheduler will never touch these.
- **Pinned tasks** — user-set start time but no hard constraint. The scheduler *may* suggest moving them if there is a conflict, but will warn.
- **Floating tasks** — have only a duration and priority. The scheduler slots them into available gaps around hard/pinned tasks.

**Task fields:** Title (required, max 100 chars), Duration in minutes (required, 5–480 min), Start time (optional — makes task pinned; must fall within the day window), Hard/immovable flag, Priority (Low / Medium / High).

**Smart suggest:** When a task is marked complete (early or late), the app computes a revised schedule for all remaining floating tasks in the day and presents a non-intrusive suggestion banner. The user taps Accept or Dismiss. Hard tasks are never moved in any suggestion.

**Day view:** The primary screen is a scrollable vertical timeline for the current day (e.g. 6 AM – 11 PM). Each hour occupies a fixed pixel height. Today is always the default; users can navigate day-to-day. Incomplete tasks from past days are shown as carry-forwards.

**Persistence:** JSON on-device storage via `dart:io` + `path_provider` (approved first-party Flutter package). Architecture uses a repository interface to make a future cloud backend swappable.

---

## Approved Dependencies

Beyond the default Flutter SDK dependencies already in `pubspec.yaml`:
- **`path_provider`** — required to locate the app documents directory on Android/iOS. First-party Flutter package. Added in Phase 6.

No other packages may be added without explicit approval.

---

## Input Validation Rules

These apply globally across all phases that accept user input:
- **Title:** required, 1–100 characters, trimmed of leading/trailing whitespace.
- **Duration:** required, integer, 5–480 minutes (8 hours max). Values outside this range are rejected with an inline error.
- **Start time:** must fall within the day window (default 6:00 AM – 11:00 PM). The task's end time (start + duration) must also fall within the window.
- **Overlap detection:** when creating or editing a hard or pinned task, reject if it overlaps with any existing hard task. Show an inline error identifying the conflicting task.

---

## Phase Summary

| # | Phase | Goal |
|---|-------|------|
| 1 | **Visual Shell** | App theme, day timeline scaffold (slot-based positioning), empty state, day navigation header |
| 2 | **Task Data Model & State** | Immutable `Task` model with `copyWith`, `ScheduledTask` wrapper, state management (`ChangeNotifier` + `InheritedNotifier`), in-memory CRUD |
| 3 | **Task UI — Create, Edit & Remove** | Add/edit task bottom sheet (with validation), task cards on timeline, swipe-to-delete, overlap detection for hard/pinned tasks |
| 4 | **Scheduling Engine** | Pure Dart algorithm: slots floating tasks into gaps between hard/pinned tasks; detects conflicts; returns an ordered `DaySchedule` |
| 5 | **Complete & Smart Suggest** | Mark task complete (with actual end time), trigger forward-only reschedule diff, show accept/dismiss suggestion card |
| 6 | **Persistence** | `dart:io` + `path_provider` JSON file per day; atomic writes; debounced saves; repository pattern |
| 7 | **Multi-day & Carry-forward** | Day navigation (prev/next), idempotent carry-forward of incomplete tasks from previous day |

---

## Key Architectural Decisions

- **State management:** `ChangeNotifier` + `ListenableBuilder` (no new packages). `InheritedNotifier` placed above `MaterialApp` so `DayPlannerModel` persists across navigation and day switches. Repository interface isolates storage concerns.
- **Immutable model:** `Task` is immutable with `final` fields and a `copyWith` method. All mutations go through `DayPlannerModel` methods that replace the task in the list and call `notifyListeners()`.
- **Scheduling algorithm:** Greedy slot-filling — sort floating tasks by priority, then insert them left-to-right into available gaps after hard tasks. Runs only when task times, durations, types, or completion status change (not on title-only edits).
- **Suggestion model:** A computed `ProposedSchedule` is held in state separately from the committed schedule. Accepted → becomes new state. Dismissed → discarded.
- **Storage:** One JSON file per calendar date (`yyyy-MM-dd.json`) in the app's documents directory. Writes use a temp-file-then-rename strategy for crash safety. Saves are debounced (500ms after last mutation) rather than on every change. `path_provider` locates the directory.
- **ID generation:** Task IDs use `Random.secure()` to produce a 16-character hex string. Sufficient entropy for local-only use with no collision risk in practice.

### Folder Architecture

```
lib/
  main.dart                              # runApp() only — minimal entry point
  app.dart                               # HyperDayApp (MaterialApp config)
  core/
    theme.dart                           # AppTheme — colors, text styles, ThemeData
    constants.dart                       # AppConstants — day window, dimensions, validation bounds
    utils.dart                           # AppUtils — time↔pixel mapping, date formatting
  models/
    task.dart                            # Task, TaskType, Priority (Phase 2)
    scheduled_task.dart                  # ScheduledTask wrapper (Phase 2)
    day_schedule.dart                    # DaySchedule output (Phase 4)
  state/
    day_planner_model.dart               # DayPlannerModel ChangeNotifier (Phase 2)
    day_planner_provider.dart            # InheritedNotifier + static .of() (Phase 2)
  services/
    scheduler.dart                       # Pure schedule() function (Phase 4)
    day_repository.dart                  # Abstract DayRepository (Phase 6)
    local_day_repository.dart            # JSON file implementation (Phase 6)
  features/
    day_view/
      day_screen.dart                    # Top-level screen — composes widgets
      timeline_view.dart                 # Scrollable Stack with hour rows
      widgets/
        day_header.dart                  # Date display + nav arrows
        empty_state_overlay.dart         # "No tasks yet" message
        task_card.dart                   # Individual task card (Phase 3)
        task_bottom_sheet.dart           # Add/edit form (Phase 3)
        suggestion_banner.dart           # Accept/dismiss reschedule (Phase 5)
        unscheduled_section.dart         # Floating tasks pre-scheduler (Phase 3)
```

**Principles:**
- `main.dart` does nothing but `runApp()` — all config in `app.dart`.
- `core/` has zero business logic — only shared design tokens, constants, and pure utilities.
- `models/` are plain Dart objects — no Flutter dependency beyond `TimeOfDay`.
- `state/` owns the ChangeNotifier and its InheritedNotifier wrapper.
- `services/` holds pure logic (scheduler) and I/O (repository) — no UI.
- `features/day_view/` groups all widgets for the day screen.

---

## Phase 1 — Visual Shell

**Goal:** A running app with the core visual framework in place — theme, timeline, empty state, and day navigation. No data, no logic.

### Deliverables
- `MaterialApp` configured with app-wide theme (color scheme, typography, light mode).
- `DayScreen` — primary screen with:
  - **Day header:** displays current date (e.g. "Tuesday, Apr 22"), with prev/next arrow buttons (non-functional placeholder until Phase 7).
  - **Timeline scaffold:** scrollable column covering a configurable time range (default 6 AM – 11 PM). Each hour has a **fixed pixel height** (code constant, not a user setting). Hour marker labels on the left edge with subtle horizontal dividers.
  - **Empty state:** overlay message centered on the timeline when no tasks exist ("No tasks yet — tap + to get started"). The timeline structure remains visible behind the overlay.
- Consistent spacing, padding constants, and a single `AppTheme` class to hold all design tokens (colors, text styles).
- **FAB placeholder:** a `FloatingActionButton` with a `+` icon, non-functional until Phase 3.

### Timeline architecture note
The timeline must use **slot-based absolute positioning** from the start (e.g. `Stack` with `Positioned` children based on time → pixel mapping). This is required so Phase 4's scheduled task placement works without restructuring the widget. Even though no tasks exist in Phase 1, the positioning infrastructure must be in place.

### Day window constant
The day window (6 AM – 11 PM) is a **code constant** defined in `AppTheme` or a dedicated constants file. There is no settings UI for this — it can be changed by editing the constant.

---

## Phase 2 — Task Data Model & State

**Goal:** Define the `Task` entity and wire up in-memory state management. No UI changes beyond the app responding to state.

### Data Model

```dart
enum TaskType { hard, pinned, floating }
enum Priority { low, medium, high }

class Task {
  final String id;              // 16-char hex via Random.secure()
  final String title;
  final int durationMinutes;
  final TaskType type;
  final TimeOfDay? startTime;   // required for hard & pinned; null for floating
  final Priority priority;
  final bool isComplete;
  final DateTime? completedAt;
  final DateTime date;          // calendar day this task belongs to
  final DateTime? carriedFromDate; // non-null if carried forward from another day

  Task copyWith({ ... });       // returns a new Task with specified fields changed
}
```

All fields are `final`. Mutations happen exclusively through `copyWith` + `DayPlannerModel` methods.

### ScheduledTask

```dart
class ScheduledTask {
  final Task task;
  final TimeOfDay computedStartTime;  // assigned by scheduler (or = task.startTime for hard/pinned)
  TimeOfDay get computedEndTime => ...; // computedStartTime + task.durationMinutes
}
```

This is a **read-only wrapper** used by the UI to render tasks at their computed positions. Defined in Phase 2 so Phase 3 can reference it, but populated by the scheduling engine in Phase 4.

### State
- `DayPlannerModel extends ChangeNotifier` — holds `List<Task>` for the currently viewed date, plus `DateTime viewedDate`.
- Methods: `addTask(Task)`, `removeTask(String id)`, `updateTask(String id, Task updated)`, `markComplete(String id, DateTime completedAt)`.
- `addTask` and `updateTask` enforce **overlap validation** for hard/pinned tasks: if the new/updated task's time range overlaps with an existing hard task, the method throws an `ArgumentError` (caught by the UI to show an error message).
- Provided to the widget tree via `InheritedNotifier<DayPlannerModel>` **above `MaterialApp`**.

---

## Phase 3 — Task UI: Create, Edit & Remove

**Goal:** Users can add and edit tasks via a bottom sheet and remove them with swipe-to-delete. Tasks appear as cards on the timeline.

### Add / Edit Task Bottom Sheet
Fields (in order):
1. Title (text field, required, max 100 chars — inline error if empty or too long)
2. Duration (numeric input, minutes, required, 5–480 — inline error if out of range)
3. Task type toggle: Floating / Pinned / Hard
4. Start time picker (shown only when type is Pinned or Hard; validated against day window and overlap)
5. Priority selector: Low / Medium / High (default Medium)

The same bottom sheet is used for both create and edit. When editing, fields are pre-populated from the existing task. The submit button reads "Add Task" or "Save Changes" accordingly.

### Task Card
- Displays: title, time range (computed), duration, priority badge, type indicator icon.
- Hard tasks: distinct visual treatment (e.g. lock icon, slightly different background tint).
- Tapping a card opens the edit bottom sheet.
- `Dismissible` widget for swipe-to-delete with an undo `SnackBar` (not a dialog — faster UX).

### Timeline placement (pre-scheduler)
- Hard and pinned tasks rendered at their fixed time positions using the slot-based positioning from Phase 1.
- Floating tasks rendered in a separate "Unscheduled" section below the timeline, as a simple vertical list. Each shows title, duration, and priority. These move onto the timeline in Phase 4.

---

## Phase 4 — Scheduling Engine

**Goal:** A pure-Dart, side-effect-free scheduling algorithm that produces an optimized `DaySchedule` from a list of tasks.

### Algorithm (Greedy Slot-fill)
1. Extract all hard + pinned tasks; sort by start time. These define fixed blocks. Completed tasks also occupy their scheduled time (they are not removed from the timeline).
2. Compute free gaps between fixed blocks (and before the first / after the last) within the day window.
3. Sort floating tasks by priority descending (High → Low), then by duration ascending as a tiebreaker.
4. Greedily fill gaps: assign each floating task to the earliest gap it fits in.
5. Any tasks that don't fit are marked as `overflow` (shown at bottom of timeline with a warning badge).

### Output
```dart
class DaySchedule {
  final List<ScheduledTask> committed;   // all placed tasks with computed startTime
  final List<Task> overflow;             // floating tasks that couldn't be placed
}
```

This runs as a pure function: `DaySchedule schedule(List<Task> tasks, DateTimeRange dayWindow)`.

### Performance guard
The scheduler is re-run only when a task is added, removed, or when its `type`, `startTime`, `durationMinutes`, `priority`, or `isComplete` fields change. Title-only edits do **not** trigger a reschedule.

---

## Phase 5 — Complete & Smart Suggest

**Goal:** Marking a task complete triggers a reschedule proposal. The user can accept or dismiss.

### Flow
1. User taps a check icon on a task card; actual completion time defaults to `DateTime.now()`.
2. The completed task is frozen in its current time slot (its time block is now treated as immovable, like a hard task, for scheduling purposes).
3. Run the scheduling algorithm on **all remaining incomplete floating tasks**, using the full day window. The completed task's block is simply a new fixed obstacle. Gaps are recomputed across the entire day.
4. Compare proposed schedule to the current committed schedule. If any floating task's computed start time changes, generate a `ScheduleSuggestion` containing a list of `(task, oldStart, newStart)` diffs.
5. Display a `SuggestionBanner` below the day header showing a summary (e.g. "3 tasks can shift earlier. Accept?") with Accept / Dismiss actions.
6. Accept → proposed schedule becomes the new committed state. Dismiss → discard, keep current positions.

### Rescheduling semantics
- The scheduler does **not** use a "cursor." It always considers the full day window. Completed tasks become fixed blocks just like hard tasks. This means if a task finishes early, the gap it freed up becomes available for any floating task, even one scheduled later in the day that could move earlier.
- Hard tasks are **never** included in a suggestion (they cannot move).
- Pinned tasks: if a completed task frees time that allows a pinned task's conflict to be resolved, the suggestion may include moving the pinned task back to its original pinned time. A "(pinned)" label distinguishes these in the suggestion UI.

---

## Phase 6 — Persistence

**Goal:** Tasks survive app restarts. One JSON file per calendar day.

### Dependency
Add `path_provider` to `pubspec.yaml` (approved in the Approved Dependencies section). Used to call `getApplicationDocumentsDirectory()` for a platform-safe storage path on Android and iOS.

### Implementation
- **Repository interface:**
  ```dart
  abstract class DayRepository {
    Future<List<Task>> load(DateTime date);
    Future<void> save(DateTime date, List<Task> tasks);
  }
  ```
- **Local implementation:** `LocalDayRepository` — reads/writes `yyyy-MM-dd.json` in a `hyperday/` subdirectory of the app's documents directory.
- **Atomic writes:** save writes to a temporary file (`yyyy-MM-dd.json.tmp`) first, then renames it to the final path. This prevents data loss if the app is killed mid-write.
- **Debounced saves:** `DayPlannerModel` does not save on every mutation. Instead, it marks the state as dirty and schedules a save after a **500ms debounce window** with no further mutations. Saves also trigger immediately on `AppLifecycleState.paused` (app backgrounded) to prevent data loss.
- **Corrupt file handling:** if a JSON file fails to parse, log the error, rename the corrupt file to `yyyy-MM-dd.json.corrupt`, and return an empty task list. The user starts with a clean day rather than a crash loop.
- `DayPlannerModel` is initialized with a `DayRepository` dependency. Designed so `LocalDayRepository` can be replaced with a cloud implementation later without touching model or UI code.

---

## Phase 7 — Multi-day & Carry-forward

**Goal:** Navigate between days; surface incomplete tasks from prior days.

### Day Navigation
- Prev/Next buttons in the day header become functional.
- `DayPlannerModel.setViewedDate(DateTime date)` — saves current day (if dirty), then loads the new date's data from the repository.

### Carry-forward
- On load of **today's date only**, scan the previous day's task file. Any incomplete, non-hard tasks are prepended to today's list as floating tasks.
- Each carried task gets `carriedFromDate` set to its original date. This field is persisted in JSON.
- **Idempotency:** before carrying, check if today's task list already contains any tasks with `carriedFromDate` matching yesterday. If so, skip carry-forward entirely. This prevents duplicates when the app is reopened multiple times in a day.
- Carry-forward only goes **one day back** automatically. Older incomplete tasks require the user to manually navigate to that day — out of scope for this phase.
- Carried-over tasks display a subtle "Carried from [date]" label on their task card.
