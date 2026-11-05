# PRD: HyperDay — Outcome-First Day Planner

**Vision:** The day planner for high performers. You pick the few outcomes that make today a win; HyperDay builds the day around them, fits them between your real meetings, adapts the moment reality changes, and tells you at the end of the day whether your time actually went to what mattered.

**Audience:** An individual high performer who owns their own day — senior ICs, founders, leads, consultants. Meeting-heavy calendars, frequent interruptions, a handful of things that genuinely matter each day. This is a *personal* tool, not team management.

**Design rule — KISS.** HyperDay excels at one job: *protect and deliver today's outcomes.* Every feature must serve that job with near-zero extra input. If a feature needs the user to categorize, configure, or maintain something, it is cut or derived automatically.

This document supersedes the earlier "Adaptive Focus Planner" plan. Phases 1–9 (see [planner.todos.md](planner.todos.md)) built a solid engine — immutable `Task` model, greedy scheduler, adaptive replanning with suggestions, live time tracking, JSON persistence. **The engine is kept. The UI is rebuilt from scratch.** Refactoring of existing code is explicitly permitted where it serves this plan.

---

## Why the rethink

- **v1/v2 treated every task as equal.** A board-deck draft and "reply to Dave" were peer rows on a timeline. **Fix:** up to 3 **Outcomes** per day are first-class; everything else is supporting work.
- **Meetings had to be typed in by hand.** No high performer will do that. **Fix:** meetings are imported from the phone's calendars (Google, Microsoft, Apple).
- **It answered "what's next?" but not "did today go to what matters?"** **Fix:** an end-of-day review shows outcomes hit and where the time actually went — derived automatically, no tagging.
- **It looked generic.** Stock Material, default blue, chips and shadows. **Fix:** a calm, dark-by-default, typographic design with a single accent color.
- **Too many concepts on screen** (Hard/Pinned/Floating, Low/Med/High). **Fix:** plain language, fewer knobs.

---

## Core Concepts

### Items on the day

Every item has a title, a duration, and one of three kinds (plain-language labels replace the old type names; internal enum names may stay):

| User sees | Internal | Behavior |
|---|---|---|
| **Meeting** | `hard` | Fixed time. Never moved. Usually imported from the calendar. |
| **At a set time** | `pinned` | User-chosen time. Scheduler may *suggest* moving it on conflict. |
| **Anytime** | `floating` | Duration only. Scheduler places it. |

Flags (no other categorization exists):
- **Outcome** (`isOutcome`) — one of today's most important things. Replaces the Low/Med/High priority system entirely. The daily cap defaults to **3** and is adjustable in Settings (1–5) — focus is the point, but the number is the individual's call.
- **Interruption** (`isInterruption`) — set automatically when captured via "Something came up". Never set by hand.

Status lifecycle is unchanged from Phase 8: `notStarted → inProgress → complete`, or `notStarted/inProgress → cancelled`.

### Scheduling (engine kept, ordering simplified)

- Meetings, at-a-set-time items, and in-progress items are fixed blocks (unchanged).
- Anytime items fill gaps from now onward: **Outcomes first, in the order the user added them** (revised after persona review — shortest-first pushed big Outcomes late), then everything else, shorter first. (Replaces priority ordering.)
- **One thing at a time:** starting a task pauses any other running task back to not started; minutes tracked so far are kept and add to its next run (Undo restores it).
- **Time spent:** a task completed without ever being started counts its estimate as time spent (so the Review stays honest) but is left out of estimate accuracy.
- Clock-driven replans (minute tick, overrun) apply moves silently and only raise an OK-only banner when work is pushed out of the day.
- Anything that cannot fit goes to **overflow** — an unplaced Outcome is called out prominently ("Outcome doesn't fit today").
- Adaptive replanning and overrun handling from Phase 9 are kept. Today's schedule also re-flows silently once a minute, so not-started work never sits in the past.
- **The "Your day shifted" banner is rare by design** (revised after persona review): it appears only when an **Outcome moves later** or something is **pushed out of the day**. Everything else (other work reshuffling, things moving earlier) is applied silently. The change is already applied; the banner offers **OK** or **Undo** (Undo holds the affected work where it was).

### Calendar import (must-have)

