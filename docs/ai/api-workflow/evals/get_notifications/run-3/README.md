# Run 3: get_notifications (+ mark read), blind, after closing spec gaps

Same blind setup as run 2, with the seven run-2 spec gaps closed in
`open_questions` (already-read tap, refresh failure UI, route, snackbar text,
no `refresh()` method name). Score: 15/15 after fixing one more checker
over-fit (see below). Imports use the scratch package name `verify_app`.

- Checker bug found again: `url_null_marks_read` hard-coded `markAsRead`; this
  run used `markRead`. Loosened to `[mM]ark\w*[Rr]ead`. Lesson: checks should
  assert behaviour patterns, never names the implementer chooses.
- Guesses the agent reported: layout/copy details (titles, shimmer count),
  whether a tile with a `url` should be marked read (still undecided),
  malformed `read_at` treated as unread, route registered without a fake repo.
- Strengths vs run 2: generation counter discards stale responses; no
  method named `refresh`; failure flags stop auto load-more until Retry.
