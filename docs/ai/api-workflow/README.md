# API implementation workflow

Turns "implement this API" into a repeatable chain with a deterministic gate
in front of the model.

```
spec (JSON, human) -> validate + route (scripts/api_spec.dart, no AI)
                   -> generate (AI, using CONVENTIONS.md + a reference feature)
                   -> checks (dart analyze, flutter test)
                   -> human reviews the diff
```

## Use it

1. Copy `specs/_template.json` to `specs/<name>.json` and fill it in. Paste
   **real** sample responses (success, 401, 422, 500) and set
   `"sample_source": "real"`.
2. Run `dart scripts/api_spec.dart docs/ai/api-workflow/specs/<name>.json`.
   - exit 0: routed, go on
   - exit 1: spec is wrong, fix it (e.g. a password in a GET query)
   - exit 2: a question must be answered by a human before generating
3. In Claude Code run `/implement-api <name>`.

## Score an implementation

```bash
dart scripts/eval_api.dart --spec get_notifications --app /tmp/verify-app --generate
# after /implement-api ran inside /tmp/verify-app:
dart scripts/eval_api.dart --spec get_notifications --app /tmp/verify-app
```

Runs the validator, `flutter analyze`, `flutter test`, then the regex checks in
`specs/<name>.checks.json`. `--candidate <run dir>` installs a saved run first
(e.g. `evals/get_notifications/run-1`, the baseline). Needs Flutter, and mason
for `--generate`. Regex checks are heuristics: they catch known failure modes
(e.g. refresh flipping to the shimmer), not correctness in general.

## Routing rules (first match wins)

| # | Condition | Template |
|---|---|---|
| 1 | POST and response contains `token` or `access_token` | `auth` |
| 2 | response has a list and a pagination object (`current_page` + `last_page`) | `paginated_list` |
| 3 | GET and response has a list, no pagination | `simple_list` |
| 4 | GET and response is a single object | `detail` |
| 5 | POST/PUT/PATCH/DELETE (no token) | `mutation` (needs the `mutation` block) |
| 6 | anything else, or fields conflict | ask a human |

For rule 2 the request must also carry a `page` param on a GET (`per_page` is
optional, since some servers fix the page size), and the spec needs real
`success_variants.empty` and `success_variants.last_page` samples. If the
signals disagree the router asks instead of guessing.

Backend wire format (envelope, error codes): see `BACKEND_CONTRACT.md`. Real
specs: `login` (auth), `get_notifications` (paginated_list),
`mark_notification_read` (mutation).

## Open questions

Ambiguities the validator cannot detect (things you only spot by reading the
backend docs) go in `open_questions` as `{question, answer}`. An empty answer
makes the validator ask, so `/implement-api` will not run until the author
has decided. The answer is a decision, so mirror it into `task_after_success`
or `out_of_scope`.

## What stays human

- Writing the spec and the `task_after_success` line.
- The whole `mutation` block (`confirm_before`, `on_success`, `idempotent`).
  Deleting or cancelling something is a business decision.
- Reviewing the diff.

## What should not use an LLM

Model classes for a stable response shape are better produced by a
deterministic tool than by a model. Use the model for wiring and logic only.
