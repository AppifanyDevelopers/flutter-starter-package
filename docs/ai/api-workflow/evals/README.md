# Saved eval runs

Score runs against the current checks with
`dart scripts/eval_api.dart --spec <name> --app <dir>`.

| Run | Spec version | Score today |
|---|---|---|
| get_notifications run-1, run-2, run-3 | v1 (tap marks read only when `url` is null) | 14/15: fail `tap_marks_read_regardless_of_url` |
| get_notifications run-4 | v2 | 15/15 |
| login run-1 | v1 | 17/18: fails `email_lowercased` |
| login run-2 | v2 | 18/18 |

A spec change shows up as a specific failing check on old runs, which is the
regression signal. After changing a spec, re-run and save the next `run-N`.
`run-4` / `login/run-2` are the current baselines.

No run has been rendered on a device or exercised against the real API.
