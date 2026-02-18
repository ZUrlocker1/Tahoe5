# Product Requirements Document (PRD)

## Product Name
Web-Based Video Poker

## Document Control
- Version: 1.1
- Date: February 12, 2026
- Author: Product Team
- Status: Draft (Revised with Turbo Pascal legacy feature parity)
- Legacy Reference: `/Users/urlocker/Downloads/Vibe1/TP Original/TAHOE5D.PAS`

## 1. Overview
This product is a browser-based video poker game that delivers a fast, casino-style single-player experience with fair randomization, responsive controls, and optional account-based progression.

This revision incorporates feature parity with the legacy Turbo Pascal implementation ("Tahoe 5"), including its classic paytable, keyboard-first hold flow, configurable sound cues, and distinctive bankroll loop.

## 2. Problem Statement
Many web poker experiences feel outdated, slow, or untrustworthy due to poor UX and unclear game fairness. Players need a modern, mobile-friendly video poker product that keeps the original Tahoe game feel while improving usability, observability, and maintainability.

## 3. Goals and Non-Goals
### Goals
- Preserve classic Tahoe gameplay behavior as a selectable "Classic Mode."
- Deliver a polished, reliable web UX for desktop and mobile.
- Provide clear flow: set bet, deal, hold, draw, evaluate, payout.
- Launch with Jacks or Better and the legacy Tahoe payout ladder.
- Preserve keyboard-driven play for expert users.

### Non-Goals (MVP)
- Multiplayer poker rooms.
- Live dealer features.
- Real-money wagering and cashout.
- Multiple variants at launch.

## 4. Target Audience
- Existing Tahoe players who want modern access to the same game feel.
- Casual casino-game players on mobile and desktop.
- Users who prefer fast keyboard interactions over complex UI flows.

## 5. Key User Stories
- As a returning Tahoe player, I want the same payout behavior and hold flow so the game feels familiar.
- As a new player, I want a clear help panel with controls and hand payouts so I can learn quickly.
- As a player, I want to toggle sound feedback for deal/hold/win/loss moments.
- As a player with low balance, I want the game to keep me in-session via configurable bailout behavior.
- As a mobile player, I want simple tap controls equivalent to keyboard shortcuts.

## 6. Functional Requirements
### 6.1 Core Gameplay
- Standard 52-card deck.
- Fisher-Yates shuffle each hand.
- Initial 5-card deal.
- Hold/unhold any subset of cards.
- Draw replaces only non-held cards.
- Hand evaluation supports:
  - Jacks or Better
  - Two Pair
  - Three of a Kind
  - Straight (including A-2-3-4-5 and 10-J-Q-K-A)
  - Flush
  - Full House
  - Four of a Kind
  - Straight Flush
  - Royal Flush
- Hand result text shown after draw (for example: "Two pair", "Royal flush!").

### 6.2 Classic Tahoe Mode (Required MVP)
- Starting balance defaults to `$90`.
- Base hand ante defaults to `$10`.
- Bet adjustment step is `$10`.
- Bet can be increased pre-deal until available balance is exhausted.
- Bet cannot be decreased below `$10`.
- On hand resolution:
  - Payout score derives from hand rank.
  - Final payout is multiplied by `bet / 10`.
  - Balance updates immediately after payout.
- If post-hand balance falls to `<= 0`, trigger emergency loan behavior:
  - Reset playable balance to classic baseline (`$90` effective for next hand).
  - Show "emergency loan" message and one randomized taunt line.
- Product must support feature flags to disable/modify emergency loan and taunt messaging for non-classic deployments.

### 6.3 Input and Control Scheme
- Desktop keyboard parity:
  - `Enter`: deal/draw/confirm next hand
  - `1-5`: toggle hold for each card
  - Arrow keys: increase/decrease bet pre-deal
  - `S`: toggle sound on/off
  - `H`: open help overlay
  - `Esc`: quit/end session flow
- Mobile/touch parity:
  - Card tap toggles hold
  - Bet plus/minus controls
  - Dedicated Sound and Help buttons

### 6.4 Audio and Feedback
- Sound toggle persisted per user/device.
- Event-based audio cues:
  - Start/chime
  - Hold toggle beep
  - Standard win cue
  - Big win cue (full house or better threshold configurable)
  - Loss/bankruptcy cue
- Visual feedback:
  - Clear "Hold" label over selected cards
  - Win/loss line item per hand
  - Always-visible balance and current bet

### 6.5 UX and Interface
- Single-screen layout preserving Tahoe information hierarchy:
  - Bet and balance at top
  - Card slots labeled `1..5`
  - Persistent paytable in view
  - Inline help access
- Intro screen and help content included in web form.
- Help overlay must not clear current hold state when closed.

### 6.6 Accounts and Persistence
- Guest mode required.
- Optional account mode for cloud sync.
- Persist:
  - Balance model preference (classic/modern)
  - Sound setting
  - Session/lifetime stats
- In guest mode, store local state in browser storage.

