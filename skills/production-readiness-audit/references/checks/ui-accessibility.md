# UI edge cases & accessibility (UI, A11Y)

## UI — edge cases

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| UI-001 | Every async screen has loading, empty, and error states | screen components | P2 | client |
| UI-002 | Empty, single-item, and very large (1,000+) datasets render correctly | list screens | P2 | client |
| UI-003 | Long content wraps or truncates gracefully: names, titles, error messages, and translations (often 30–40% longer than English) | fixed widths, `numberOfLines`, `text-overflow` | P2 | client |
| UI-004 | The keyboard never hides the focused input or the submit button on small screens | keyboard avoidance | P2 | client |
| UI-005 | Very small screens (iPhone SE, 320px web) and large ones (tablet, desktop, split view) are usable | layout breakpoints, size classes | P2 | client |
| UI-006 | Safe areas, notch/Dynamic Island, home indicator, and Android gesture/navigation bars are respected | safe-area handling, edge-to-edge | P2 | mobile |
| UI-007 | Landscape is either supported properly or locked deliberately | orientation config | P3 | mobile |
| UI-008 | Dark mode is either supported (no hard-coded colors that become invisible) or explicitly disabled | color usage | P3 | client |
| UI-009 | Rapid navigation and double taps don't push duplicate screens or open two modals | navigation calls in handlers | P2 | client |
| UI-010 | Fast loading → success → error transitions don't flicker or show stale content | state transitions, skeletons | P3 | client |

## A11Y — accessibility

Default target: WCAG 2.2 AA (web) and the platform accessibility guidelines (mobile).

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| A11Y-001 | All interactive elements have accessible names; icon-only buttons have labels | `accessibilityLabel`, `aria-label`, `contentDescription` | P1 | client |
| A11Y-002 | Text scales with Dynamic Type / font scale / browser zoom up to 200% without clipping or overlap | fixed font sizes, fixed heights | P2 | client |
| A11Y-003 | Screen-reader focus order is logical; modals move and trap focus and restore it on close | focus management, modal components | P2 | client |
| A11Y-004 | Text and essential icons meet contrast requirements (4.5:1 body text, 3:1 large text and UI components) | color tokens | P2 | client |
| A11Y-005 | Touch targets are at least 44×44 pt (iOS) / 48×48 dp (Android) / 24×24 CSS px minimum (web) | small buttons, icon hit areas | P2 | client |
| A11Y-006 | Reduce Motion is respected for non-essential animation | animation code, `prefers-reduced-motion`, `accessibilityReduceMotion` | P3 | client |
| A11Y-007 | Everything is operable by keyboard (web; also iPad/Android hardware keyboards), with a visible focus indicator | custom controls, `outline: none` | P2 | client |
| A11Y-008 | Form errors are announced and associated with their fields | `aria-describedby`, `aria-invalid`, accessibility announcements | P2 | client |
| A11Y-009 | Native semantic elements are used (`button`, `a`, `label`) instead of clickable `div`s with handlers | `onClick` on `div`/`span` | P2 | web |
| A11Y-010 | Images that convey meaning have text alternatives; decorative images are hidden from assistive technology | `alt`, `accessibilityIgnoresInvertColors`, `importantForAccessibility` | P2 | client |
