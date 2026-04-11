
# Supply chain protection for Ruby/Bundler
# gem.coop provides a 48-hour built-in cooldown (not 10 days — best available for Ruby).
#
# IMPORTANT: ~/.gemrc source ordering is ignored by Bundler when a Gemfile has
# an explicit `source "https://rubygems.org"` line — which every real project does.
# The only way to enforce gem.coop for Bundler without editing every Gemfile is the
# global mirror config below, which rewrites sources at fetch time transparently.

if command -v bundle > /dev/null 2>&1; then

  # Set gem.coop as a transparent mirror for rubygems.org in Bundler.
  # This rewrites all `source "https://rubygems.org"` Gemfile lines at fetch time
  # so existing projects get the cooldown without manual Gemfile edits.
  # Self-heals if the config is wiped.
  _bundle_mirror="$(bundle config get mirror.https://rubygems.org 2>/dev/null)"
  if [ "$_bundle_mirror" != "https://gem.coop/" ] && [ "$_bundle_mirror" != "https://gem.coop" ]; then
    bundle config set --global mirror.https://rubygems.org https://gem.coop/ 2>/dev/null
  fi
  unset _bundle_mirror

  if command -v bundle-audit > /dev/null 2>&1; then
    # Update advisory DB and check current Gemfile.lock for known CVEs
    alias bundle-audit-update='bundle-audit update && bundle-audit check'
  fi

fi
