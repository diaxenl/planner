# PRD: HyperDay — Adaptive Focus Planner

**Vision:** A planner for professionals who need to get the most out of every working day. Instead of a static timeline you fill out once, HyperDay tracks what you're *actually* doing in real time, and replans the rest of the day the instant reality diverges from plan — a task runs long, finishes early, something urgent lands on your desk, or a plan gets cancelled. The app always knows what you should be doing right now.

This supersedes the v1 "static timeline" plan (Phases 1–7, see [planner.todos.md](planner.todos.md)). V1 proved the core architecture (immutable `Task` model, `ChangeNotifier` state, greedy scheduler, JSON persistence) but only reacted to one event (task completion) and required a confusing multi-field form to create even a simple task. This plan overhauls the product on top of that foundation.

---

## What's changing and why

- **v1 problem:** Creating a task means picking an abstract "type" (Floating/Timed/Locked) before you even know what you're describing. **Fix:** a natural-language quick-capture box is the primary way to add a task; a structured form remains as a fallback for precision editing.
- **v1 problem:** The scheduler only reacts when a task is marked complete. Overruns, cancellations, and unplanned work aren't handled at all. **Fix:** every mutation (add, edit, delete, cancel, start/stop work, overrun detected) triggers a recompute of the rest of the day.
- **v1 problem:** The day is presented as one long timeline — useful as an overview, but it doesn't answer "what should I be doing right now?" **Fix:** a new **Focus Screen** becomes the app's home screen, built around the single task you should be working on. The full timeline becomes a secondary view.
- **v1 problem:** There's no notion of how long things actually took, so the schedule can't reflect reality. **Fix:** lightweight live time tracking (start/complete) records actual duration per task and surfaces the variance against the estimate.

---

## Core Concepts

**Task types (unchanged from v1):**
- **Hard** — immovable anchors (meetings, appointments). Fixed start time + duration. Scheduler never touches these.
- **Pinned** — user-set start time, but the scheduler may suggest moving it if a conflict arises.
- **Floating** — duration + priority only. Scheduler slots it into the best available gap.

