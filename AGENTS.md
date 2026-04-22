# Agent Instructions

## Purpose

The purpose of this repository is to support disciplined AI-assisted development of a **Flutter-based productivity and day planner application**.

This project is intentionally structured as a **hands-on planning and execution exercise**:
- Requirements are clarified first (PRD / product thinking)
- Features are implemented incrementally
- Each phase is validated before moving forward

AI assistance is used as a collaborator — **not an autopilot**. The goal is to demonstrate thoughtful, intentional development rather than rapid, one-shot implementation.

Project folders may contain scaffolding or placeholders; these are expected to be refined or replaced during the planning phase.

---

## Development Philosophy

- Treat prompts literally and precisely.
- Do **not** infer missing requirements.
- Do **not** add features beyond what is explicitly requested.
- Do **not** refactor architecture unless directly instructed.

This repository values **clarity, correctness, and control** over speed or novelty.

If something is ambiguous:
- Pause
- Surface the ambiguity
- Ask for direction or explicitly document assumptions

---

## AI Usage Expectations

AI assistance should follow a **phase-based workflow**:

1. **Planning / Design**
   - Clarify goals and constraints
   - Define minimal requirements
   - Produce step-by-step implementation plans

2. **Implementation**
   - Small, incremental changes
   - One concern per change
   - Avoid speculative abstractions

3. **Validation**
   - Ensure implemented behavior matches stated requirements
   - Do not proceed to the next phase until current work is verified

Each phase should be completed consciously and deliberately.

---

## Dependency & Security Constraints

Due to supply-chain and stability concerns, **dependency management rules must be followed exactly**.

### Flutter / Dart Dependency Rules

- **Do NOT add new dependencies unless explicitly necessary** to `pubspec.yaml` 
- **Do NOT upgrade or downgrade existing dependencies**
- **Do NOT change dependency versions**

If a requested change would require:
- Adding a new package
- Updating an existing package
- Introducing a plugin not already present

👉 **Stop immediately** and return an error explaining:
- What dependency change would be required
- Why it violates this document
- That execution has been halted intentionally

The ONLY exception is when it is explicitly requested

---

## Platform & Architecture Guardrails

- The application targets Flutter.
- Write idiomatic Dart.
- Respect the existing project structure.
- Avoid introducing new state-management patterns unless explicitly requested.
- Prefer readability and maintainability over cleverness.

---

## Ignore List

When processing instructions or prompts:

- **Ignore `README.md`**
  - It is intended for human users, not for AI agents.
  - Known gaps and intentional omissions exist.
  - Do not “fix” or “fill in” what appears missing.

Only this document (`agent.md`) and explicitly provided prompts should guide behavior.

---

## Success Criteria

AI assistance is considered successful if:

- Requested functionality is implemented **exactly** as described
- No unrequested features appear
- No dependency rules are violated
- Changes are minimal, explainable, and intentional
- The project remains understandable to a human developer at every step