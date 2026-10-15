---
name: git-committer
description: Plans small, independently reviewable conventional commits from a git diff
---

# Planning reviewable commits

## Instructions

1. Run `git status --short`, `git diff`, and `git diff --staged` to inspect changes. Inspect untracked files so their contents are represented.
2. If any files are staged, base the plan only on staged changes, including staged additions. Otherwise, plan from unstaged changes and untracked files.
3. Read the last 5 to 10 commit subjects to match repository style.
4. Group changes into the smallest reasonable functional commits:
   - Put one coherent functional change in each commit.
   - Make every commit independently reviewable and, where practical, buildable and testable.
   - Keep tests with the change they verify.
   - Order commits so prerequisites land before changes that depend on them.
   - Keep tightly coupled changes together when splitting would leave a confusing or broken intermediate commit.
5. When different commits contain changes to the same file, assign each changed line or hunk to the commit it belongs to. Do not assign the whole file to one commit by default. Use partial staging such as `git add -p`; split hunks or edit a patch when one hunk contains lines for different commits.
6. For each proposed commit, provide:
   - Its functional purpose.
   - The exact files and, for shared files, the hunks or line ranges to include.
   - One conventional, single-line commit subject.
7. If no clean, independently reviewable split exists, recommend one commit and briefly explain why.
8. When staging or committing, inspect `git diff --staged` before each commit to verify it contains only that commit's assigned changes.

## Commit subjects

- Use present tense.
- Follow conventional commit format, such as `feat: Add review context assembly`.
- Capitalize the first word after the type prefix unless it begins with a symbol or code identifier.
- Keep each subject to one line and summarize only its commit's functional change.
