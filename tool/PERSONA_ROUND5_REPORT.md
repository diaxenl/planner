# Persona Review — Round 5 (consolidated)

Date: 2026-11-21 · Branch: `rebuild/outcome-first` · Commit `2269292` **plus the uncommitted working tree** (scheduler change included)

These are findings only. Nothing here is implemented or approved. Each fix needs the owner's go-ahead and its own phase.

## How the test was run

- **Testers:** five in parallel, each in its own tab of the owner's Chrome via Claude in Chrome:
  1. **C** Casey: cold first-timer with no idea what the app is
  2. **O** Jordan: office worker
  3. **L** Alex: engineering team lead
  4. **E** Morgan: VP/executive
  5. **A** Riley: market analyst / prospective investor
- **Scale:** about 560 browser actions in total.
- **Method:** black box only. No tester read the code.
- **Harness:** `tool/persona_main.dart` wiring plus an in-memory recurring repository.
  - The fake calendar ran a busy Thursday.
  - A fake clock (`__setClock`) started at Thu 19 Nov 2026, 7:45, and testers lived through the whole day.
  - The temporary entrypoint has been deleted.
- **Method for this report:**
  - An issue reported by ≥2 testers counts as a duplicate, and duplicates are ranked first.
  - Single reports are kept only if they were reproduced or verified in code.
  - Noise is listed at the end, with the reason it was removed.
- **Baseline:** `flutter analyze` is clean. `flutter test`: 118 pass, with 1 known failure (`review_screen_test.dart`, depends on the clock, already noted in the todos).

## 0. Found before testing: the real web build crashes on startup

`LocalDayRepository.load` calls `getApplicationDocumentsDirectory()` outside its `try` block (`lib/services/local_day_repository.dart:24`).

- **On web:** `path_provider` throws "No implementation found", `main()` dies before `runApp`, and the page stays blank. The Chrome dev preview can't run without the harness.
- **On phones:** the same unguarded call would show a white screen if the documents directory ever fails to resolve.
- **Why it matters:** low impact for users today, but it's a robustness gap.

---

## Headline

The niche needs two things above all: **plan quality** (outcomes get real, contiguous focus time between meetings) and **time truth** (the end-of-day answer is honest). Both are broken right now.

- **The first is caused by the uncommitted scheduler change.**
  - `minSessionMinutes` went from 30 to 5.
  - All Anytime work now splits across the earliest gaps. Before, only Outcomes split, and other work was placed whole.
  - Every product tester rated this the #1 or #2 problem.
- **The second is a design assumption in `day_stats.dart`.**
  - Meetings count as fully attended from the start of the day.
  - Tracked time is never cut off where it overlaps a meeting.

The things testers loved are consistent across all five and should be protected (§4).

---

## 1. Duplicates (≥2 testers): these need to be addressed

Columns: C O L E A = which testers reported it. ✔ = verified in code by the coordinator.

