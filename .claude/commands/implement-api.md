---
description: Implement an API from a spec in docs/ai/api-workflow/specs/<name>.json
---

Implement the API described by `docs/ai/api-workflow/specs/$ARGUMENTS.json`
in the app_starter brick's conventions.

Steps:

1. Run `dart scripts/api_spec.dart docs/ai/api-workflow/specs/$ARGUMENTS.json`.
   - Exit 1: stop, report the errors, change nothing.
   - Exit 2: stop and ask the user each `[ASK]` question. Do not guess answers.
   - Exit 0: continue with the template printed as `template:`.
2. Read `docs/ai/api-workflow/CONVENTIONS.md` and the reference it names for
   that template (`FaqController` + `faq_screen.dart` for paginated lists,
   `LoginController` + `AuthRepository` for auth). Do not load other features.
3. Implement only what the spec asks: endpoint constant, model, repository
   interface + Dio implementation, controller, screen/state wiring. Follow
   `task_after_success` exactly and respect `out_of_scope`.
4. Do not invent response fields absent from the spec sample.
5. Verify with `dart analyze` (and `flutter test` if tests exist) on the
   generated project or the brick; report failures, do not hide them.
6. Summarise the diff for the user's review. Do not commit.