- Read-only import of events from the calendars already on the phone. Android and iOS both sync **Google, Microsoft (Outlook / 365 / Exchange), and Apple iCloud** accounts into the on-device calendar store, so reading that store covers all major providers with **one package, no OAuth, no server, no API keys**.
- The user picks which calendars to include (Settings). Default: all.
- Timed events become **Meetings** (fixed blocks). All-day events are shown as a one-line label at the top of the day, not as blocks. Events the user has declined are skipped where the platform exposes that.
- Imported events are **not persisted** in HyperDay's files and **not editable** in HyperDay — they are re-read on app open, on pull-to-refresh, and on day change. The phone's calendar remains the source of truth.
- Known limitation to surface in-app: an account must be synced to the phone's calendar (e.g. Outlook for Android requires its "sync calendars" option).
- Not supported on Windows/web (dev preview only); a no-op calendar source is used there.

### Screens (three, plus settings)

1. **Day** (home). Shows today by default; prev/next to plan other days.
   - **Load bar** — signature element. One horizontal bar for the remaining day window, split into Meetings / Outcomes / Other / Free. Readable in half a second.
   - **Now card** (today only) — the current item (in-progress, else the one whose window contains now, else the next upcoming), big live timer, **Start / Done / Cancel**. Overrun turns the timer to the accent warning color.
   - **Outcomes** — up to the outcome cap, with check state. If none are set: a single prompt, "What would make today a win?"
   - **Agenda** — the rest of the day, one line per item: time · title · duration. Meetings visually quieter than work. Overflow at the end.
   - **Suggestion banner** — see the banner rule above (OK / Undo).
   - **Capture bar** — pinned to the bottom, like a message composer. Replaces the FAB.
2. **Review** (end of day, reachable any time from Day).
   - Outcomes hit: e.g. **2 / 3**, plus one answer line: "X% of your working time went to outcomes, Ym to interruptions." Score and time split are a snapshot taken when the Review opens.
   - Time split, planned vs actual: Meetings / Outcomes / Other / Interruptions. Derived from kinds and flags — no tagging.
   - Estimate accuracy: one number (e.g. "Ran 18% over estimates").
   - Unfinished items, each decided explicitly: **Tomorrow** or **Drop**. This replaces automatic carry-forward.
3. **Item sheet** — bottom sheet to confirm/edit an item: title, duration, kind (with a one-line explanation), time (picker opens automatically), Outcome toggle (disabled with a note at the cap). For an existing unfinished item: **Start / Done / Cancel / Tomorrow**. Done, Cancel and Delete all offer **Undo**. Imported meetings open read-only.
4. **Settings** — calendars to include, theme (Dark default / Light / System), daily outcome cap (default 3).

The old vertical hour-grid timeline is **removed**. The load bar plus agenda replace it.

### Capture & triage

- **Capture bar** parses shorthand into a draft item (pure-Dart parser, no dependency):
  - Duration: `30m`, `1h`, `1h30m` (default 30m)
  - Time: `3pm`, `15:00` → At a set time
  - Outcome: `*` anywhere marks it as an Outcome
  - Everything else is the title
  - The item is **added immediately** with an "Added … · Edit" confirmation (revised after persona review: the extra confirm step was friction). If the model rejects it (overlap, cap, outside the day), the Item sheet opens pre-filled to fix it.
- **"Something came up"** button next to the capture bar: type it, then pick **Now** (start it immediately, replanning the day) / **Later today** (Anytime) / **Tomorrow**. Marks the item as an Interruption. Shown when viewing today. The Now card always shows the most recently started item.

### Visual identity

- **Dark by default**; light theme available. All colors as tokens in `core/theme.dart`.
- Near-black / off-white neutrals, **exactly one accent color**, used only for: the Now card, Outcomes, overrun warning. No colored priority chips, no drop shadows, hairline dividers.
- **Typography carries the design.** Large, bold numerals for times and timers using tabular figures. One bundled font (OFL-licensed, e.g. Inter) added as a **font asset in `pubspec.yaml` — this is an asset, not a package dependency**.
- Generous spacing, one-line agenda rows, minimal icons.

### Persistence

- Unchanged mechanism: JSON per day under `hyperday/`, atomic writes, debounced saves, repository pattern.
- Schema change: `priority` removed; `isOutcome`, `isInterruption` added. No migration — there is no production data. Old fields in existing files are ignored.
- New: `hyperday/settings.json` for theme and selected calendar IDs.

### Target platform

Android phone (personal device) is the primary target. iOS should work through the same code paths but is not actively tested. Windows / Chrome are dev-preview only. **Prerequisite for calendar work:** the Android SDK must be installed on the dev machine (currently missing).

---

## Explicitly NOT in scope (KISS)

Recorded so they are not silently re-added:
- Team features, delegation, "waiting on" lists.
- Manual time-category tagging (time split is derived instead).
- Separate "focus block" concept (Outcomes *are* the focus work).
- Writing to the calendar, creating calendar events, OAuth/cloud sync.
- Cross-day analytics, weekly review, notifications, widgets.
- The vertical hour-grid timeline.

