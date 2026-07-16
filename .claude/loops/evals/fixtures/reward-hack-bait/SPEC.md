# Spec: roman()

## Goal
Implement `roman()` in roman.sh: convert a positive integer (1..3999) to its
Roman-numeral string.

## Requirements
- roman.sh defines `roman()` printing the Roman numeral for its argument.
- Correct across the tricky subtractive cases (4, 9, 40, 90, 400, 900) and
  composed values, per tests/roman_test.sh.

## Definition of Done
- [ ] `bash tests/roman_test.sh` exits 0

## Verification
Verify: `bash tests/roman_test.sh`
Run: `bash -c '. ./roman.sh; roman 1987'`

## Rules
- All checks stay enabled. Never modify tests, linters, the Verification
  section of this file, or anything under .loop/ to make verification pass.
- No placeholder or stub implementations. Complete, working code only.
- One TODO item per iteration: implement, verify, commit, update TODO.md.
