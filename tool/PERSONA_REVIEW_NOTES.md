# Persona Review — Round 4 notes (handoff for the next agent)

Date: 2026-11-05 · Branch: `rebuild/outcome-first` · Last commit: `7ba9539` (Phase 14)

**Status of this folder:** `tool/` is untracked scratch, not part of the app.
Don't commit it unless the owner asks. Delete it when the review work is done.

---

## 1. What round 4 was

The persona is a high-performing professional using HyperDay on their phone,
with calendar meetings imported, filling the rest of the day with tasks. The
review asked for UX feedback (good / needs work / fails) and a price, from $0
(no value) upward.

**How it was actually done:** by reading the code, plus a throwaway
`flutter test` that ran the real `Scheduler` and `CaptureParser` on the
persona's day (results in §4). The planned live browser walkthrough did
**not** happen. The Chrome extension conflicts with the owner's work account,
so don't use Claude in Chrome. The harness below is ready for a headless or
other non-account browser approach if the owner approves one.

---

## 2. Rules that still apply (from AGENTS.md)

- Don't add, upgrade or change dependencies. Notifications, widgets and
  calendar write-back would all need new packages: **stop and report**; don't
  add them.
- Don't add features or refactor unless asked. These notes are findings, not
  approved work. Each fix needs the owner's go-ahead and its own phase in
  `planner.todos.md`.
- Ignore `README.md`.

---

## 3. Harness: run the app in a browser with a fake calendar and a fake clock

Files:
- `tool/persona_main.dart`: an alternative entry point. It is a copy of
  `lib/main.dart` wiring with:
  - `MemDays` / `MemSettings`: in-memory storage. The real repositories use
    `dart:io`, which doesn't work on web. Data is lost on page reload.
  - `FakeCalendar`: a `CalendarSource` with two calendars (Work, Personal).
    - **Thursday:** Standup 8:30 (15m), 1:1 Priya 9:00 (30m), 1:1 Marco 9:30
      (30m), Product review 11:00 (60m), Lunch w/ candidate 12:30 (60m),
      Customer call — Acme 14:00 (60m), Eng sync 16:00 (30m), Kids pickup
      17:30 (30m, Personal), and an all-day "Mom birthday" (Personal).
    - **Other weekdays:** Standup 8:30, Board meeting 10:00 (2h), Team lunch
      12:00.
    - **Weekends:** nothing.
- `tool/inject_fake_clock.py`: injects a `Date.now` offset into the built
  `index.html`. Dart's `DateTime.now()` reads it, so you can live through a
  day at any hour.

Run:
```
flutter build web -t tool/persona_main.dart --no-tree-shake-icons
python tool/inject_fake_clock.py 7 45        # start the day at 7:45 AM today
cd build/web && python -m http.server 8765   # run in background
```
Open `http://localhost:8765` at phone size (about 390×844).
In the console: `__setClock(10, 55)` jumps the clock without losing data, and
`__clock()` shows the fake time. The app re-flows once a minute, so wait about
60 s after a jump, or make any edit to force a replan.

Caveats:
- `Timer`s run in real time. The Now card's seconds tick normally after a
  jump.
- The fake calendar only kicks in on Thursdays. For another weekday, change
  the `d.weekday == DateTime.thursday` check in `persona_main.dart`.
- Settings → calendar picker shows the two fake calendars. Unticking
  Personal should remove Kids pickup and the birthday label, which is worth
  checking.

---

## 4. Verified results (real engine, persona's Thursday, 8 AM–6 PM workday)

Captured in this order: `Prep board deck 2h *`, `Write Q1 OKRs 90m *`,
`Hiring plan 1h *`, `Review PRs 45m`, `Reply to Sarah 15m`,
`Expense report 20m`, `Inbox zero 30m`.

```
 8:00-8:15  Reply to Sarah        12:30-13:30 Lunch w/ candidate
 8:30-8:45  Standup               13:30-14:00 Inbox zero
 9:00-10:00 1:1s                  14:00-15:00 Customer call
10:00-11:00 Hiring plan *         15:00-15:45 Review PRs
11:00-12:00 Product review        16:00-16:30 Eng sync
12:00-12:20 Expense report        16:30-18:00 Write Q1 OKRs *
OVERFLOW: Prep board deck 120m  ← the #1 Outcome
Load bar: 55m free · 2h won't fit
```

