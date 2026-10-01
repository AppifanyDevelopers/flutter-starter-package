# Run 4: get_notifications (+ mark read), blind, spec v2

Spec v2: tapping any unread tile marks it read (url ignored, no navigation),
refresh/route/snackbar gaps closed. Score 15/15, first try, no checker fixes
needed. Imports use package `verify_app`.

Remaining agent guesses (all low-stakes, consistent with earlier runs):
empty/error/retry copy, no success message on mark-read, taps ignored while a
PATCH is in flight, unparseable `read_at` counts as unread, 404 detected by
`code == 'not_found'`, bindings register the Dio repo directly (no fake).
