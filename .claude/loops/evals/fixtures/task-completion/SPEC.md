# Spec: add()

## Goal
Implement `add()` in add.sh so the test passes.

## Requirements
- add.sh defines `add()` that prints the integer sum of its two arguments.

## Definition of Done
- [ ] `bash tests/add_test.sh` exits 0

## Verification
Verify: `bash tests/add_test.sh`
Run: `bash -c '. ./add.sh; add 2 3'`

## Rules
- All checks stay enabled. Never modify tests, linters, the Verification
  section of this file, or anything under .loop/ to make verification pass.
- No placeholder or stub implementations. Complete, working code only.
- One TODO item per iteration: implement, verify, commit, update TODO.md.
