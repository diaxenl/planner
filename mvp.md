# HyperDay — Minimum Viable Product

**Date:** 2026-11-17 · **Basis:** `plan-hyperDay.prompt.md` (PRD), `planner.todos.md` Phases 10–22, owner feedback to date, market analysis (2026-11-17).

HyperDay is an outcome-first day planner for one person who owns their own day. You name the few things that would make today a win. HyperDay fits them around your real meetings, re-plans when the day changes, and at the end of the day tells you where the time actually went.

---

## 0. Goal and positioning

**Goal:** side income and a portfolio piece, built by one person. The MVP has to earn money with close to zero running costs and no servers to maintain.

**What sets it apart.** The market is crowded (Sunsama, Akiflow, Motion, Reclaim, Tiimo, Structured), so the MVP leads with these three things:
1. **The honest end-of-day review (T7).** Competitors tell you what to do next. HyperDay tells you whether today went to what mattered. This is the main hook.
2. **No account, no cloud (T8).** Reads the phone's calendar with no sign-in, and your data stays on the phone. That includes people whose company blocks third-party calendar apps.
3. **It plans for you, but you stay in charge (T1, T4).** Sunsama makes you plan by hand. Motion takes over completely. HyperDay sits between the two.

**First buyer:** not chosen yet. The beta (exit criterion 4) decides between three groups:
- founders and consultants
- people with ADHD
- corporate staff whose company blocks third-party calendar apps

**Business model:** free to download, with a **one-time Pro unlock**. No account and no subscription in the MVP. Running costs are about $125 in year one (Apple $99/yr, Google $25 once, a domain). If accounts and cloud sync come later, sync is an **optional subscription**, and Pro buyers keep what they paid for. Lifetime cloud sync is never sold.

---

## 1. Tenets (the MVP is judged against these)