| # | Issue | C | O | L | E | A | Sev | Verified / root cause |
|---|---|---|---|---|---|---|---|---|
| D1 | **Work is chopped into 3–15 min slivers** even when a contiguous block is free. A 30m phone call is split 6m + 24m, a "5m session" of a hiring memo is offered, and a 1h review is split 5m/45m/10m while 1:30–6 PM is empty | ● | ● | ● | ● | ● | major | ✔ uncommitted `scheduler.dart` diff + `constants.dart` `minSessionMinutes = 5`. Every floating item now goes through `_split`; the "whole in the first gap that fits" step was removed |
| D1a | ↳ Blocks under 15 min are drawn as blank, unlabeled bars | | ● | ● | ● | ● | minor | Made worse by D1 |
| D1b | ↳ Future sessions of a started item are labelled "In progress · 2/4" | | ● | | ● | ● | minor | |
| D1c | ↳ "10m free" shows while a 10m item sits in Doesn't fit (the free time is split across gaps) | | ● | | | | minor | Comes from D1 |
| D2 | **A running timer keeps counting through calendar meetings**, so meeting time is credited as task work ("took 2h 12m", about 1h of which was Product review). Worked time can't be corrected afterwards | ● | ● | ● | ● | ● | major | ✔ Tracked minutes are never clipped at meeting boundaries |
| D3 | **Review numbers can't be trusted.** At 7:53 AM it shows "Meetings 5h 15m of 5h 15m". Totals exceed the day (10h17m inside 10h12m; 11h12m inside 9h50m). "80% of your working time" leaves out meetings, which were 5h of the day. Bars are scaled to the largest category, not to the plan. "Planned" doesn't drop after an item moves to tomorrow | ● | ● | (●) | ● | ● | major | ✔ `day_stats.dart:168-190`: meetings are assumed attended no matter the time, and they're added on top of tracked time. (L found the numbers fine on their day) |
| D4 | **Running-task controls are inconsistent.** There's no Pause while within the estimate. The "In a meeting" card has Pause but no Done. At a meeting boundary the buttons swap under your thumb, so a Done tap is lost | ● | | ● | ● | ● | minor→major (feeds D2) | |
| D5 | **The parser silently misreads natural phrasing.** "before Friday/Monday/2pm" and "after 2pm" become *on* that day or time, and the title is cut off ("…paperwork before"). "1h 30m" with a space gives title "…30m" and duration 1h. "20 min", "2 hours", "at noon", "2-3pm" and "now" are ignored. None of this is flagged to the user | ● | | ● | ● | ● | major | ✔ Same class as round 4 #4, partly fixed in Phase 17 |
| D6 | **Overlap handling in the item sheet.** The warning goes stale after you change the time or switch to Anytime. The first Add only reveals the warning. There's no way to save a real double-booking. On Friday no warning showed at all (O, once) | ● | ● | ● | ● | | minor | |
| D7 | **"Meeting" and "Set time" can't be told apart** (the copy is nearly identical). **Priority (High/Normal/Low) overlaps with Outcome**, and High didn't put prep before the meeting it was for | ● | ● | ● | ● | | minor | Priority (Phase 22) conflicts with the PRD's "no other categorization" |
| D8 | **"Tomorrow", "Monday" and "Pick a day…" in the edit sheet throw away unsaved edits** (duration 1h→2h and a retyped title were both lost) | ● | ● | | | | major | ✔ `item_sheet.dart:301-303` pops and acts on the original `task` |
| D9 | **Feedback doesn't match outcome.** "Added '…'" and "Added … for later today" appear while the item went straight to Doesn't fit. The Doesn't-fit set reshuffles on every edit (Expense report went in and out 5× by noon). "Your day shifted" lists 1 of 5 dropped items, never says what came back, and fires for 2-minute moves | ● | ● | | ● | ● | major | Made worse by D1's earliest-first churn |
| D10 | **No way to say "before / after this meeting".** Prep for the 2 PM Acme call lands at 3 PM even at High. Board follow-ups land before the board meeting | | ● | | ● | | major (E: blocker) | In-niche; owner decision (see §5) |
| D11 | **No limit or nudge on the number of Outcomes.** 6 were accepted on a day where 2 fit ("0 / 6") | | | ● | | ● | minor | ✔ Cap removed on purpose in `2269292`, but the PRD still says cap 3 and `day_screen.dart:63` still has a stale comment about it. Owner decision |
| D12 | **Wording and behavior meant for today leak onto other days.** Tomorrow's view says "Not enough time left today". Past days accept new work scheduled at 8 AM. The "tomorrow" chip shows while you're viewing tomorrow | ● | | | ● | ● | cosmetic | |
| D13 | **Remaining time is handled wrongly.** After an overrun it silently becomes "5m". Moving a partly-worked task to tomorrow resets it to the full estimate. "How long" means total, not remaining | | | ● | | ● | minor | Part of time truth (D2/D3) |

## 2. Single reports kept (reproduced, verified, or severe)

| # | Issue | Who | Sev | Notes |
|---|---|---|---|---|
| S1 | **Now card hides a running task when a Set-time item's slot begins.** The card shows "READY call Sam" while the MSA review is still timing in secret; reproduced 2×, and that's how lunch was logged as work | O | major | ✔ `now_card.dart:227` shows "still running" only when `isMeeting` |
| S2 | **An Outcome slightly too big for the day gets zero time**, and the chores get its time ("Doesn't fit, even split up", while 2h15m went to Slack and expense reports) | L | major | ✔ `_split` returns null → the whole item overflows. This directly contradicts "outcomes first" |
| S3 | **Tapping outside the "New item" sheet loses the captured item.** No toast, no undo; reproduced 2× | E | major | Data loss inside a capture tool |
| S4 | **A renamed item keeps its old title on the timeline until you scroll**; reproduced 3× | C | minor | |
| S5 | **Moving a repeating task to Tomorrow duplicates it there.** The Missed card offers no "Won't do / skip", so a past 1:1 prep can only be "Done" or carried forward | L | minor | |
| S6 | **Undo on the "Paused …" toast after ⚡ Do it now** resumes the old task but leaves the interruption orphaned in Doesn't fit | O | minor | |
| S7 | **⚡ "Something came up" has no label.** Desktop testers found it through hover tooltips; on a phone there is no hover. E found it at 17:51. Interruptions captured through the normal bar don't count as interruptions | E (C via hover) | minor | Discoverability of the best-liked feature |
| S8 | **Editing a calendar meeting saves back to the shared event** without saying which calendar or account it belongs to | L | minor | A safety and trust issue for organiser-owned meetings |
| S9 | **Work pushed to tomorrow lands in the slot just before the big meeting** (Expense report at 9:30 right before the 10:00 Board meeting) | E | minor | Same root cause as D1 and D10 |
| S10 | **On a mid-day cold start, the timeline opens at 8 AM.** Past items look the same as future ones, and the now-line strikes through a title | C | minor | |

