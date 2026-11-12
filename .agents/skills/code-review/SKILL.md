---
name: code-review
description: "Review a branch, PR, or work-in-progress diff against standards and spec, with impact-based depth, focused follow-up reviews, and an explicit merge-readiness verdict."
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

Use `docs/agents/issue-tracker.md` when present; otherwise use the repository and issue workflow named in `AGENTS.md`.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Resolve and record the merge-base SHA and reviewed head SHA. Capture the diff between those immutable SHAs and the commit list. For work-in-progress reviews, also include staged and unstaged changes and relevant untracked files; record their patch/content snapshot so later rounds can identify exactly what changed. A committed diff alone does not cover work-in-progress changes.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the selected diff is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

### 1a. Classify impact and freeze the review contract

The author proposes one class with a short rationale; the reviewer confirms or corrects it before investigating. If absent, infer it from affected contracts, consumers, and failure impact and record the rationale. Use the highest applicable class, independent of file count or PR size.

| Class | Impact | Required review scope and evidence |
| --- | --- | --- |
| Leaf | Local behavior with limited reach; no shared contract changes | Changed behavior and direct callers; focused tests or an appropriate documented manual check. |
| Branch | Feature or subsystem with bounded consumers | Leaf checks plus acceptance criteria, subsystem boundaries, failure paths, and affected integration checks. |
| Trunk | Shared infrastructure or contracts used across features | Branch checks plus identified downstream consumers, compatibility, shared failure handling, and representative cross-feature checks. |
| Root | Foundations such as trust model, persistence guarantees, or architecture | Trunk checks plus design assumptions, system failure modes, and applicable security, migration, recovery, and rollback evidence. |

Escalate beyond Leaf for security-sensitive behavior, potential data loss, public compatibility, migrations, or changes to shared dependencies. Set the final class by reach and consequences: a local input-validation fix can be Branch; an authentication trust-model change is Root even if one line. Shared cross-feature dependencies warrant at least Trunk. Explain each escalation.

Before review, record a finite contract: class and rationale, base/head or WIP snapshot, spec source, affected boundaries, applicable checks, and required evidence. Mark inapplicable checks with a reason. Documentation and workflow changes can use consistency checks and representative walkthroughs instead of runtime tests. New review requirements need an evidenced risk or material scope change and an explicit contract update.

Depth determines investigation and evidence, not a quota of findings. Every class uses the same blocker threshold and completion rule below.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

Give both reviewers the review contract and the blocker, convergence, and reporting rules below. On follow-up rounds, also pass the previous report, finding IDs, previous snapshot, and changes since that snapshot. Their scope is the current review round, not an automatic restart of the full diff.

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Review the agreed scope. Report substantiated blockers together, citing the documented standard and concrete impact for each. Keep possible baseline smells and preferences optional unless independent evidence establishes a blocker. A documented repo standard overrides the baseline. Skip anything tooling enforces; record required tooling results separately. Use the finding format below; concise evidence takes priority over a word limit."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Review the agreed scope for missing, partial, or incorrectly implemented requirements and material scope violations. Cite the requirement and concrete impact for each blocker. Keep improvements beyond the agreed requirements optional. Use the finding format below; concise evidence takes priority over a word limit."

If the user confirms there is no spec, skip the Spec sub-agent and note this limitation. Record available acceptance criteria in the contract. A missing source needed to verify a requirement remains missing required evidence.

### Blockers and optional suggestions

A blocker is an evidenced correctness defect, security risk, unmet agreed requirement, or material breach of a documented standard. Each needs a specific location, source requirement or rule where applicable, a reproducible trigger or concrete reasoning, actual impact, and the smallest reasonable fix. A speculative concern, naming preference, or code smell alone is optional. A documented-standard breach needs a material consequence to block; stylistic preferences remain optional.

Assign stable IDs (`STD-1`, `SPEC-1`) and retain them across rounds. For each finding record axis, blocker/optional, evidence, impact, proposed fix, and open/resolved status. Deduplicate the same underlying defect across axes by referencing its ID; retain both axes' assessment and count the blocker once in the overall verdict.

### Follow-up reviews and convergence

Complete the initial investigation against the contract and report all substantiated findings together. Zero findings is a valid result.

After fixes, inspect the delta since the previous reviewed snapshot, verify each previous blocker, and check affected paths for regressions caused by those fixes. Resolve findings with evidence and retain unresolved IDs. Reopen unchanged code only for a newly discovered, evidenced blocker; explain the discovery and its connection to the agreed scope. Unrelated improvements remain optional follow-ups.

Material scope changes require an updated class and contract, followed by review of the newly affected scope. Otherwise, retain the original scope and checks. Repeated rounds trigger a scope/evidence reassessment, never automatic approval or an automatic broad restart. Round count alone neither approves a PR nor requires more review.

### 5. Aggregate

Report the class/rationale, reviewed snapshot, and contract check results (passed, failed, pending, or inapplicable with reason). Present `## Standards` and `## Spec` separately, each with blockers, optional suggestions, and resolved IDs. Preserve the two assessments; neither axis can cancel a blocker in the other.

End every completed review with exactly one explicit verdict:

- **READY TO MERGE — 0 unresolved blockers.** All applicable required checks passed, required evidence is present, and both axes completed or their agreed limitations are recorded. Optional suggestions may remain. Stop reviewing this snapshot.
- **CHANGES REQUIRED — N unresolved blockers.** List the open IDs and any failed, pending, or missing required checks/evidence with the specific action needed. Missing evidence prevents readiness even when N is zero; state that reason explicitly.

Readiness applies only to the recorded snapshot and is not an instruction to merge. Subsequent changes need the focused follow-up review above. Never invent findings to fill a report or withhold readiness solely for optional improvements.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
