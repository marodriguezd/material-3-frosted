# UI/UX Audit — <App name>

> **Scope**: <modules / screens in scope>
> **Stack detected**: <Compose / Views / mixed · Compose BOM x.y · material3 a.b · minSdk/targetSdk>
> **Date**: <YYYY-MM-DD>
> **Auditor**: <name>

---

## 1. Summary

| | |
|---|---|
| **Overall score** | <X.X / 10> |
| **Screens audited** | <N> |
| **Critical defects (0–3)** | <N> |
| **Warnings (4–6)** | <N> |
| **Estimated effort** | <S / M / L> — <person-days> |
| **Recommended sequence** | <one line> |

**The five highest-impact defects**

| # | Defect | Where | Impact | Fix |
|---|--------|-------|--------|-----|
| 1 | | `file:line` | | |
| 2 | | `file:line` | | |
| 3 | | `file:line` | | |
| 4 | | `file:line` | | |
| 5 | | `file:line` | | |

---

## 2. Screen matrix

Score 0–10 per dimension. **N/A** excludes the dimension from the average.

| Screen | Color | Type | Shape | Motion | Depth | Comp. | Layout | Nav | Glass | A11y | Perf | Platform | **Avg** | Action |
|--------|-------|------|-------|--------|-------|-------|--------|-----|-------|------|------|----------|--------|--------|
| Home | | | | | | | | | | | | | | | |
| Detail | | | | | | | | | | | | | | | |
| Settings | | | | | | | | | | | | | | | |
| Onboarding | | | | | | | | | | | | | | | |

Legend — 9–10 compliant · 7–8 minor · 4–6 gap · 1–3 broken · N/A not applicable.

**A screen is done only when every dimension is ≥ 8.**

---

## 3. Critical issues (score 0–3)

### 3.1 <Short title>

- **Where**: `path/to/File.kt:123`
- **Dimension**: <Colour | Typography | …>
- **What**: <what is wrong, and why it matters to the user>
- **Fix**: <the concrete change>
- **Effort**: S / M / L
- **Acceptance**: <how we know it is done>

_(repeat per issue)_

---

## 4. Warnings (score 4–6)

| # | Where | Dimension | Issue | Recommendation | Effort |
|---|-------|-----------|-------|----------------|--------|
| 1 | `file:line` | | | | S |
| 2 | `file:line` | | | | M |

---

## 5. Passing (score 7–10)

Noted so the upgrade does not regress it.

- **<Screen / area>** — <what is already right, e.g. "dynamic colour already wired with a branded fallback">
- …

---

## 6. Workstreams (Phase 2)

Ordered by dependency, not by screen.

| # | Workstream | Files | Depends on | Risk | Acceptance criterion | Effort |
|---|------------|-------|------------|------|---------------------|--------|
| 1 | Foundation: BOM, SDK, theme, dynamic colour, edge-to-edge | | — | Low | App builds; dynamic colour on/off; light/dark | S |
| 2 | Shared components | | 1 | Low | | M |
| 3 | Layout & adaptive | | 1, 2 | Medium | Compact/Medium/Expanded reviewed | M |
| 4 | Screen-by-screen | | 2, 3 | Medium | Every screen ≥ 8 | L |
| 5 | Glass layer | | 4 | Medium | ≤ 3 surfaces/screen; opaque fallback | M |
| 6 | Motion polish & hero moments | | 4 | Low | Reduced-motion path verified | S |

---

## 7. Glass placement decisions

Which surfaces get frosted, and which are explicitly excluded.

| Surface | Tier | Decision | Reason |
|---------|------|----------|--------|
| Top app bar | 1 | Glass | |
| Bottom nav bar | 1 | Glass | |
| FAB | 1 | Glass container, M3 colour | |
| Content cards | 3 | Opaque | Reading surface |
| Text fields | 3 | Opaque | Focus + legibility |
| Snackbar | 3 | `inverseSurface` | |

**Opaque fallback**: <what the app renders when the platform disables blur>

**Contrast verification on glass**: <measured ratios, light and dark>

---

## 8. Measurements

Device: <model, Android version, refresh rate> · Build: <release>

| Metric | Before | After | Target | Source |
|--------|--------|-------|--------|--------|
| Scroll frame time p95 (ms) | | | < 16.6 | `gfxinfo framestats` |
| Jank frames (%) | | | < 5 | |
| Cold start (ms) | | | < +100 | `am start -W` |
| Memory delta (MB) | | | < 40 | `dumpsys meminfo` |

> Do not report a speedup without a before/after measurement on the same device.

---

## 9. Verification checklist

- [ ] `./gradlew assemble<Variant>` succeeds
- [ ] `./gradlew lint` clean for touched modules
- [ ] Existing unit + UI tests pass (none deleted to silence a failure)
- [ ] Screenshot tests updated for intentional visual change
- [ ] Every screen in the matrix is ≥ 8 on all 12 dimensions
- [ ] Light and dark theme reviewed on every changed screen
- [ ] Dynamic colour on and off reviewed
- [ ] Compact / Medium / Expanded width reviewed; foldable hinge respected
- [ ] Font scale 1.0 and 2.0 reviewed — no clipped glass chrome
- [ ] Animation scale 0 reviewed — transitions instant, layout final
- [ ] "Reduce blur effects" ON reviewed — content fully legible
- [ ] TalkBack walkthrough on changed screens
- [ ] Frame timing measured with the glass layer enabled
- [ ] Contrast 4.5:1 body / 3:1 large and non-text, including over glass
- [ ] RTL layout mirrors correctly

---

## 10. Not doing (out of scope)

| Item | Reason | Revisit when |
|------|--------|--------------|
| | | |
