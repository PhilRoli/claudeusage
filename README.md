# ClaudeUsage

Menubar app showing Claude Code 5-hour / weekly limit usage (`42% · 18%`) plus local token and cost stats.

- Limits: Anthropic OAuth usage endpoint, token read from the `Claude Code-credentials` Keychain item via `/usr/bin/security` (read-only). Undocumented endpoint — may change.
- Local stats: `~/.claude/projects/**/*.jsonl`, last 30 days. Costs are estimates from `PricingTable.swift`; `+` marks tokens from models missing from the table.
- Build + install: `./rebuild.sh` (installs to /Applications, ad-hoc signed). Tests: `swift test`.
- First launch: choose "Always Allow" on the Keychain prompt.
