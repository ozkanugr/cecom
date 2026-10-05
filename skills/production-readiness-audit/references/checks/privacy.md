# Data & privacy (PRIV)

Technical controls only. Passing these checks does not by itself make a product KVKK/GDPR compliant; legal obligations need qualified review.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| PRIV-001 | Every collected personal-data field has a purpose; nothing is collected "just in case" | signup forms, profile schema, analytics properties | P2 | all |
| PRIV-002 | Analytics events contain no PII (emails, names, phone numbers, free text, precise location); user ids are pseudonymous | analytics `track`/`logEvent` calls and their properties | P1 | client |
| PRIV-003 | Crash and error reports scrub PII and tokens (`beforeSend`, data scrubbing rules, no request bodies) | Sentry/Crashlytics/Bugsnag init | P1 | all |
| PRIV-004 | Push payloads carry no sensitive content (they are shown on lock screens and pass through Apple/Google) | push payload construction | P1 | push |
| PRIV-005 | Locally cached personal data is minimal; sensitive caches are encrypted and excluded from device backups where needed (`isExcludedFromBackup`, `allowBackup`/`dataExtractionRules`) | local DB, file caches, Android manifest | P2 | mobile |
| PRIV-006 | Non-essential analytics, tracking and ads SDKs start only after consent (cookie consent on web; ATT on iOS for tracking; KVKK/GDPR consent where required) | SDK init order vs consent state | P1 | client |
| PRIV-007 | Account deletion really deletes or anonymizes server-side data, including data held by third parties (analytics, email, CRM), within a defined time; backups follow the retention policy | delete-account flow, retention jobs | P1 | api |
| PRIV-008 | Users can export their data and request deletion where required, and those flows work end to end | export/delete endpoints | P2 | api |
| PRIV-009 | Third-party SDKs are inventoried with what they collect; store disclosures match (Apple privacy manifest `PrivacyInfo.xcprivacy` and nutrition label, Google Play Data safety) | SDK list, privacy manifest, required-reason APIs | P1 | mobile |
| PRIV-010 | Personal data sent to LLM providers is minimized and documented (which data, which provider, retention/training terms) | prompt construction | P1 | llm |
| PRIV-011 | Retention periods are enforced by code (scheduled purge/anonymization jobs), not just written in a policy | cron/jobs, TTL indexes | P2 | api, db |
| PRIV-012 | Permission requests (location, contacts, photos, camera, microphone) are only for features that use them, asked in context, with accurate usage descriptions | Info.plist usage strings, AndroidManifest permissions, request call sites | P1 | mobile |
| PRIV-013 | A privacy notice (KVKK *aydınlatma metni* / GDPR Art. 13 information) is shown or linked at every point where personal data is collected; where consent is the legal basis, it is separate from the notice, specific, freely given, recorded with time and notice version, and withdrawable | sign-up and data-entry forms, consent records | P1 | all |
| PRIV-014 | A record of processing activities exists and cross-border transfers are identified (cloud regions, analytics, email, AI providers) with their legal basis (KVKK Art. 9, GDPR Chapter V); VERBİS registration is checked where required | docs/ADRs, provider list — usually outside the repository, so often UNCERTAIN | P2 | all |
| PRIV-015 | Non-production environments hold anonymized or synthetic personal data only | seed scripts, database dumps in the repository, staging copy procedures | P1 | all |
