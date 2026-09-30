# ClaudeUsage

Menubar app showing Claude Code 5-hour / weekly limit usage (`42% · 18%`) plus local token and cost stats.

## Installation

### Homebrew

```bash
brew tap PhilRoli/tap
brew install --cask claudeusage
```

ClaudeUsage is ad-hoc signed (not notarized). On first launch, right-click the app in Finder and choose "Open" to bypass Gatekeeper, or run:

```bash
xattr -dr com.apple.quarantine /Applications/ClaudeUsage.app
```

On first launch macOS asks for Keychain access for `security`: choose "Always Allow".

## How it works

- Limits: Anthropic OAuth usage endpoint, token read from the `Claude Code-credentials` Keychain item via `/usr/bin/security` (read-only). Undocumented endpoint — may change.
- Local stats: `~/.claude/projects/**/*.jsonl`, last 30 days. Costs are estimates from `PricingTable.swift`; `+` marks tokens from models missing from the table.

## Development

- Build + install locally: `./rebuild.sh` (installs to /Applications, ad-hoc signed).
- Tests: `swift test`. Lint: `swiftlint --strict`.
- Release: push a tag `vX.Y.Z`. The Release workflow builds a universal app, publishes `ClaudeUsage-X.Y.Z.app.zip` and updates `Casks/claudeusage.rb` in `PhilRoli/homebrew-tap` (needs the `HOMEBREW_TAP_TOKEN` repo secret).
- Regenerate the icon: `scripts/make-icon.sh`.
