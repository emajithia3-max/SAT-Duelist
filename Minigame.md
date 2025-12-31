SAT Duelist — Minigame Authoring Documentation (Swift)

Version 1.0 | JSON-Driven | Production-Ready

Canonical Dependency: Author.md
All question formats, topic strings, section enums, and validation rules are defined exclusively in Author.md.
This document assumes Author.md exists at the project root and must be read before any code generation.

Table of Contents

Overview

Global UI / UX Requirements

Post-Processing Pipeline (All Games)

Haptics & Audio Rules

Question Bank Contract (via Author.md)

Scope Selection Modes

Question Loading & Randomization

Minigame Runtime Contract

Minigame Input / Output API

Game Loop & Scoring

Required Minigame Behaviors

Error Handling & Fallbacks

Validation Checklist

1. Overview

SAT Duelist consists of multiple self-contained Swift minigames.
Each minigame:

Reads questions from the SAT JSON bank defined in Author.md

Supports Anything Goes, Section-only, and Topic-specific play

Is visually and haptically polished

Shares a unified cinematic rendering pipeline

No minigame may hardcode questions.

2. Global UI / UX Requirements (MANDATORY)

All minigames must follow a consistent interaction language.

Core UI

Card-based question surface

Rounded corners

Soft depth shadow

Elevated “physical” feel

Clear hierarchy:

Section / Topic (small)

Question (primary)

Answers (interactive)

Motion & Transitions

Card slide + fade between questions

Subtle scale-in on new question

Micro-tilt / parallax on drag

Wrong answer: slight shake + desaturation pulse

Correct answer: glow + light scale pop

3. Post-Processing Pipeline (REQUIRED)

Every minigame must render inside a shared CinematicContainer.

Effects (Always On)

Vignette (subtle, constant)

Bloom (subtle; accent + correct feedback)

Motion blur (triggered during fast transitions)

Optional: very light film grain / noise

Rules

Post-processing is not implemented per game

All games use the same rendering wrapper

Effects may be parameterized but must share defaults

Acceptable implementations:

Metal shaders

Core Image filter stack

SpriteKit / SceneKit compositing layer

4. Haptics & Audio Rules
Haptics (REQUIRED)
Event	Haptic
Answer tap	Light impact
Correct	Success
Incorrect	Error
Timer warning	Warning
Game start / end	Subtle impact
Audio (Recommended)

Soft UI ticks

Correct chime

Incorrect dull hit

Routed through a shared SoundManager

5. Question Bank Contract (via Author.md)

All question files must:

Conform exactly to the schema in Author.md

Use canonical section and topic strings

Support:

multiple_choice

student_produced_response

Minigames must assume mixed question types unless explicitly filtered.

6. Scope Selection Modes

Minigames must support the following scopes:

A) Anything Goes

All question files

English + Math

All topics

B) Section Only

All files where:

section == "Reading and Writing" OR

section == "Math"

C) Topic Specific

All questions whose topic matches the selected canonical topic

Topic selection must be section-consistent

7. Question Loading & Randomization
Loading Rules

Non-blocking (background thread)

May preload metadata or lazy-load

Must tolerate malformed files

Randomization Rules

Uniform random selection across the active pool

Track recently used question IDs

Avoid repeats within a session when possible

Fallback

Skip invalid questions

Skip invalid files

If pool becomes empty → show error UI and exit cleanly

8. Minigame Runtime Contract

Each minigame acts as a consumer of a shared QuestionEngine.

Runtime Loop

Request next question

Render question card

Accept input

Evaluate answer

Play feedback (animation + haptic)

Update score / timer

Transition to next question

9. Minigame Input / Output API
Inputs
GameMode
ScopeSelection {
  anythingGoes: Bool
  section: String?
  topic: String?
}
SessionConfig {
  questionCount?: Int
  timeLimit?: TimeInterval
  allowSPR: Bool
}

Outputs
SessionResult {
  totalAnswered: Int
  correctCount: Int
  accuracy: Double
  maxStreak: Int
  timeSpent: TimeInterval
  perTopicBreakdown?: [String: Int]
  missedSkills?: [String]
}

10. Game Loop & Scoring
Default Scoring

Correct: +1

Incorrect: +0

Minigames may add bonuses (speed, streaks) but must not penalize learning.

11. Required Minigame Behaviors

All minigames must:

Render MCQs (4 options)

Render SPR input (numeric/text)

Display section + topic label

Display optional difficulty badge

Auto-advance or tap-to-continue (configurable)

Never crash on bad data

12. Error Handling & Fallbacks

Minigames must gracefully handle:

Missing fields

Invalid question_type

Wrong answer count mismatch

Empty question text

Strategy:

Skip bad question

Log internally

Exit session if pool exhausted

13. Validation Checklist (SHIP-BLOCKING)

 Reads JSON strictly per Author.md

 Anything Goes works

 Section filtering works

 Topic filtering works

 MCQ + SPR both supported

 Animations present

 Haptics present

 CinematicContainer applied

 No UI thread blocking

 Graceful failure paths

FINAL AUTHORITY STATEMENT

Author.md is the single source of truth for SAT content.

This document governs how games consume that content.

Any conflict → Author.md wins.
