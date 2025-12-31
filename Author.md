# SAT Digital 2026 — Question Authoring & Generation Specification

**FINAL · CLOSED WORLD · PRODUCTION READY**

This document defines the complete structural, semantic, pedagogical, and legal rules for generating **original** SAT Digital (2026) practice questions in JSON format.

It is intended for:

* AI question-generation agents
* Human editors
* Automated validators
* Adaptive testing systems
* Scoring and analytics pipelines

**No assumptions are allowed outside this document.**

---

## ⚠️ LEGAL & COPYRIGHT SAFETY OVERRIDE (CRITICAL)

The system MAY reference *example SAT-style questions* provided in `Examples.md` **ONLY** for:

* Tone calibration
* Difficulty calibration
* Structural patterns (length, format, phrasing style)
* SAT-typical cognitive demand

The system MUST:

* ❌ **NEVER copy** any sentence, clause, structure, numeric setup, variable configuration, or answer choice from the examples
* ❌ **NEVER paraphrase** an example question
* ❌ **NEVER reuse** distinctive numbers, contexts, scenarios, or entities
* ❌ **NEVER mirror** answer choice patterns or traps from a specific example

The examples are **REFERENCE-ONLY STYLE GUIDES**, not templates.

✅ Every generated question must be:

* Fully original
* Independently constructed
* Legally non-derivative
* Safe for commercial distribution

**If a generated question could be plausibly traced back to an example, it MUST be rejected.**

This is a hard safety requirement.

---

## TABLE OF CONTENTS

1. Overview
2. Digital SAT Context (2026)
3. Core Design Principles
4. File-Level Rules
5. Canonical JSON Schema
6. Question Object Schema
7. Field Definitions (STRICT)
8. Multiple Choice Rules
9. Student-Produced Response (SPR) Rules
10. Difficulty Philosophy
11. Skill Construction Rules
12. Section-Specific Writing Rules
13. Canonical Sections & Topics Registry (2026-ALIGNED)
14. Weighting & Coverage Alignment
15. AI Authoring Prompt (Drop-In)
16. Validation Checklist
17. Common Failure Modes (AI)

---

## 1. Overview

This system generates **SAT-style practice questions** aligned to the **Digital SAT 2026** as administered via College Board’s **Bluebook** app.

All generated questions must be:

* Independent
* Deterministic
* SAT-legal
* Machine-parseable
* Original (non-derivative)
* Scalable to tens of thousands of items

---

## 2. Digital SAT Context (2026)

### Sections

* **Reading & Writing (RW)** — 64 minutes, 54 questions
* **Math** — 70 minutes, 44 questions

### Question Types

* RW: Discrete multiple-choice only
* Math: Multiple-choice (~75%) + Student-Produced Response (~25%)

### Adaptive Structure

* Two modules per section
* Module 2 adapts in difficulty

⚠️ This system generates **module-agnostic** questions. Adaptivity is handled downstream.

---

## 3. Core Design Principles

* One Topic per File
* One Skill per Question
* Exactly One Correct Answer
* No Ambiguity
* No Trickery
* SAT-Realistic Difficulty
* Closed Vocabulary for Topics & Sections
* **Original construction required at all times**

---

## 4. File-Level Rules

### One File = One Topic

Each JSON file:

* Covers exactly **one SAT topic**
* Contains multiple questions
* Shares metadata across all questions

### Valid Filenames

```
rw_words_in_context.json
rw_standard_english_boundaries.json
math_linear_equations.json
math_problem_solving_data_analysis.json
```

---

## 5. Canonical JSON Schema

```json
{
  "_meta": "SAT Question Bank | Digital SAT 2026",
  "section": "Reading and Writing | Math",
  "topic": "string",
  "exam": "SAT",
  "year": 2026,
  "questions": []
}
```

---

## 6. Question Object Schema

```json
{
  "id": "string",
  "question_type": "multiple_choice | student_produced_response",
  "difficulty": "easy | medium | hard",
  "skill": "string",
  "question": "string",
  "correct_answer": "string",
  "wrong_answers": ["string", "string", "string"],
  "explanation": "string"
}
```

---

## 7. Field Definitions (STRICT)

### File-Level Fields

| Field     | Required | Rules                     |
| --------- | -------- | ------------------------- |
| _meta     | ✅        | Versioning only           |
| section   | ✅        | Must match Section Enum   |
| topic     | ✅        | Must match Topic Registry |
| exam      | ✅        | Always "SAT"              |
| year      | ✅        | Always 2026               |
| questions | ✅        | Non-empty array           |

### Question-Level Fields

