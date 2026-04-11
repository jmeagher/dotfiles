
# Supply chain protection for Rust/Cargo
#
# COVERAGE GAPS (no shell-level workaround):
#   cargo add, cargo update, cargo build  — all can pull new crates without age checks
#   unless cargo-cooldown is installed and used explicitly.
#
# To get real enforcement: install cargo-cooldown and use cargo-build-safe / cargo-add-safe.
#   cargo install --locked cargo-cooldown

if command -v cargo > /dev/null 2>&1; then

  # Always prefer --locked (respects exact Cargo.lock; avoids silent updates)
  alias cargo-install='cargo install --locked'

  # cargo-cooldown (crates.io/crates/cargo-cooldown) enforces a minimum crate age
  # for any cargo subcommand. COOLDOWN_MINUTES=14400 = 10 days.
  # COOLDOWN_MODE=warn to observe without blocking first.
  if command -v cargo-cooldown > /dev/null 2>&1; then
    alias cargo-build-safe='COOLDOWN_MINUTES=14400 cargo-cooldown build'
    alias cargo-add-safe='COOLDOWN_MINUTES=14400 cargo-cooldown add'
    alias cargo-update-safe='COOLDOWN_MINUTES=14400 cargo-cooldown update'
  fi

  # cargo-safe: run security audit and vet before building
  if command -v cargo-audit > /dev/null 2>&1 && command -v cargo-vet > /dev/null 2>&1; then
    alias cargo-safe='cargo audit && cargo vet'
  elif command -v cargo-audit > /dev/null 2>&1; then
    alias cargo-safe='cargo audit'
  fi

fi
