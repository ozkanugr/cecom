# Lifecycle & state (LIFE)

What happens when the OS, the user, or a link moves the app between states it didn't plan for.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| LIFE-001 | Returning from background preserves state and refreshes stale data; timers, sockets and subscriptions are resumed | `AppState`, `scenePhase`, `onResume`, `visibilitychange` | P2 | client |
| LIFE-002 | After the OS kills the process (memory pressure), critical in-progress state — drafts, forms, navigation, pending uploads — is restored or was persisted | `onSaveInstanceState`, `SavedStateHandle`, `@SceneStorage`, state restoration, persisted stores | P1 | mobile |
| LIFE-003 | A kill or crash mid-write cannot leave corrupt persisted state (atomic writes, write-then-rename, transactions) | file writes, `UserDefaults`/`AsyncStorage` multi-key writes, JSON blobs | P1 | client, db |
| LIFE-004 | Rotation, resize and configuration changes (theme, locale, font scale) keep state; Android activity recreation doesn't lose it | ViewModels, `rememberSaveable`, window resize handlers | P2 | client |
| LIFE-005 | Entering a screen directly (deep link, notification, restored state, refresh on a nested web route) works when the usual prior state — logged-in user, loaded config, parent data — is missing | route guards, screen `init` assumptions, `!` on store values | P1 | client |
| LIFE-006 | Cold start and warm start behave the same; initialization runs once, in order, and the first screen can't run before init finishes | app bootstrap, `useEffect` init races, `didFinishLaunching` | P2 | client |
| LIFE-007 | Events that arrive during splash/init (deep links, push taps, auth callbacks) are queued and handled after init, not dropped | link/notification handlers registered late | P2 | mobile |
| LIFE-008 | The same lifecycle event delivered twice (double `onResume`, React StrictMode double effects, re-mount) causes no duplicate side effects | effects with side effects, analytics on mount, subscriptions | P2 | client |
| LIFE-009 | If persisted state can't be read or written (disk full, quota exceeded, corrupt JSON, schema mismatch), the app still starts with a safe fallback | storage read paths, `JSON.parse` without try, hydration | P1 | client |
| LIFE-010 | Persisted client state written by the previous app version is migrated, not crashed on (versioned store, migrations) | persist config `version`/`migrate`, Core Data/Room migrations | P1 | client |
| LIFE-011 | Long-running work (uploads, sync) uses the platform's background APIs or resumes after suspension (`BGTaskScheduler`, `URLSession` background, `WorkManager`) | upload/sync code | P2 | mobile |
| LIFE-012 | Web: multiple tabs stay consistent (logout in one tab logs out the others; storage events handled); back/forward cache restores don't show stale private data | `storage` event, `BroadcastChannel`, `pageshow` | P2 | web |
