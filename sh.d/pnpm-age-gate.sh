
# Supply chain protection for pnpm.
# pnpm does not read ignore-scripts or min-release-age from .npmrc.
# These must be set via pnpm's own config.
#
# Checks the actual config values on each shell start and self-heals if they've
# been wiped (e.g., pnpm config delete, new pnpm store, machine restore).
# Cost: one 'pnpm config get' call per shell start — fast.

if command -v pnpm > /dev/null 2>&1; then

  _pnpm_expected_age=14400  # minutes = 10 days

  _pnpm_current_age="$(pnpm config get minimum-release-age 2>/dev/null)"
  if [ "$_pnpm_current_age" != "$_pnpm_expected_age" ]; then
    pnpm config set minimum-release-age "$_pnpm_expected_age" --global 2>/dev/null
  fi

  _pnpm_current_scripts="$(pnpm config get ignore-scripts 2>/dev/null)"
  if [ "$_pnpm_current_scripts" != "true" ]; then
    pnpm config set ignore-scripts true --global 2>/dev/null
  fi

  unset _pnpm_expected_age _pnpm_current_age _pnpm_current_scripts

fi