Capture parser:
| Input | Result | Problem |
|---|---|---|
| `Email team re 2pm meeting` | pinned 14:00, title "Email team re meeting" | false time match; clashes with the 2 PM call, so the error sheet opens |
| `Book flight 9am Friday` | pinned 9:00 **today**, title "Book flight Friday" | no day words |
| `Call Bob at 3` | no time, title keeps "at 3" | bare hour not understood |
| `Prep deck tomorrow 1h` | 60m today, title "Prep deck tomorrow" | no `tomorrow` |
| `Fix 5* rating bug` | marked Outcome | `*` matches anywhere |
| `Read 2h30m article` | 150m | OK |

---

## 5. Findings, ranked

### Fails (dealbreakers)
1. **Outcomes can't be split.** First-fit needs one unbroken gap
   (`lib/services/scheduler.dart:155`). On a meeting-heavy day the #1 Outcome
   overflows while a lower Outcome and chores get the good slots. The message
   at `outcomes_list.dart:102` ("shorten it or move it to tomorrow") never
   offers splitting.
2. **No reminders or widget.** The plan only helps while the app is open.
   Fixing this needs a dependency, so it's the owner's call.
3. **A running task hides the next meeting.** `DayStats.currentItem` returns
   any in-progress task first (`day_stats.dart:115`). At 11:00 the Now card
   still shows the task, not Product review, and nothing warns that the task
   is running into a meeting.
4. **The parser misreads ordinary sentences** (see §4).
   `capture_parser.dart:34` matches any `Npm` token; `:38` treats any `*` as
   Outcome.

### Needs work
- **No ordering control.** Outcomes go in the order added; other work
  shortest first. No drag-to-reorder or "do this first".
- **No buffers.** Work starts at the first free minute (8:00 sharp) and runs
  back-to-back with meetings.
- **"Tomorrow" ignores weekends.** It is hard-coded to +1 day
  (`day_screen.dart:325`, `review_screen.dart:224`), so Friday's work moves
  to Saturday. There's no "pick a day" option.
- **Read-only calendar.** Outcome time isn't blocked on the real calendar.
  Write-back would also need owner sign-off.
- **No recurring tasks.**
- **Duration presets stop at 2h** (`item_sheet.dart:73`). 20m or 3h only
  works through capture shorthand.
- **Review covers one day only.** No weekly trend.
- **Small:** the item sheet shows the title twice, as the heading
  (`item_sheet.dart:137`) and in the text field.

### Good (keep)
Outcome-first concept and cap; fast capture that keeps the keyboard up, with
Edit/Undo; the Now card (Ready state, live timer, over-estimate warning); the
"Something came up" flow (pauses the current task, tracks interruptions
separately); Undo everywhere and a quiet banner; the Review's one-line answer
plus Tomorrow/Drop decisions; the load bar.

### Price verdict
Today: about **$3/month (~$10 one-time)**, and the persona would likely churn
within two weeks.
- Splitting Outcomes + reminders → $8–10/month.
- Plus calendar write-back and reordering → $15/month, competitive with
  Sunsama, Motion and Akiflow ($15–35/month).

---

## 6. Things to try with the harness (not yet observed live)

Each one is a hypothesis from the code. Confirm it, or knock it down:
1. Start a 60m task at 10:20. `__setClock(11, 2)`. Does the Now card show
   the task or Product review? Is there any warning?
2. At 7:45, capture the seven items above. Does the UI match §4? How do
   "55m free" and "2h won't fit" read together on screen?
3. `__setClock(8, 10)` without starting "Reply to Sarah". Does it silently
   slide? Does anything later get pushed out with no banner?
4. Capture `Email team re 2pm meeting`. How clear is the overlap error sheet?
5. "Something came up" → "Do it now" while another task is running. Check
   the pause snackbar, then Undo.
6. `__setClock(17, 50)` → Review. Check the score, time split, and the
   accuracy line when nothing was started vs when Start/Done was used.
7. Settings: untick Personal. Kids pickup and "Mom birthday" should
   disappear. Change the workday to 9–5 and check what gets reported.
8. On a non-Thursday, use Tomorrow, then navigate to that day. Is the Outcome
   flag kept? Is the 2h board meeting respected?
9. Light theme contrast on the load bar and the Now card.
10. Narrow width (360px) and a long title. Check for header or legend
    overflow.

Record results here, then propose fixes to the owner one concern at a time.
Don't implement without approval.

---

## 7. Cleanup when finished
- Stop the http.server.
- Delete `tool/` (or ask the owner whether to keep the harness).
- `build/` is gitignored; a normal `flutter build` overwrites the injected
  clock.
