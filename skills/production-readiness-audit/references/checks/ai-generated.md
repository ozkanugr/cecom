# AI-generated code & LLM features (AIGEN, LLM)

AIGEN covers failure patterns typical of vibe-coded projects regardless of what the app does. LLM covers apps that call language models themselves.

## AIGEN — AI-generated code smells

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| AIGEN-001 | No stubs or placeholders on real paths: `TODO`, `FIXME`, `// implement later`, `NotImplemented`, functions that just `return true`/success, empty handlers | `rg -n "TODO\|FIXME\|not implemented\|implement later\|placeholder"` | P0 | all |
| AIGEN-002 | No mock data, hard-coded responses, or fake success in production code paths (`mockUsers`, `setTimeout(() => resolve({ ok: true }))`, sample JSON imported by screens) | `mock`, `fake`, `dummy`, `sample`, `lorem` in `src` (not tests) | P0 | all |
| AIGEN-003 | The project builds, type-checks and lints cleanly now — this catches hallucinated APIs, wrong signatures and missing imports. Run the commands; report actual output | build/typecheck/lint commands from `CLAUDE.md` or manifests | P1 | all |
| AIGEN-004 | Checks aren't silenced to make code compile: `@ts-ignore`, `@ts-expect-error`, `as any`, `eslint-disable`, `# type: ignore`, `@SuppressLint`, `!`/`!!`/`try!` force unwraps on fallible data | `rg -n "ts-ignore\|as any\|eslint-disable\|type: ignore\|try!"` | P1 | all |
| AIGEN-005 | No commented-out security or validation code (auth checks, signature verification, input validation) | commented blocks near auth/validation | P0 | all |
| AIGEN-006 | One implementation per concept: not two API clients, two auth helpers, two date utilities, or three state-management approaches drifting apart | duplicate modules with similar names | P2 | all |
| AIGEN-007 | Copied tutorial configuration is gone: example keys, default passwords, `allow all` rules, `cors({ origin: "*" })`, sample bundle ids | config files, rules files | P0 | all |
| AIGEN-008 | Requested permissions and entitlements are actually used (camera, location, contacts, background modes) | Info.plist, AndroidManifest, entitlements vs code | P1 | mobile |
| AIGEN-009 | Dead code, unused files and exports from earlier iterations are removed | `knip`, `ts-prune`, unused files | P3 | all |
| AIGEN-010 | Comments and docs don't claim behavior the code doesn't implement ("retries 3 times", "validated server-side") | comments near critical logic vs implementation | P2 | all |

## LLM — apps that call language models

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| LLM-001 | Provider API keys are server-side only; clients call your backend, not the provider with a secret key | client code importing provider SDKs, `dangerouslyAllowBrowser` | P0 | llm |
| LLM-002 | Prompt injection is contained: untrusted content (user input, documents, web pages, tool results) is separated from instructions, and model-triggered actions/tools are allow-listed and confirmed for anything destructive | prompt assembly, tool definitions, agent loops | P0 | llm |
| LLM-003 | Model output is treated as untrusted: validated against a schema before use, never executed directly as code, SQL, shell, or rendered as unsanitized HTML | output parsing, `eval`, raw HTML rendering | P0 | llm |
| LLM-004 | Cost and abuse are bounded: per-user rate limits, max tokens, max agent iterations, budget alerts | request handlers calling the model | P1 | llm |
| LLM-005 | Timeouts, bounded retries, and a fallback or graceful message when the provider is down; streaming errors handled mid-stream | provider client config, stream handlers | P2 | llm |
| LLM-006 | Prompts and responses are logged only as privacy rules allow (see PRIV-010); no secrets in prompts | logging around model calls | P1 | llm |
| LLM-007 | Model versions are pinned and prompts versioned, with at least a small regression check when either changes | model ids (`-latest` aliases), prompt storage | P3 | llm |