## 3. Stripped as noise

- **Harness artifacts:**
  - Nothing persists after a reload.
  - The calendar is fake.
  - The layout is desktop width.
  - Header values are stale right after a clock jump.
  - Dropped taps on the workday stepper (L) are probably tool timing, so they're unconfirmed.
- **Outside the niche, or already excluded by the PRD:**
  - Notifications and widgets (need a new dependency; PRD excludes them).
  - Writing focus blocks to the calendar.
  - Team features, or "skip this meeting for planning".
  - Weekly or cross-day analytics beyond the existing 7-day strip.
- **Not the target user** (C is a retail manager):
  - "After work" errand windows.
  - "Prod outage" being jargon.
  - Onboarding copy aimed at non-office users. C's "Outcome is never explained" point is kept only as a low-priority note: the target user got it right away.
- **Low-value wishes:**
  - Workday steps finer than 1 hour.
  - Personal calendar events reported separately from Meetings.
  - Merging queued toasts.
  - The review offering a "set tomorrow's top 3" handoff. E only; worth revisiting after D3.
- **Polish (E, F20):** do these as one pass, not individual items:
  - Block layout differs between ≤15m and longer blocks.
  - "Won't do" items appear under "Finished".
  - Gridlines strike through the "free" labels.
  - Two different selection styles in light theme.
  - The time picker defaults to 7 PM for tomorrow and 8 AM instead of the item's time.
  - The Outcome list isn't in chronological order.
  - Small headers on Review and Settings.

## 4. Keep (all or most testers praised these, so don't break them)

| Feature | Praised by |
|---|---|
| Zero-setup start: "What's the one thing you need to get done today?" over the real calendar | all 5 |
| ⚡ Something came up: Do it now / Later today / Tomorrow, auto-pause, counted as Interruptions | all 5 |
| Undo on every action; the Missed card | C O E A |
| Live Now card nudges: "+9m over… still on it?", "Lunch starts in 5m", "In a meeting · X is still running" | C O L A |
| Capture shorthand and chips (`10m`, `3:40pm`, `*`, `tomorrow`) | O E A |
| Review "Still open" triage; Tomorrow on a Friday becomes Monday | O E A L |
| Dragging to reorder Outcomes, with instant replan | L A |
| Header capacity math (meetings + outcomes + other + free = workday) | O L |

## 5. Decisions only the owner can make

1. **Scheduler splitting** (this is D1, S2 and S9 together). The uncommitted change implements "most important work always gets the earliest time". Testers rejected the fragmentation it causes. Options:
   - (a) Revert to the committed behaviour: whole-first, and only Outcomes split, at ≥30m.
   - (b) Keep "fill freed time", but place each item whole in the first gap that fits before splitting. Split only Outcomes, at ≥25–30m, and give an Outcome its partial time before chores get any (fixes S2).
   - (c) Something else.
2. **Time truth model.** Should tracked time auto-pause or clip at a meeting's start? Should meetings count only up to "now"? What should the headline % be measured against (working time, or the whole day)?
3. **Outcome cap:** bring back a cap or soft nudge, or update the PRD to say there's no cap.
4. **Before/after a meeting** (D10): add a constraint, or accept that pinning is the answer.
5. **Meeting vs Set time, and Priority vs Outcome** (D7): merge or clarify.

## 6. Market analyst summary (A)

- **Verdict:** Watch, and invest if:
  - time accounting is correct with zero extra input
  - outcomes get contiguous blocks
  - a 200-user beta shows D30 retention ≥25%, the review opened on ≥50% of active days, and 4–5% trial-to-paid conversion
  - there is a credible iOS plan
- **Real differentiators:**
  - Calendar import on the phone itself, with no sign-in. Every scheduling competitor needs OAuth.
  - Mobile-first auto-scheduling on Android. There's a gap now that Clockwise has shut down, Motion has moved upmarket, and Sunsama's Android app is only a companion.
- **Thin differentiator:** outcome-first framing. Potentially real: the "honest review", once it's honest.
- **Must be perfect, in order:**
  1. Time truth
  2. Contiguous outcome blocks
  3. Zero-input meeting transitions
  4. A 30-second morning
  5. A 10-second evening close
  6. Reliability
- **Pricing:**
  - Free: 1 outcome plus today's review.
  - Pro: $5.99/mo or $49/yr, plus a $99 lifetime option.
  - Don't charge until D2 and D3 are fixed.
- **Willingness to pay today:**
  - C $0
  - O $3
  - L $0 (→$5 once D1/S2 are fixed)
  - E $0 (→$10 once D1/D10 are fixed)
  - A $0 (→$5–6 once D2/D3 are fixed)

The full analyst competitive table, with sources, is in the session transcript.