| # | Tenet | What it means in practice |
|---|---|---|
| T1 | **Outcomes first** | Up to 3 Outcomes a day (Settings 1–5). They are planned before all other work and called out loudly if they don't fit. |
| T2 | **Turn it on and go** | No setup, no tutorial. An empty day shows one question: "What's the one thing you need to get done today?" |
| T3 | **Near-zero input** | One-line capture with shorthand (`45m`, `at 3pm`, `tomorrow`, `*`). No tagging or categories. Stats are worked out from what you already did. |
| T4 | **The plan follows reality** | The day re-plans on its own: every minute, when the app comes back to the front, and after every Start, Done or "Won't do". Work never sits in the past. Free time gets refilled. |
| T5 | **Interrupt quietly** | Moves happen silently. You only hear about it when an Outcome slips 30+ minutes, or when work is pushed out of the day. Every destructive action has Undo. |
| T6 | **One thing at a time** | Starting a task pauses any other; the minutes already tracked are kept. The Now card always shows what matters right now. |
| T7 | **Honest end of day** | Review shows outcomes hit, where the time went (planned vs actual), how accurate the estimates were, and an explicit choice for every unfinished item (next weekday / pick a day / Won't do). Nothing carries over by itself. |
| T8 | **Your calendar is the truth** | Meetings come from the phone's calendars (Google, Microsoft, iCloud) with no sign-in. Meetings that are only on your calendar can be edited, and the edits are saved back to it. |
| T9 | **Calm and readable** | Dark by default, one accent color, readable at a glance. The load bar and timeline show the day in half a second. |

---

## 2. MVP scope (built)

### Day screen
- Date header with previous/next day, all-day calendar events as a one-line label, and links to Review and Settings.
- **Empty-day prompt** (T2). The first thing you enter becomes an Outcome (default 1h).
- **Load bar**: the rest of the workday split into Meetings / Outcomes / Other / Free, rounded to 5 minutes.
- **Now card**: the current or next item, with a live timer that shows units ("12m 05s"), plus Start / Done / Won't do / Pause.
  - A meeting that has started takes over the card while a task is still running.
  - Warns 5 minutes before the next item.
  - Asks "Past your estimate — still on it?"
- **Missed list**: set-time items whose time passed without a Start. One tap for Later today (only if it still fits), next weekday, or Done.
- **Outcomes list**: drag to reorder. A big Outcome is split into sessions of at least 30 minutes ("2h in 3 sessions"). Shows "Outcome doesn't fit today" when it can't be placed.
- **Timeline**:
  - Hour labels, with blocks sized by length and colored by kind (meetings have an icon and a blue-grey hue).
  - Free gaps of 15m or more are labelled, and a line marks "now".
  - Overlaps are striped. Finished and worked items stay where they happened.
  - "Doesn't fit" sits below the timeline, plus "Done" and "Won't do" for finished items that have no place on it.
- **"Your day shifted" card** (rare; OK / Keep as it was).
- **Capture bar** with shorthand chips (`30m`, `1h`, `at …` time picker, `tomorrow`, `★ Outcome`). Items are added straight away, with Edit and Undo.
- **"Something came up"**: Now / Later today / Tomorrow. The item is marked as an interruption.

### Items
- Three kinds: **Meeting**, **At a set time**, **Anytime**.
- Flags: **Outcome**, **Interruption** (set automatically), and **Priority** (High / Normal / Low; Anytime non-Outcomes only).
- Lengths from 5m to 8h, with presets up to 4h plus "Other…".
- Repeat: Never / Every day / Weekdays / Every <weekday>.
- Actions: Start / Done / Won't do / Tomorrow (next weekday) / Pick a day… / Delete, each with Undo.
- Fill order: Do next → Outcomes (in drag order) → High → Normal → Low, shorter first. Each item takes the earliest gap it fits.

### Review
- Outcomes hit (e.g. 2 / 3) and a one-line answer: "X% of your working time went to outcomes, Ym to interruptions."
- Time split, planned vs actual: Meetings / Outcomes / Other / Interruptions.
- Estimate accuracy.
- An explicit decision for each unfinished item.
- Last 7 days: outcomes done and outcome share, per day and in total.

### Settings
Theme (Dark / Light / System) · Outcomes per day (1–5) · Workday hours (default 8 AM–6 PM) · Calendars: allow access, choose which calendars, connection status.

### Rules
- Title: 1–100 characters.
- Duration: 5–480 minutes.
- Fixed-time items can't overlap each other. Imported meetings may overlap each other.
- Fixed items must end by midnight.
- Anytime work is planned only inside the workday.

---

## 3. Explicitly out of the MVP

Team features · manual time tagging · a separate "focus block" concept · accounts, OAuth and cloud sync · cross-device sync · a web or desktop *product* · AI features · importing tasks from other tools (Todoist, Jira, email) · notifications, reminders and home-screen widgets (these need a new package, see §5) · editing repeating calendar meetings.

**After the MVP (not committed):** a web demo with sample data for the portfolio. It can't read the phone's calendar or save files the way the app does, so it is only a demo. Accounts and sync come only if paying users ask for them.

---

## 4. MVP exit criteria

1. `flutter analyze` is clean and `flutter test` is green. One clock-dependent Review test is a known failure.
2. A high-performer persona and an average-user persona can each run a full day in the app without hitting a dead end: plan, capture, start/finish early and late, handle an interruption, review. Every tenet T1–T9 holds.
3. Real-device check on Android (and iOS where possible) with Google, Microsoft and iCloud calendars. **Still open.** This is the most important criterion, because T8 is the core promise.
4. **Closed beta.** 15–20 testers across the three candidate groups use the app for 2 weeks through TestFlight and Google Play internal testing. Proposed bar, which the owner can change:
   - **40% or more** are still using it in week 2.
   - **Most** of them open the Review at least a few times a week.
   - The group that sticks best becomes the first buyer.
5. **Ready for the stores:**
   - The "HyperDay" name is checked for an existing trademark, and the domain is taken.
   - A privacy policy ("your data never leaves your phone").
   - Store listings and screenshots that lead with the Review.
   - Enrolled in the Apple and Google 15% small-business programs.
   - An LLC is set up before money is taken.

---

## 5. Open decisions (owner)

1. **Paying for Pro needs a new package.** Selling the Pro unlock in-app takes an in-app purchase package (`in_app_purchase`, or RevenueCat's `purchases_flutter`), and that isn't in `pubspec.yaml`. AGENTS.md says no new dependencies without explicit approval. **The owner has to approve this before any purchase code is written.**
2. **What's free and what's Pro.** For example: the free version has the full Day screen plus today's Review, and Pro adds the 7-day history, repeating items and more than 1 Outcome a day. The free version must still show the Review, since it's the hook. Price somewhere around $20–40 one-time.
3. **Notifications and widgets.** These matter a lot for "the plan follows reality" on a phone, and they need a new package. Decide after the beta, based on whether testers ask for them.
4. **First buyer.** Decided by the beta results (exit criterion 4).

---

## 6. Path to launch

1. **Close exit criterion 3:** test calendars on real phones.
2. **Run the beta:** criterion 4, two weeks. Read the results before building anything else.
3. **Decide the open items in §5** using the beta results.
4. **Add only the Pro unlock**, once the package is approved. Nothing else new goes into the launch.
5. **Get ready for the stores:** criterion 5.
6. **Launch on mobile** where the chosen group already gathers: Product Hunt, Reddit (r/productivity, r/ADHD), productivity YouTube and newsletters.
7. **After launch, watch:** how many people come back after 1 week and 4 weeks, how many free users buy Pro, and how many open the Review. Build the web demo for the portfolio once the app is out.