| Field          | Required | Rules                         |
| -------------- | -------- | ----------------------------- |
| id             | ✅        | Unique within file            |
| question_type  | ✅        | MCQ or SPR only               |
| difficulty     | ✅        | easy / medium / hard          |
| skill          | ✅        | One atomic skill              |
| question       | ✅        | SAT-style phrasing (original) |
| correct_answer | ✅        | Exactly one                   |
| wrong_answers  | ⚠️       | 3 for MCQ, empty for SPR      |
| explanation    | ✅        | Clear SAT-style rationale     |

---

## 8. Multiple Choice Rules (CRITICAL)

If `question_type = "multiple_choice"`:

⚠️ **MANDATORY**: `wrong_answers.length === 3`

* Exactly **three** wrong answers
* No more, no fewer

All answer choices must:

* Be plausible
* Match grammar, units, and format
* Be non-empty strings

❌ No "All of the above"
❌ No "None of the above"
❌ No trick giveaways
❌ No empty wrong answers

---

## 9. Student-Produced Response (SPR) Rules

If `question_type = "student_produced_response"`:

* `wrong_answers` **must be empty**
* `correct_answer` must be:

  * Unambiguous
  * Minimal (number, expression, or short phrase)

Explanation must show:

* Method
* Common SAT pitfall avoided

---

## 10. Difficulty Philosophy

Difficulty reflects **cognitive load**, not obscurity.

| Difficulty | Meaning                       |
| ---------- | ----------------------------- |
| Easy       | Direct application            |
| Medium     | Translation + setup           |
| Hard       | Multi-step or common SAT trap |

❌ Difficulty must NOT come from:

* Obscure vocabulary
* Non-SAT math
* Artificial trick phrasing

---

## 11. Skill Construction Rules

Each question tests **exactly one atomic skill**.

### Skill String Rules

* Start with a verb
* Describe one specific action
* More specific than the topic

**Good**

* "Solve linear equations in one variable"
* "Identify subject-verb agreement errors"
* "Select appropriate transitions"

**Bad**

* "Grammar"
* "Algebra"
* "Math reasoning"

---

## 12. Section-Specific Writing Rules

### Reading & Writing (RW)

* Short passages only
* One question per passage
* Academic but concise tone
* Vocabulary always tested **in context**
* No literary analysis

### Math

* No calculus
* No imaginary numbers
* Calculator-allowed assumptions valid
* Clean, SAT-realistic numbers
* Concise word problems

---

## 13. Canonical Sections & Topics Registry

### 13.1 Section Enum

```
["Reading and Writing", "Math"]
```

### 13.2 Reading & Writing — Topics

**Craft and Structure (~28%)**

* Words in Context
* Text Structure and Purpose
* Cross-Text Connections

**Information and Ideas (~26%)**

* Central Ideas and Details
* Command of Evidence
* Quantitative Information

**Standard English Conventions (~26%)**

* Sentence Boundaries
* Form, Structure, and Sense

**Expression of Ideas (~20%)**

* Rhetorical Synthesis
* Transitions

### 13.3 Math — Topics

**Algebra (~35%)**

* Linear Equations in One Variable
* Linear Equations in Two Variables
* Linear Functions
* Systems of Linear Equations
* Linear Inequalities

**Advanced Math (~35%)**

* Equivalent Expressions
* Nonlinear Equations
* Systems of Nonlinear Equations
* Nonlinear Functions

**Problem Solving and Data Analysis (~15%)**

* Ratios and Rates
* Percentages
* Units and Conversions
* One-Variable Data
* Two-Variable Data
* Probability
* Statistical Inference
* Evaluating Statistical Claims

**Geometry and Trigonometry (~15%)**

* Area and Volume
* Lines and Angles
* Triangles
* Right Triangle Trigonometry
* Circles

---

## 14. Weighting & Coverage Alignment

Weighting is enforced at the **dataset level**, not the file level.

---

## 15. AI Authoring Prompt (DROP-IN)

```
Generate original SAT Digital 2026 practice questions following the SAT Question Authoring Specification.

You MAY reference example questions only to calibrate tone and difficulty.
You MUST NOT copy, paraphrase, mirror, or structurally imitate any example question.

Constraints:
- One topic only (from registry)
- Deterministic answers
- SAT-legal content only
- Valid JSON only

Requirements:
- Mix easy / medium / hard
- One skill per question
- Correct wrong-answer counts
- Fully original construction
- Include explanations
```

---

## 16. Validation Checklist (CRITICAL)

### Structural

* JSON parses
* Section valid
* Topic valid
* No duplicate IDs
* Wrong answer count correct

### Content

* One correct answer
* Skill matches question
* Difficulty appropriate
* SAT-legal concepts only
* **No derivative resemblance to examples**

---

## 17. Common AI Failure Modes

❌ Invented topics
❌ Vague skills
❌ Ambiguous correct answers
❌ Wrong MCQ count
❌ Overly clever tricks
❌ Non-SAT math
❌ Copyright-derivative questions
