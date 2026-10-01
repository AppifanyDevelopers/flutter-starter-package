# Run 2: get_notifications (+ mark read), blind

Implemented by a fresh agent that was told to follow `/implement-api` and was
forbidden from reading `evals/`, `scripts/eval_api.dart` and `*.checks.json`.
Inputs: the two specs, CONVENTIONS.md, BACKEND_CONTRACT.md, the generated app.
No hints about run 1. Imports use the scratch package name `verify_app`.

Score: 15/15 (`dart scripts/eval_api.dart --spec get_notifications --app <dir> --candidate docs/ai/api-workflow/evals/get_notifications/run-2`).

## What the eval itself taught us

- First scoring gave 14/15: the `refresh_keeps_list` check hard-coded the
  method name `pullToRefresh` from run 1; this run called it `refreshList`.
  That was a checker bug, not an implementation bug. The check now finds the
  `onRefresh:` handler by name and inspects its body.
- After the fix both runs pass, and re-adding `state.value = TheStates.loading`
  to the handler makes the check fail.

## Difference vs run 1 (same spec, same conventions)

| | Run 1 | Run 2 |
|---|---|---|
| Refresh method | `pullToRefresh` | `refreshList` |
| Double-refresh guard | none | `_isRefreshing` flag |
| Model name | `NotificationItem` | `AppNotification` |
| Lines (feature + tests) | smaller | ~513 |
| Avoided the `refresh()` override trap | after review | first try (CONVENTIONS did not mention it; analyzer did) |
| Avoided FaqController refresh flaw | after review | first try (CONVENTIONS now warns) |

Guesses the agent had to make (spec gaps worth closing): behaviour of a tap on
an already-read tile; refresh failure UI (snackbar); the mark-read snackbar
title; the route path.