**Task status (replaces v1's `isComplete` bool):**
- `notStarted` → `inProgress` → `complete`, or `notStarted`/`inProgress` → `cancelled`.
- A task becomes `inProgress` when the user taps **Start**. While `inProgress`, the scheduler treats it as a fixed block (never silently moved out from under active work).
- `cancelled` frees the task's slot immediately (like completion) but is excluded from estimate-accuracy stats and shown struck through with a "Cancelled" tag rather than removed from the day's record.

**Live time tracking:** Starting a task records `startedAt`. Completing it records `actualDurationMinutes` (elapsed real time). If elapsed time exceeds the estimate while a task is still `inProgress`, it's flagged as **overrunning** and the day is recomputed using the elapsed time as the effective duration, so the rest of the day reflects reality, not the original estimate.

**Adaptive replanning:** The scheduler recomputes on every mutation — add, edit, delete, cancel, start, complete, and overrun detection. Recomputation is silent when it only affects tasks that were never shown to the user in a fixed position (e.g. slotting a brand-new floating task into empty space). It surfaces a **Suggestion Banner** (Accept/Dismiss) whenever it would move an already-visible committed task or push a task into/out of overflow. Hard tasks and `inProgress` tasks are never included in a suggestion — they never move.

**Quick capture:** A free-text entry box parses shorthand like `Call mom 20m 3pm high` into a draft task (title, duration, time, priority) using a small pure-Dart parser — no new dependency. The parsed draft always opens in an editable confirmation step (the structured form) before saving, so nothing is created from a misparse. A dedicated **"Something came up"** shortcut opens the same box pre-set to high priority for fast interruption capture.

**Focus Now:** The home screen shows one task at a time — the one currently `inProgress`, or whichever committed task's time window contains "now", or the next upcoming one if there's a gap. It shows a live elapsed-time readout, Start/Complete/Cancel controls, a 1–2 item "up next" preview, and a lightweight **day health** chip (comfortable / tight / overloaded) computed from remaining committed + overflow work versus remaining time in the day window. The full multi-hour timeline (v1's `DayScreen`) remains available as a secondary view.

**Estimate accuracy:** Completed task cards show the variance between estimate and actual (e.g. "Est 30m · Actual 42m (+12m)"). A simple same-day aggregate (e.g. average overrun %) is surfaced subtly on the Focus screen. No cross-day analytics or ML in this MVP — just visibility into today's accuracy.

**Persistence:** Unchanged from v1 — JSON on-device storage via `path_provider`, one file per day, atomic writes, repository pattern. New `Task` fields (`status`, `startedAt`, `actualDurationMinutes`) are added to the existing JSON schema; no migration path is needed since there is no production data yet.

**Target platform for testing:** Android phone (personal device). No desktop-specific interactions (keyboard shortcuts, hover states) are in scope.

---

## Approved Dependencies

No change from v1. Only `path_provider` (already added). The natural-language quick-capture parser is implemented as plain Dart string/regex parsing — **no new package required**. No other packages may be added without explicit approval.

---

## Input Validation Rules

Carried over from v1, still apply everywhere a task is created or edited:
- **Title:** required, 1–100 characters, trimmed of leading/trailing whitespace.
- **Duration:** required, integer, 5–480 minutes.
- **Start time:** must fall within the day window (6:00 AM – 11:00 PM by default); end time must also fall within the window.
- **Overlap detection:** creating/editing a hard or pinned task is rejected if it overlaps an existing hard task.

New rules for status transitions:
- **Start** is only available on `notStarted` tasks.
- **Complete** is only available on `inProgress` tasks (completing a `notStarted` task first transitions it through `inProgress` with `startedAt = completedAt`, i.e. zero tracked time — this covers "I forgot to hit start").
- **Cancel** is available on `notStarted` or `inProgress` tasks, not on `complete` tasks.

---

## Phase Summary (new work, builds on completed v1 Phases 1–7)

| # | Phase | Goal |
|---|-------|------|
| 8 | **Data Model & State Overhaul** | Replace `isComplete` with `TaskStatus`; add `startedAt`/`actualDurationMinutes`; scheduler treats `inProgress` as fixed |
| 9 | **Adaptive Replanning Everywhere** | Broaden reschedule + suggestion-diff triggers to every mutation; overrun detection |
| 10 | **Live Time Tracking UI** | Start/Complete/Cancel controls, live elapsed timer, overrun visual state, variance badge |
| 11 | **Focus Now Screen** | New home screen: current task, up-next, day health chip, becomes primary; Timeline becomes secondary |
| 12 | **Natural-Language Quick Capture** | Free-text parser + confirmation step; "Something came up" urgent shortcut |
| 13 | **Estimate Accuracy Surfacing** | Per-task variance display; same-day aggregate accuracy stat |

Detailed task breakdowns for each phase are tracked in [planner.todos.md](planner.todos.md).

---

## Key Architectural Decisions

- **State management:** unchanged — `ChangeNotifier` + `InheritedNotifier` above `MaterialApp`, no new packages.
- **Scheduler:** the existing pure `Scheduler.schedule()` function gains one new rule: `inProgress` tasks are treated as fixed blocks (like hard tasks) so active work is never displaced. Everything else about gap-filling and priority ordering is unchanged.
- **Suggestion diffing:** the existing `ScheduleSuggestion`/`TaskMove` diff mechanism (v1 Phase 5) is reused, but the model now calls it from every mutation path, not just `markComplete`.
- **Quick capture parser:** a new stateless `services/task_text_parser.dart` returns a draft `Task` (or a partial result with fields left at smart defaults) from free text. It never saves directly — its output always flows into the existing structured form for confirmation.
- **Focus selection:** "what's the current task" is a pure function of `DaySchedule` + `DateTime.now()`, computed the same way the timeline already computes positions — no new state machine.
- **ID generation, storage format, debounced saves:** unchanged from v1.

### Folder Architecture (additions on top of v1)

```
lib/
  models/
    task.dart                            # + TaskStatus enum, startedAt, actualDurationMinutes
  services/
    scheduler.dart                       # + inProgress tasks treated as fixed blocks
    task_text_parser.dart                # NEW — free-text → draft Task (pure Dart, no deps)
  state/
    day_planner_model.dart               # + startTask(), cancelTask(), overrun detection,
                                          #   dayHealth getter, suggestion diffing on all mutations
  features/
    focus/                               # NEW — primary home screen
      focus_screen.dart                  # Current task, live timer, up-next, day health, quick capture
      widgets/
        focus_card.dart                  # Current task detail + Start/Complete/Cancel
        up_next_strip.dart               # Next 1-2 committed tasks
        day_health_chip.dart             # Comfortable/tight/overloaded indicator
        quick_capture_bar.dart           # Free-text entry + "Something came up" shortcut
    day_view/                            # Retained as secondary "Timeline" view (v1 Phases 1-3, 5)
      ...                                # unchanged structure; reachable from Focus screen
  app.dart                               # home: FocusScreen (was DayScreen)
```

The v1 folder layout (`core/`, `models/`, `state/`, `services/`, `features/day_view/`) and its principles are unchanged — see [planner.todos.md](planner.todos.md) for the original structure. This section only lists what's new or modified.

Detailed, ordered task breakdowns for Phases 8–13 are tracked in [planner.todos.md](planner.todos.md).