### 6.7 Fairness and Transparency
- Publish exact hand-ranking rules and paytable values.
- Server-authoritative shuffle/deal/draw/evaluate in production mode.
- Display result details and payout math for each hand.
- Audit log hand events for debugging and dispute handling.

### 6.8 Admin and Operations
- Admin configuration for:
  - Paytable values
  - Economy values (start balance, ante, bet step, bailout amount)
  - Win-sound thresholds
  - Taunt messaging enable/disable
  - Feature flags (Classic Mode default on/off)

## 7. Non-Functional Requirements
- Performance: first interactive screen < 2.5s on mid-tier mobile network.
- Reliability: 99.9% monthly uptime target.
- Security: OWASP-aligned controls and encrypted transport.
- Scalability: support 10k concurrent sessions at launch target.
- Accessibility: keyboard navigation, high contrast, and screen-reader labels.

## 8. Technical Requirements
### 8.1 Frontend
- Responsive web app (mobile-first).
- Deterministic client state machine:
  - `PRE_DEAL`
  - `DEALT`
  - `HOLD_SELECT`
  - `DRAWN`
  - `HAND_RESULT`
- UI state restoration after help overlay close.

### 8.2 Backend
- API endpoints:
  - `POST /game/start`
  - `POST /game/set-bet`
  - `POST /game/deal`
  - `POST /game/toggle-hold`
  - `POST /game/draw`
  - `POST /game/next-hand`
  - `GET /game/history`
- Backend returns hand result object including:
  - rank name
  - base payout score
  - bet multiplier
  - final payout
  - resulting balance

### 8.3 Data Model (High-Level)
- User: id, auth profile, settings, balance profile.
- SessionState: current hand, deck pointer/top index equivalent, holds, phase.
- HandHistory: bet, initial cards, held positions, draw cards, result, payout, balance_after, timestamp.
- EconomyConfig: ante, starting_balance, bet_step, bailout_enabled, bailout_amount.
- AudioConfig: event sound mappings and thresholds.

### 8.4 Analytics
- Track:
  - app_open
  - intro_continue
  - help_open
  - bet_changed
  - hold_toggled
  - hand_completed
  - bailout_triggered
  - sound_toggled
  - session_end

## 9. Success Metrics
- Activation: % of users who complete first hand within 2 minutes.
- Engagement: average hands/session.
- Retention: D1/D7/D30 return rates.
- Legacy parity: % of scripted classic-mode test cases matching expected Tahoe outcomes.
- Balance stability: bailout trigger frequency per 100 hands.
- Stability: crash-free sessions and API error rate.

## 10. MVP Scope
### In Scope
- Jacks or Better with Tahoe legacy payout ladder.
- Classic bet/balance loop with configurable bailout behavior.
- Keyboard and touch controls with parity.
- Intro/help overlays and persistent paytable.
- Sound cues with user toggle.

### Out of Scope
- Real-money transactions.
- Multiplayer/social features.
- Additional poker variants.
- Native mobile apps.

## 11. Milestones
1. Legacy Mapping and UX Spec (1 week)
- Confirm parity rules from Turbo Pascal source
- Define Classic Mode state diagram
- Approve responsive wireframes

2. MVP Build (5 weeks)
- Implement game engine and parity test fixtures
- Build web client controls and overlays
- Implement audio, payouts, and economy configuration

3. QA and Soft Launch (2 weeks)
- Golden test suite against legacy expected hands/scores
- Input parity testing (keyboard and touch)
- Telemetry and balancing review

4. Public Launch
- Controlled rollout
- Monitor bailout frequency, win distribution, and session quality

## 12. Risks and Mitigations
- Risk: Legacy economy feels punitive or confusing to new users.
- Mitigation: expose Classic vs Modern economy preset; clear payout math.

- Risk: Help overlay/state bugs regress hold behavior.
- Mitigation: explicit UI state tests to confirm holds persist after help close.

- Risk: Audio annoys users.
- Mitigation: instant mute toggle and persisted preference.

- Risk: Perceived unfairness.
- Mitigation: transparent rules, visible paytable, and server-side auditability.

## 13. Open Questions
- Should Classic Mode be default for all users or only returning users?
- Should bailout taunt text ship enabled, disabled, or region-dependent?
- Should "Only a pair" (below Jacks) have explicit zero payout messaging?
- Do we keep exact legacy starting balance/ante defaults (`$90`/`$10`) globally?
- Is a separate "Modern Mode" economy required at MVP or post-MVP?

## 14. Appendix
### A. Legacy Tahoe Paytable (Base Score at $10 Bet)
- Royal Flush: 2500
- Straight Flush: 500
- Four of a Kind: 250
- Full House: 80
- Flush: 50
- Straight: 40
- Three of a Kind: 30
- Two Pair: 20
- Jacks or Better: 10
- Other outcomes: 0 payout (hand loss)

### B. Legacy Control Mapping
- `Enter`: deal, draw, and continue prompts
- `1-5`: hold toggles
- Arrow keys: bet up/down
- `S`: sound on/off
- `H`: help
- `Esc`: quit

### C. Legacy Audio Intent
- Start cue
- Toggle beep
- Win cue
- Great win cue
- Losing cue
