#!/usr/bin/env bash
# Verify passes only when a PASS marker file exists in the workdir. The eval
# toggles that marker to drive the gate: absent -> fail -> block; present ->
# pass -> unblock.
[ -f PASS ]
