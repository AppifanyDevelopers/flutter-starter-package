# Saved eval runs

Runs are snapshots against the spec as it was at the time. Specs have moved on:

| Run | Scored against | Today's checks |
|---|---|---|
| get_notifications run-1, run-2, run-3 | spec v1 (tap marks read only when `url` is null) | 14/15: fail `tap_marks_read_regardless_of_url` (spec v2: any unread tap marks read, no navigation) |
| login run-1 | spec v1 | 17/18: fails `email_lowercased` (spec v2: lowercase before sending) |

That is the regression signal working: a spec change shows up as a specific
failing check. Re-run after changing a spec, then save as the next `run-N`.
