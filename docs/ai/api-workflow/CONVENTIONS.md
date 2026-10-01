# Conventions the generator must follow

Short on purpose: this is the context an AI gets, so every line should
change what it writes. Source of truth is the brick under
`bricks/app_starter/__brick__/lib`.

## Layers

`features/<feature>/data/{model,repository}` and
`presentation/{bindings,controllers,screens}`. Controllers and screens never
call Dio. See `docs/ARCHITECTURE.md`.

## Data

- A repository interface `XRepository` returns `Future<Either<AppError, T>>`
  (dartz). Never throw to the UI.
- Real implementation is `DioXRepository implements XRepository` using
  `core/network/dio_api_client.dart` (`get/post/put/patch/delete`, which already
  maps errors to `AppError`). Swap it in the feature's Bindings at the
  `TODO(swap-backend)` line.
- Add the path to `core/constants/app_endpoints.dart`; no magic strings.
- Models are plain Dart classes with `fromJson`, no codegen. Parse defensively:
  never `as String` on a value the spec marks nullable or optional.
- Side effects (saving a token, analytics) belong in the controller, not the
  repository. Reference: `LoginController.login`.

- Wire format: read `BACKEND_CONTRACT.md`. Parse success with `ApiEnvelope`
  (`core/network/api_envelope.dart`); it exposes `dataMap`, `dataList` and
  `meta` (`PaginationMeta.hasMore`).
- Errors arrive as `ApiErrorResponse` with `code`, `fieldErrors`,
  `retryAfterSeconds`. Branch on `code`, show `firstError(field)` under form
  fields, and never parse `message`. `401 unauthenticated` is already handled
  globally by `DioApiClient`; controllers must not handle it again.

## State

- `TheStates` (`core/enums/the_states.dart`) held in `final state = TheStates.initial.obs;`.
- Render with `state.value.showWidget(loading:, error:, orElse:)` inside `Obx`.
- Errors: show as the spec's `ui.error_display` says; use `error.message` only.
- Loading skeletons use `core/widgets/app_shimmer.dart` (`AppShimmer.box`, ...).
- Error view: `AppErrorWidget(message:, onRetry:)`. Loading spinner: `AppLoadingWidget`.

## Pagination and refresh

Reference implementation: `FaqController` + `faq_screen.dart`.

- `_page`, `_hasMore`, `isLoadingMore`, a `ScrollController` listener that loads
  more at `maxScrollExtent - 200`, and `RefreshIndicator(onRefresh: reload)`.
- When the response carries `meta`, derive `_hasMore` from
  `PaginationMeta.hasMore`, not from `items.length == pageSize`.
- Load-more failure must not wipe the list; show the spec's retry UI.
- Pull-to-refresh must not set `state` to loading (that swaps the list for the
  shimmer and kills the refresh indicator). Use a separate `refresh()` that
  keeps the old list on failure. `FaqController.reload` gets this wrong; do not
  copy it.
- Lists inside `RefreshIndicator` need `AlwaysScrollableScrollPhysics`,
  otherwise a short list cannot be pulled to refresh.

## Tests

- Controllers are tested against a fake repository, no Dio.
- Anything that calls `Get.snackbar` needs a `GetMaterialApp` (use
  `testWidgets`), or it throws in tests.
- Do not copy the pagination block per list; if a third list appears, extract
  a shared controller first.

## Do not

- Use `setState` or `StatefulWidget` for server state.
- Leave commented-out code or unused cancel tokens in generated files.
- Invent response fields that are not in the spec sample.
- Touch files outside the feature and the endpoint constants file unless the
  spec says so.
