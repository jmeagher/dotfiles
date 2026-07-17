# Spec: verify-gate probe

## Goal
A fixture whose verify command is toggled by the presence of a `PASS` marker
file, used to exercise the Stop-hook verification gate deterministically
(fail → block, pass → unblock, three strikes → disarm).

## Verification
Verify: `bash check.sh`
Run: `bash check.sh`

## Rules
- All checks stay enabled. Never modify tests, the Verification section, or
  anything under .loop/ to make verification pass.