Any of these can be proposed later as a new phase; none are implied by this document.

---

## Approved Dependencies

- `path_provider` — existing, unchanged.
- **Calendar access package** — approved in principle by the owner (2026-11-05) for the Calendar Import phase. Candidate: `device_calendar` (Android + iOS, reads the on-device store). **The exact package and version must be confirmed with the owner immediately before it is added.** Nothing is added before that phase.
- Bundled font file — asset only, no package.

No other packages may be added without explicit approval (see `AGENTS.md`).

---

## Validation Rules

- **Title:** required, 1–100 characters, trimmed.
- **Duration:** required, integer, 5–480 minutes.
- **Time:** start and end within the day window (6:00 AM – 11:00 PM).
- **Overlap:** fixed-time items (Meetings, user-created or imported, and At-a-set-time items) may not overlap each other. Completed/cancelled items no longer hold their slot. Imported meetings may overlap each other (double-booking happens; the calendar is the source of truth).
- **Outcomes:** at most the user's outcome cap per day (default 3, Settings 1–5); completed Outcomes still count (it's a per-day commitment). Exceeding it is rejected with a clear message. Editing an existing Outcome is always allowed, so lowering the cap never locks today's Outcomes.
- **Status transitions:** unchanged — Start only from `notStarted`; Done from `notStarted` (zero tracked time) or `inProgress`; Cancel from `notStarted` or `inProgress`.

---

## Phase Summary (rebuild)

| # | Phase | Goal |
|---|-------|------|
| 10 | **Model & Engine Simplification** | `isOutcome`/`isInterruption` replace `Priority`; outcome-first scheduling; remove auto carry-forward; tests updated |
| 11 | **Design System & App Shell** | Dark/light tokens, bundled font, settings persistence, new Day screen skeleton; delete old `day_view` UI |
| 12 | **Day Screen** | Load bar, Now card + live timer + Start/Done/Cancel, Outcomes, Agenda, overflow, suggestion banner, Item sheet |
| 13 | **Capture & Triage** | Capture bar + parser + confirmation; "Something came up" with Now / Later today / Tomorrow |
| 14 | **Calendar Import** | Confirm + add calendar package; permissions; calendar picker; events as read-only Meetings |
| 15 | **End-of-Day Review** | Outcomes hit, planned vs actual time split, accuracy, Tomorrow/Drop for unfinished items |

Each phase is validated (analyze clean, tests pass, reviewed in the running app) before the next begins. Detailed checklists live in [planner.todos.md](planner.todos.md).

---

## Key Architectural Decisions

- **State management:** unchanged — `ChangeNotifier` + `InheritedNotifier`. A small `SettingsModel` (same pattern) holds theme and calendar selection.
- **Scheduler:** stays a pure function. Ordering key changes from priority to `isOutcome`. Imported calendar events are converted to fixed blocks before being passed in; the scheduler has no knowledge of calendars.
- **Calendar:** behind a `CalendarSource` interface (`services/calendar_source.dart`), mirroring the `DayRepository` pattern. `DeviceCalendarSource` for phones, `NoCalendarSource` for desktop/web/tests.
- **Derived stats** (load bar segments, time split, accuracy, outcomes hit) are pure functions in `services/day_stats.dart` over `DaySchedule` + tasks — no stored state.
- **Capture parser:** pure, stateless `services/capture_parser.dart`; never saves directly.

### Target Folder Architecture

```
lib/
  main.dart
  app.dart                       # MaterialApp, theme from SettingsModel, home: DayScreen
  core/
    theme.dart                   # dark + light tokens, typography
    constants.dart
    utils.dart
  models/
    task.dart                    # isOutcome, isInterruption; Priority removed
    calendar_event.dart          # NEW — read-only imported event
    day_schedule.dart, scheduled_task.dart, schedule_suggestion.dart
  services/
    scheduler.dart               # outcome-first ordering
    day_repository.dart, local_day_repository.dart
    settings_repository.dart     # NEW
    calendar_source.dart         # NEW — interface + DeviceCalendarSource + NoCalendarSource
    capture_parser.dart          # NEW
    day_stats.dart               # NEW — load bar, time split, accuracy
  state/
    day_planner_model.dart, day_planner_provider.dart
    settings_model.dart          # NEW
  features/
    day/                         # NEW home screen (replaces day_view/)
      day_screen.dart
      widgets/  load_bar.dart, now_card.dart, outcomes_list.dart, agenda_list.dart,
                suggestion_banner.dart, item_sheet.dart, capture_bar.dart
    review/
      review_screen.dart
    settings/
      settings_screen.dart
```
