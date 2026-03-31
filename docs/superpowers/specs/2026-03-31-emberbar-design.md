# EmberBar — Design Spec

**macOS menu bar app for tracking Claude AI usage with predictive intelligence.**

## Overview

EmberBar is a native macOS menu bar app that gives Claude users real-time visibility into their usage limits. It differentiates from the 10+ existing competitors through three features nobody does well: burn rate predictions, peak-hour 2x awareness, and smart contextual notifications.

The name "EmberBar" reflects the core metaphor: a glowing ember in your menu bar that dims as your quota depletes — like a fire burning out.

**Target audience:** Claude Pro and Max subscribers (optimized for Max). All tiers supported.

**Domain:** emberbar.app (available)

## v1 Scope

### In scope
- Ember gauge menu bar icon with percentage
- Dashboard Cards popover layout
- Session + weekly usage tracking with progress bars
- Burn rate predictions (time until limit, estimated messages remaining)
- Peak hour 2x detection and warning
- Smart contextual notifications
- Guided onboarding wizard with cookie validation
- Secure cookie storage in macOS Keychain
- Global keyboard shortcut
- Launch at login
- Stale data indicator

### Explicitly out of scope (v1.1+)
- Configurable menu bar widgets (toggle which data points show)
- Alternative popover layouts (Ring Gauge, Compact Data-Dense)
- Alternative menu bar icon styles (progress bar, text-only)
- Auto-detect cookies from browsers
- Historical analytics / 30-day trends
- Subscription ROI dashboard
- Multi-provider support
- Per-project cost attribution

## Menu Bar Icon

A circular gauge ring with a glowing ember at its center, plus a percentage number beside it.

**Ember semantic: Remaining Fuel.** The ember burns bright when you have plenty of quota left and dims/fades as you run low.

