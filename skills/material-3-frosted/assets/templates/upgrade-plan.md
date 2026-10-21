# Upgrade plan — <App name> → Android 17 / Material 3 Expressive + Frosted

> **Audit**: <link/path to audit-report.md>
> **Stack**: <Compose / Views / mixed> · <Compose BOM> · <material3> · minSdk <n> → targetSdk <n>
> **Total effort**: <person-days> across <N> workstreams

---

## Principles for this upgrade

1. **Foundation first.** Tokens and theme before components, components before screens, glass last.
2. **Every increment ships.** Each workstream ends in a buildable, testable, reviewable state.
3. **No regressions.** Behaviour, navigation and tests stay intact.
4. **Glass is an accent.** It is added after the underlying surfaces are correct.
5. **Accessibility gates every increment**, not just the end.

---

## Workstream 0 — Foundation

**Goal**: the app runs on the current platform with a correct, tokenised theme.

| Item | Detail |
|------|--------|
| Files | `app/build.gradle.kts`, `ui/theme/Color.kt`, `ui/theme/Theme.kt`, `ui/theme/Type.kt`, `ui/theme/Shape.kt`, `MainActivity.kt` |
| Changes | Compose BOM → `2026.09.00` **plus an explicit `material3:1.5.0-beta01` override** (the BOM's 1.4.0 keeps the Expressive APIs `internal`); `compileSdk`/`targetSdk` → 37; `MaterialExpressiveTheme` + `MotionScheme.expressive()`; dynamic colour on API 31+ with branded fallback; `surfaceContainer*` roles for containers; `enableEdgeToEdge()` + insets |
| Risk | Low — compile-time changes plus one theme swap |
| Acceptance | `./gradlew :app:dependencies` shows material3 1.5.0-beta01; app builds and runs; light/dark correct; dynamic colour on/off correct; edge-to-edge with no content under the status bar |
| Effort | S |

---

## Workstream 1 — Shared components

**Goal**: one correct implementation of each repeated component, inherited by every screen.

| Item | Detail |
|------|--------|
| Files | `ui/components/*` |
| Changes | Buttons → `Button`/`FilledTonalButton`/`ButtonGroup`; cards → `Card` with `shapes.medium`; text fields → `OutlinedTextField`; list rows → `ListItem`; nav bar → `NavigationBar` with labels; top bar → `TopAppBar`/`CenterAlignedTopAppBar`; FAB → `FloatingActionButton`/`ExtendedFloatingActionButton`; loading → `LoadingIndicator` |
| Risk | Low–Medium — visual change across many screens |
| Acceptance | Every component has hover/focus/pressed/disabled/error/loading states; all icon-only controls have `contentDescription`; touch targets ≥ 48dp |
| Effort | M |

---

## Workstream 2 — Layout & adaptive

**Goal**: the app is usable from a 360dp phone to a 1200dp tablet and a foldable.

| Item | Detail |
|------|--------|
| Files | `ui/navigation/*`, per-screen composables |
| Changes | `NavigationSuiteScaffold` (bar → rail → drawer by width); `currentWindowAdaptiveInfo()`; `ListDetailPaneScaffold` on Medium+; content width constrained to 840–1040dp on Expanded; scaffold `contentPadding` used for scroll insets; hinge-aware layout |
| Risk | Medium — navigation restructure |
| Acceptance | Compact/Medium/Expanded reviewed on emulator; foldable open/closed reviewed; no content across the hinge; landscape and split-screen usable |
| Effort | M |

---

## Workstream 3 — Screen-by-screen

**Goal**: every screen reaches ≥ 8 on all 12 dimensions.

| Screen | Files | Key changes | Acceptance |
|--------|-------|-------------|------------|
| Home | | | |
| Detail | | | |
| Settings | | | |
| Onboarding | | | |
| Empty / error / loading states | | | |

**Acceptance for the workstream**: every row of the screen matrix is ≥ 8; light and dark
reviewed; font scale 2.0 reviewed.

---

## Workstream 4 — Frosted layer

**Goal**: Tier-1 glass chrome, with a guaranteed opaque fallback.

| Item | Detail |
|------|--------|
| Files | `ui/theme/FrostedTheme.kt`, `ui/components/GlassChrome.kt`, `app/build.gradle.kts` |
| Dependencies | `dev.chrisbanes.haze:haze*` at one version (2.0.1) |
| Changes | Glass top bar + bottom nav over scrolling content; glass FAB dock; merged glass control group; source = scrolling content only; `LocalGlassAvailable` drives the opaque fallback; in-app "reduce transparency" preference |
| Risk | Medium — the most common source of jank and of contrast regressions |
| Acceptance | ≤ 3 glass surfaces on the busiest screen; opaque fallback renders when blur is unavailable; text on glass ≥ 4.5:1 light and dark; reduce-blur reviewed; frame time p95 < 16.6 ms on a mid-range device |
| Effort | M |

**Glass placement table** (copy from the audit):

| Surface | Tier | Decision | Reason |
|---------|------|----------|--------|
| | | | |

---

## Workstream 5 — Motion polish & hero moments

**Goal**: 1–2 expressive moments per flow, and nothing else that moves.

| Item | Detail |
|------|--------|
| Changes | `motionScheme.defaultSpatialSpec()` for state changes; emphasized transitions for navigation; one hero moment per flow (e.g. a morphing FAB → expanded sheet); reduced-motion path |
| Risk | Low |
| Acceptance | Animation scale 0 → all transitions instant, layout final; no motion longer than 400 ms except the hero moment; no jank |
| Effort | S |

---

## Dependency order

```
0 Foundation ──► 1 Components ──► 2 Layout ──► 3 Screens ──► 4 Glass ──► 5 Motion
                                   └──────────────────────────┘
```

---

## Rollout

| Increment | Workstream | Ship independently? | Notes |
|-----------|------------|---------------------|-------|
| PR 1 | 0 | Yes | Pure foundation; no visual change expected |
| PR 2 | 1 | Yes | Visual change; update screenshot tests |
| PR 3 | 2 | Yes | Navigation restructure; manual QA on 3 size classes |
| PR 4–n | 3 | Yes | One screen per PR, or per flow |
| PR n+1 | 4 | Yes | Flag behind a setting first if the app is large |
| PR last | 5 | Yes | Polish |

**Feature flag**: <how the glass layer is rolled out / how to disable it>

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Glass jank on low-end devices | Medium | High | `HazePerformanceMode.Performance` on low-RAM; opaque fallback |
| Contrast regression on glass | Medium | High | Tint + measured contrast in both themes |
| `targetSdk 37` behaviour change | Medium | Medium | Test on API 37 emulator; separate PR |
| Screenshot test churn | High | Low | Update baselines deliberately; review the diff |
| Scope creep beyond the matrix | Medium | Medium | "Not doing" list in the audit report |

---

## Definition of done

- [ ] All workstreams accepted
- [ ] Screen matrix: every cell ≥ 8
- [ ] Full verification checklist in the audit report passes
- [ ] Measurements recorded (before/after, device named)
- [ ] Rollout flag removed or documented
- [ ] Audit report updated with the final state
