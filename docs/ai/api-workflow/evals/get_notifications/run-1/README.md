# Run 1: get_notifications (+ mark read)

Baseline output of `/implement-api get_notifications`, generated into a scratch
app from brick 0.6.0 + the Unreleased network layer, then corrected once by
review. Kept as a regression reference, not as brick code.

- `feature/` -> `lib/features/notifications/` in a generated app
- `notifications_controller_test.dart` -> `test/`
- `routes-lines.txt`: the route/import lines added to `app_routes.dart`
- Imports use the scratch package name `verify_app`; replace with yours.

## Scorecard

| Check | First pass | After review |
|---|---|---|
| `flutter analyze` clean | FAIL (`refresh()` overrode `GetxController.refresh`; found by the runner, renamed `pullToRefresh`) | pass |
| Tests pass | pass | pass |
| Paging from `PaginationMeta.hasMore` | pass | pass |
| Load-more failure keeps list + inline retry row | pass | pass |
| Empty state | pass | pass |
| Pull-to-refresh keeps the list (no shimmer) | FAIL | pass |
| Short list can be pulled to refresh | FAIL | pass |
| Did not copy FaqController's refresh flaw | FAIL | pass |
| Tap with null `url` marks read; url set does nothing | pass | pass |

Automated: `dart scripts/eval_api.dart --spec get_notifications --app <dir> --candidate docs/ai/api-workflow/evals/get_notifications/run-1`
(15 checks, all pass on this run).

Re-run this spec after any change to the prompt, conventions or templates and
compare against this table.

## Not covered

No widget test of the screen, never run against the real API, no link from
the dashboard.