| Usage | Gauge Color | Ember State | Example |
|-------|------------|-------------|---------|
| 0-40% | Green (#4ade80) | Bright, warm glow | `[bright ember] 23%` |
| 40-70% | Yellow-green → amber | Dimming | `[warm ember] 55%` |
| 70-85% | Amber (#f59e0b) | Fading | `[fading ember] 78%` |
| 85-100% | Red (#ef4444) | Barely visible, dying | `[dying ember] 93%` |
| 100% (limit hit) | Gray (#666) | Ash — no glow | `[ash] 100%` |

The percentage shown is session usage by default.

## Popover Layout: Dashboard Cards

Fixed layout for v1. Width: 320px. Dark theme matching macOS dark mode (also supports light mode via system theme).

### Cards (top to bottom):

**Header**
- EmberBar logo/icon + app name
- Plan badge ("Max", "Pro", "Free")

**Session Usage Card**
- "SESSION USAGE" label
- Percentage (color-coded)
- Progress bar (gradient: green → amber → red based on fill)
- "Resets in Xh Xm" on left
- "~N messages left" on right (approximate range, e.g., "~8-15 messages left")

**Burn Rate Card**
- "BURN RATE" label
- Rate indicator: "▲ Fast", "● Moderate", "▼ Light", "— Idle"
- Prediction text: "At this pace, you'll hit your limit in **47 min**"
- Only shows when there's enough data (at least 3 samples). Before that: "Calculating..."

**Weekly Usage Card**
- "WEEKLY USAGE" label
- Percentage (color-coded)
- Progress bar
- "Resets in Xd Xh"

**Peak Hour Warning Card** (conditional — only shown during peak hours)
- Amber background tint with amber border
- Lightning bolt icon
- "Peak Hours Active"
- "Usage may deplete 2x faster until 11am PT"

**Footer**
- "Updated Xm ago" timestamp (stale data indicator)
- "Open Claude" button (opens claude.ai in default browser)
- Settings gear icon
- Refresh button

## Notifications

Native macOS notifications via UserNotifications framework. All configurable on/off in settings.

| Trigger | Message | Default |
|---------|---------|---------|
| Session 75% | "Session 75% used · ~N messages left · resets in Xh Xm" | On |
| Session 90% | "Session 90% used · ~N messages left · resets in Xh Xm" | On |
| Burn rate warning | "At this pace, you'll hit your session limit in ~15 minutes" | On |
| Peak hours start | "Peak hours active — usage may deplete 2x faster until 11am PT" | On |
| Cookie expired | "Session expired — click to update your cookie" | On (always) |

Not included in v1 defaults (but toggleable): 25%, 50% thresholds, peak hours end, session reset.

## Onboarding Flow

A multi-step wizard presented in a standard macOS window (not the popover).

1. **Welcome** — App icon, tagline "Never hit a Claude limit by surprise", "Get Started" button.

2. **Browser instructions** — Text-based steps (no screenshots that go stale):
   - "1. Open claude.ai/settings/usage" (clickable link)
   - "2. Press Cmd+Option+I to open Developer Tools"
   - "3. Click the Network tab"
   - "4. Refresh the page (Cmd+R)"
   - "5. Click the request named 'usage'"
   - "6. Under Request Headers, find 'Cookie' and copy the entire value"

   Each step is a numbered card with clear, bold key terms.

3. **Paste & Validate** — Large text field with "Paste your cookie here" placeholder. "Connect" button.
   - On success: green checkmark, "Connected! You're on the **Max** plan. Session resets in 2h 14m."
   - On failure: red X, "Invalid cookie. Make sure you copied the entire Cookie value, not just part of it." Retry.

4. **Done** — "You're all set! EmberBar is now monitoring your usage." Options: "Launch at Login" toggle (default on), "Finish" button.

Cookie stored in macOS Keychain under service name "com.emberbar.session-cookie".

## Data Layer

### API Integration
- **Endpoint:** `https://claude.ai/api/organizations/{org_id}/usage`
- **Method:** GET with session cookie as Cookie header
- **Org ID:** Extracted from initial auth validation call to `https://claude.ai/api/organizations`
- **Refresh interval:** 60 seconds (default), stored in UserDefaults
- **Response parsing:** Extract session usage %, weekly usage %, per-model data, reset timestamps

### Burn Rate Calculation
- Store last 20 usage samples (timestamp + percentage) in memory
- Compute rolling average: `(current% - oldest%) / (current_time - oldest_time)` = % per minute
- Time to limit: `(100% - current%) / burn_rate_per_minute`
- Messages remaining: `time_to_limit / average_time_between_samples_that_showed_increase`
- Fallback when insufficient increase samples: estimate 1 message ≈ 2-3% session usage (based on typical Opus message cost) and show wider range
- Show as approximate range, not false precision: "~8-15 messages"
- Requires minimum 3 samples before showing predictions
- Reset sample buffer when session resets (usage drops significantly — i.e., current% is 20+ points lower than previous sample)

### Peak Hour Detection
- Check if current time is 5:00 AM - 11:00 AM Pacific Time, Monday-Friday
- Additionally: compare recent burn rate to historical average. If burn rate is >1.5x normal during peak window, confirm 2x is active
- Show peak warning card and optionally notify

### Error Handling
- **401/403 response:** Cookie expired → notify user, show "Update Cookie" button in popover
- **Network error / timeout:** Show last known data with "Updated Xm ago" indicator. Retry on next interval.
- **Rate limiting from API:** Back off to 5-minute intervals, show indicator
- **No data yet (first launch):** Show empty state with "Waiting for first data..." after onboarding
- **Idle state (0% usage):** Show full bright ember, "0% used", burn rate "— Idle". This is the happy state — everything is available.

### Org ID Discovery
- On first successful cookie validation, call `GET https://claude.ai/api/organizations` with the session cookie
- Response contains an array of orgs; use the first org's `uuid` field
- Cache the org_id in UserDefaults (it rarely changes)
- If the orgs call fails, the cookie is likely invalid — treat as auth failure

### Cookie Lifecycle
- Stored in macOS Keychain (encrypted at rest by OS)
- Validated on paste during onboarding
- Re-validated on each API call (check for 401/403)
- User can re-paste or clear cookie from Settings
- Never written to disk as plaintext, never logged, never transmitted to any server other than claude.ai

## Settings

Presented as a standard macOS Settings window (accessible from popover footer or menu bar right-click).

### General
- Launch at login (toggle, default: on)
- Global keyboard shortcut (default: Cmd+Shift+E)
- Refresh interval (slider: 30s / 60s / 2min / 5min, default: 60s)

### Notifications
- Checkbox list of notification triggers (see Notifications section)
- Each can be toggled on/off independently

### Account
- Current plan display
- Cookie status (valid / expired / not set)
- "Update Cookie" button → re-opens cookie wizard
- "Clear Cookie & Sign Out" button

### About
- Version number
- "Check for Updates" (Sparkle framework or manual check)
- Link to website (emberbar.app)
- Link to support/feedback

## Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **Target:** macOS 13+ (Ventura)
- **Frameworks:** AppKit (NSStatusItem, NSPopover), SwiftUI, Security (Keychain), UserNotifications, ServiceManagement (SMAppService for login item)
- **Networking:** URLSession (no third-party HTTP libraries)
- **Updates:** Sparkle framework (only external dependency) — or defer to v1.1
- **Distribution:** Direct download (.dmg) from emberbar.app. Mac App Store possible later.
- **Size target:** Under 5MB
- **No analytics, no telemetry, no data collection.** Privacy-first.

## Project Structure

```
EmberBar/
├── EmberBar.xcodeproj
├── EmberBar/
│   ├── App/
│   │   ├── EmberBarApp.swift          # App entry point, NSApplicationDelegate
│   │   └── AppState.swift             # Shared app state (ObservableObject)
│   ├── MenuBar/
│   │   ├── StatusBarController.swift  # NSStatusItem setup, ember gauge rendering
│   │   └── EmberGaugeView.swift       # Custom drawn ember + gauge icon
│   ├── Popover/
│   │   ├── PopoverView.swift          # Main popover container
│   │   ├── SessionCard.swift          # Session usage card
│   │   ├── BurnRateCard.swift         # Burn rate prediction card
│   │   ├── WeeklyCard.swift           # Weekly usage card
│   │   └── PeakWarningCard.swift      # Peak hour alert card
│   ├── Onboarding/
│   │   ├── OnboardingWindow.swift     # Onboarding window controller
│   │   ├── WelcomeStep.swift
│   │   ├── InstructionsStep.swift
│   │   ├── PasteValidateStep.swift
│   │   └── DoneStep.swift
│   ├── Settings/
│   │   ├── SettingsWindow.swift
│   │   ├── GeneralSettings.swift
│   │   ├── NotificationSettings.swift
│   │   └── AccountSettings.swift
│   ├── Services/
│   │   ├── ClaudeAPIClient.swift      # API calls to claude.ai
│   │   ├── KeychainManager.swift      # Secure cookie storage
│   │   ├── BurnRateCalculator.swift   # Usage prediction math
│   │   ├── PeakHourDetector.swift     # Peak hour logic
│   │   └── NotificationManager.swift  # Smart notification dispatch
│   ├── Models/
│   │   ├── UsageData.swift            # API response model
│   │   ├── BurnRate.swift             # Burn rate + predictions model
│   │   └── AppSettings.swift          # UserDefaults-backed settings
│   └── Assets.xcassets/
│       └── AppIcon                    # Ember icon assets
└── README.md
```
