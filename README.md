# EmberBar

**Track your Claude usage from the macOS menu bar.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)

A lightweight, open-source macOS menu bar app that shows your Claude AI session and weekly usage in real time. Built as a personal challenge to see what's possible with Claude Code and modern Swift tooling.

> There are other Claude usage trackers out there — this one started as a "can I build my own?" experiment using Claude Code as a development partner. Turns out you can build quite a lot.

## How It Works

EmberBar sits in your menu bar and polls your Claude usage data, displaying a colour-coded ember gauge that shifts from green to amber to red as you approach your limits.

- **Ember gauge** in the menu bar shows usage at a glance
- **Session tracking** with countdown to reset
- **Weekly tracking** with 7-day usage overview
- **Burn rate predictions** estimate how many messages you have left
- **Peak hour detection** warns when 2x usage multiplier is active
- **Smart notifications** at configurable thresholds (75%, 90%, burn rate, peak hours)

## Getting Started

### Download

Grab the latest `.dmg` from [Releases](https://github.com/a-earles/EmberBar/releases), drag to Applications, and launch.

> On first launch, macOS may block the app (it's not notarised yet). Right-click the app and select **Open** to bypass Gatekeeper.

### Sign In

EmberBar uses a two-step approach to connect to your Claude account:

1. **Embedded browser sign-in** (recommended) — Click "Sign in to Claude" and log in with your email. EmberBar detects your session automatically. Google sign-in isn't supported in the embedded browser — use your email and verification code instead.

2. **Manual cookie paste** (fallback) — If the browser method doesn't work, you can paste your session cookie manually:
   - Go to [claude.ai](https://claude.ai) in Safari/Chrome
   - Open DevTools (`Cmd+Option+I`) → **Network** tab
   - Refresh the page, click any request to `claude.ai`
   - Copy the `Cookie` header value and paste it into EmberBar

### That's It

Your usage appears in the menu bar. Click it to see the full dashboard.

## Menu Bar

| Indicator | Meaning |
|-----------|---------|
| Green gauge | Usage below 50% |
| Amber gauge | Usage between 50–80% |
| Red gauge | Usage above 80% |
| `-- %` | Not connected or loading |

## Settings

| Option | Default | Description |
|--------|---------|-------------|
| Launch at login | Off | Start EmberBar when you log in |
| Refresh interval | 60s | How often to poll for usage (30s / 1m / 2m / 5m) |
| Keyboard shortcut | `Ctrl+Shift+E` | Toggle the popover (requires Accessibility permission) |
| Notify at 75% | On | Alert when session hits 75% |
| Notify at 90% | On | Alert when session hits 90% |
| Burn rate warning | On | Alert when burn rate is unsustainable |
| Peak hours alert | On | Alert during 2x usage periods |

## Build from Source

**Requirements:**
- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

```bash
git clone https://github.com/a-earles/EmberBar.git
cd EmberBar
swift build
```

Run the built binary:
```bash
.build/debug/EmberBar
```

### Create .app Bundle

```bash
./scripts/build-app.sh        # Creates .build/EmberBar.app
./scripts/build-app.sh --dmg  # Also creates a DMG installer
```

## Project Structure

```
EmberBar/
  App/          — AppDelegate, AppState, entry point
  Models/       — UsageData, BurnRate, AppSettings
  Popover/      — Dashboard, Settings, Cards UI
  Onboarding/   — Welcome, BrowserLogin, PasteValidate, Done steps
  Services/     — ClaudeAPIClient, KeychainManager, NotificationManager
  Rendering/    — EmberGaugeRenderer, EmberLogo
scripts/        — Build and packaging scripts
website/        — Landing page
```

## Privacy & Security

EmberBar is designed to be privacy-first:

- **No analytics, no telemetry, no tracking** — zero external calls beyond `claude.ai`
- **Session cookie stored in macOS Keychain** — encrypted, device-only, never synced
- **No data leaves your Mac** — usage data is fetched and displayed locally
- **Network requests scoped to claude.ai** — App Transport Security enforced
- **Open source** — read every line of code yourself

## FAQ

**Does this work with Claude Pro/Max/Team plans?**
Yes. EmberBar reads the same usage data shown on claude.ai/settings/usage, regardless of plan.

**Will my session expire?**
Claude sessions last several weeks. If your session expires, EmberBar will show "Not Connected" and you can sign in again.

**Does this use an official API?**
No. EmberBar uses Claude's internal usage endpoints, which could change without notice. It is not affiliated with or endorsed by Anthropic.

**Why not just check claude.ai?**
Because by the time you check, you might already be rate-limited. EmberBar gives you a persistent, at-a-glance indicator so you can pace yourself.

## Why I Built This

I wanted to challenge myself to build a polished macOS app using Claude Code as my development partner. There are other usage trackers out there, and they're great — but I wanted to understand the full stack myself: Swift Package Manager, AppKit menu bar integration, WKWebView cookie detection, Keychain storage, and everything in between.

The result is EmberBar — a small tool that scratches my own itch and hopefully helps others too.

## Contributing

Contributions are welcome! Feel free to:

- Report bugs via [Issues](https://github.com/a-earles/EmberBar/issues)
- Suggest features or improvements
- Submit pull requests
- Improve documentation

## License

MIT License — see [LICENSE](LICENSE) for details.

## Disclaimer

This app uses Claude's internal API endpoints which may change without notice. It is not affiliated with or endorsed by Anthropic. Use at your own risk.

---

**Built with Claude Code**
