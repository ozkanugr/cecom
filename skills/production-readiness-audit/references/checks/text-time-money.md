# Text, time & money (I18N, TIME, MONEY)

The Turkish dotted/dotless i is one symptom of a wider class: code that silently assumes one locale, one timezone, or exact decimal arithmetic.

## I18N — text and localization

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| I18N-001 | Case conversion of **identifiers** (keys, enum names, emails, usernames, file extensions, HTTP headers) is locale-invariant. Locale-sensitive APIs turn `"TITLE"` into `"tıtle"` and `"id"` into `"İD"` under `tr-TR`: Java/Kotlin `toLowerCase()`/`toUpperCase()` without a `Locale`, .NET `ToLower()`/`ToUpper()`, JS `toLocaleLowerCase()`/`toLocaleUpperCase()`, Swift `lowercased(with:)`/`localizedLowercase`. (JS `toLowerCase()`, Swift `lowercased()` and Python `lower()` are locale-independent.) | `toLowerCase(`, `toUpperCase(`, `ToLower(`, `toLocaleLowerCase`, `localizedLowercase`, `Locale.ROOT`, `CultureInfo.InvariantCulture` | P1 | all |
| I18N-002 | Case conversion of **user-visible text** is locale-aware where it matters (titles, buttons rendered upper-case) | UI text transforms, `text-transform: uppercase` with `lang` attribute | P3 | client |
| I18N-003 | Case-insensitive comparison and search use collation/normalization (`localeCompare` with sensitivity, `ILIKE` with correct collation, `caseInsensitiveCompare`) rather than lower-casing both sides | search, dedupe, uniqueness checks | P2 | all |
| I18N-004 | Database and connection charset is full UTF-8 (MySQL `utf8mb4`, not `utf8`), and collation is chosen deliberately | DB config, migrations, connection strings | P1 | db |
| I18N-005 | Unicode is normalized (NFC) before comparison, uniqueness constraints (usernames, emails), and file names | `normalize(`, `precomposedStringWithCanonicalMapping`, `unicodedata.normalize` | P2 | all |
| I18N-006 | Length limits and truncation count user-perceived characters (grapheme clusters), not UTF-16 code units; emoji and combined characters aren't split | `.length`, `substring`, `prefix(`, `maxLength`, `Intl.Segmenter` | P3 | all |
| I18N-007 | No hard-coded user-facing strings where the product is localized (follow the project's i18n decision) | JSX/SwiftUI/Compose text literals, alert messages | P2 | client |
| I18N-008 | A missing translation key falls back to the default language — not to the raw key, an empty string, or a crash | i18n init (`fallbackLng`), `NSLocalizedString` defaults | P2 | client |
| I18N-009 | Plurals use plural rules (ICU / `.stringsdict` / Android plurals), not `count == 1 ? … : …` | count-dependent strings | P3 | client |
| I18N-010 | User-entered numbers respect the locale's decimal separator (`1,5` vs `1.5`); parsing failures are reported, not silently truncated | `parseFloat`, `Double(`, number inputs, `NumberFormatter` | P1 | client |
| I18N-011 | Layout supports RTL if RTL locales are planned: logical properties (leading/trailing, start/end), mirrored directional icons | `left`/`right` margins, `marginLeft`, `.leading` | P3 | client |
| I18N-012 | User-visible lists are sorted with locale collation (`Intl.Collator`, `localizedStandardCompare`), not byte order | `sort()` on strings | P3 | client |

## TIME — dates, times, clocks

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| TIME-001 | Instants are stored and transmitted in UTC (or with offset) and converted to local time only for display | DB column types (`timestamptz` vs `timestamp`), serializers | P1 | all |
| TIME-002 | Date-only values (birthdays, due dates, holidays) are stored as dates, not midnight timestamps that shift a day across timezones | `DATE` vs `TIMESTAMP` columns, `new Date('2024-05-01')` (parsed as UTC) | P1 | all |
| TIME-003 | Scheduling and recurrence store an IANA timezone id (e.g. `Europe/Istanbul`), not a fixed offset, so DST and rule changes are handled | reminders, cron per user, calendar code | P2 | all |
| TIME-004 | Durations, timeouts and rate windows use a monotonic clock, not wall-clock time that can jump | `Date.now()` diffs vs `performance.now()`, `SystemClock.elapsedRealtime`, `ContinuousClock`, `time.monotonic()` | P2 | all |
| TIME-005 | The client's clock is never trusted for security or business decisions (token expiry, trial end, rate limits, "already claimed today") | expiry checks done on device, `Date()` in entitlement logic | P1 | all |

## MONEY — amounts and currency

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| MONEY-001 | Money is stored and computed as integer minor units or a decimal type with an explicit currency; never binary floating point; rounding rule is explicit | `price * qty` on floats, `Double`/`number` for amounts, `DECIMAL` columns, `Decimal`, `BigDecimal` | P0 | pay, api, db |
| MONEY-002 | Amounts are formatted with the currency code and the user's locale (`Intl.NumberFormat` with `currency`), not string concatenation with `$` or `TL` | price display code | P3 | client |
| MONEY-003 | The amount charged is computed server-side from server prices; a client-sent price or total is never trusted | checkout/order endpoints, payment intent creation | P0 | pay, api |
