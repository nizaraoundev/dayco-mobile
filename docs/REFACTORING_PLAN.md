# Refactoring plan and progress

Companion to `ARCHITECTURE_AUDIT.md`. The audit says what is wrong; this says
what is being built, in what order, and how far it has got.

Gate after every phase: `flutter analyze` reports **0 errors** and
`flutter test` is green. Both hold at the time of writing.

---

## Target architecture

```
lib/
  app/                    app shell: bootstrap, MaterialApp, router, DI wiring
  core/
    catalog/              shared reference data (car brands)
    config/               backend hosts + every endpoint, in one place
    error/                Failure hierarchy + Result<T>
    network/              one ApiClient per backend, interceptors, JSON coercion
    state/                DataState<T> — the deterministic UI state model
    storage/              SessionStore (tokens, namespaced per backend)
    theme/                design tokens
    utils/                logger, JWT, single-flight / latest-wins primitives
    widgets/              shared presentational widgets
  features/
    auth/                 sign-in, session restore, connected user
    clients/              clients, sub-clients, prospects  (REAL API)
    cartography/          the map                           (REAL API + Google)
    stock/                stock consultation                (REAL b2b API)
    sales/                dashboard, orders, products, visits (PROTOTYPE data)
```

Each real feature is `domain/` (entities + repository interface) +
`data/` (repository implementation, mappers) + `presentation/`
(cubits + widgets). Layers that earn their keep only — there are deliberately
no use-case classes, because the previous build's `domain/usecases` were dead
code that nothing imported (audit M-1).

### Decisions and why

**Bloc/Cubit, not GetX, for state.** GetX's `Obx` tracks whatever observable the
closure happens to read, which is precisely how `GoogleMap` ended up rebuilding
on every GPS fix (audit H-1). Cubit makes the dependency explicit: a widget
subscribes to a named state type, and `buildWhen`/`BlocSelector` bound the
rebuild. The states are also plain values, so they are unit-testable without a
widget tree.

**GetX is retained for navigation during the migration.** `GetMaterialApp`,
`Get.toNamed` and the route table work and are used from ~30 call sites.
Replacing routing at the same time as state management would mean no working
build between the two, so routing is migrated last and separately.

**Repositories own the cache and are the single source of truth.** The map, the
clients list and the client detail screen all read one `ClientsRepository`, which
publishes `portfolioChanges`. That is what makes creating a client on the map
show up in the list without a reload — previously each screen kept its own
`RxList` and refetched independently.

**Domain does not depend on any SDK.** `GeoPosition` exists so business logic
does not need `google_maps_flutter`'s `LatLng` (and therefore a platform
channel) to be unit-tested. Conversion happens at the presentation boundary.

---

## Phase 0 — Unblock the build  ✅ done

* `pubspec.yaml`: `dev_dependencies` was corrupted so `flutter_test` did not
  resolve and **no test could compile** (audit C-3). Repaired.
* `animation_config.dart`: referenced APIs removed/moved in Flutter 3.47, so the
  project **did not compile at all** (audit C-2). Fixed.
* Result: `flutter analyze` 23 errors → 0.

## Phase 1 — Core foundation  ✅ done

| Area | File | Replaces |
| --- | --- | --- |
| Errors | `core/error/failure.dart`, `result.dart` | `throw Exception('string')` + `e.toString().replaceFirst(...)` |
| Config | `core/config/api_config.dart` | three hardcoded base URLs, endpoints inline at call sites |
| HTTP | `core/network/api_client.dart`, `auth_interceptor.dart`, `error_mapper.dart` | 3 ad-hoc `Dio` instances, per-request `SharedPreferences` reads |
| JSON | `core/network/json_coercion.dart` | `_asMap` / `_asListOfMaps` / `_safeString` / `_toDouble` duplicated in 3 files |
| Tokens | `core/storage/session_store.dart` | **audit C-1** — namespaced per backend, secure storage, migrates existing installs |
| UI state | `core/state/data_state.dart` | loose independent `RxBool`s that could contradict each other |
| Concurrency | `core/utils/single_flight.dart` | nothing — new: request de-duplication, double-submit guard, latest-wins |
| Logging | `core/utils/app_logger.dart` | `print()`, one of which logged the password in cleartext (audit M-4) |
| JWT | `core/utils/jwt.dart` | inline expiry check, now with clock leeway |
| Brands | `core/catalog/car_brand.dart` | **audit H-10 / M-0** — one serialisation, stable-name persistence |

## Phase 2 — Auth + clients data layer  ✅ done

* `features/auth/domain/entities/commercial_user.dart` — one object replacing ~20
  preference keys.
* `features/auth/data/user_profile_store.dart` — one atomic JSON write instead of
  twenty sequential ones; reads the legacy keys so existing installs survive.
* `features/auth/data/auth_repository_impl.dart` — sign-in is login **and**
  profile load, guarded against double submit; a 401 from `/auth/login` is
  reported as bad credentials, not as session expiry.
* `features/clients/` — `Client` / `ClientKind` / `GeoPosition` entities,
  `ClientMapper`, and `ClientsRepositoryImpl`: the portfolio source of truth,
  with concurrent B2B + sub-client fetches, partial-failure tolerance,
  de-duplication, freshness window, in-flight collapsing and cache-updating
  writes.
* Dead code removed: `domain/usecases`, `domain/entities/user_entity.dart`,
  `data/datasources`, `data/repositories` (audit M-1).

## Phase 3 — Map rendering core  ✅ partially done

* `features/cartography/presentation/marker_icon_cache.dart` — **audit H-2**.
  The pin asset is decoded once; finished `BitmapDescriptor`s are cached by
  `(kind, photo identity, pixel ratio)`; concurrent misses share one build.
  A hundred same-kind markers now build one icon instead of a hundred.

## Phase 3b — Post-login initialization  ✅ done

A dedicated screen between a successful sign-in and the map, so the map opens
with its data already loaded instead of filling in behind several spinners.

* `features/startup/presentation/cubit/` — `AppInitializationCubit` and a state
  whose phase is **derived from the step table**, so it cannot report "loading"
  after the work has settled. Four steps, taken from what
  `CommercialMapController.onInit` actually did: `profile`, `portfolio`,
  `location`, `mapAssets`. Stock is deliberately excluded — it is a separate
  screen that loads its own data.
* `profile` runs first because the portfolio endpoints are keyed by the
  representative's id; the other three are independent and run **concurrently**.
* `location` and `mapAssets` are non-critical: a refused GPS permission or a
  failed icon prewarm does not block entry. A critical failure offers **retry**
  and **continue without this data**; a 401 offers **sign in again** instead,
  since retrying cannot help.
* **No `Future.delayed` anywhere.** Progress is the fraction of settled steps and
  each message names a step that is genuinely in flight.
* `core/services/location_service.dart` — was an empty stub; now a real service
  behind an interface, with a hard timeout so a hung GPS fix cannot strand the
  screen.
* `core/di/service_locator.dart` — `get_it` composition root. `main()` awaits it,
  and now calls `runApp` exactly once (it previously called it a second time
  from a `catch`).
* The splash's 700 ms `Future.delayed` is gone, and a restored session takes the
  same path as a fresh sign-in rather than a second code path that can drift.

### Duplicate requests eliminated

`CommercialMapController` now reads the portfolio through `ClientsRepository`
instead of calling `AuthService` directly. Both `loadMyClients()` and
`loadAllSubClientsAndProspectsForCommercial()` delegate to one private
`_loadPortfolio()`, so `onInit` calling both costs **one** fetch — and because
the initialization screen filled the same cache moments earlier, that fetch is
normally served without touching the network.

Two bugs fixed on the way:

* `onInit` fired `_loadConnectedProfile()` without awaiting it and then
  immediately called `loadMyClients()`, which read `profileData['id']`. It was
  reliably empty, so the B2B fetch silently fell back to `/my-clients` instead of
  the commercial-scoped endpoint. The id now comes from `AuthRepository`, and
  the profile is awaited before the portfolio.
* `loadClientsByCommercialId()` had no callers and was removed.

`Client` gained `raw` (the untouched payload) and `toUiMap()`, so screens not yet
migrated to the typed entity lose no backend field while still benefiting from
the parsing fixes.

## Phase 3c — Map rendering  ◐ core fixes done, cubit extraction pending

The three defects behind the map's jank are fixed in place, before any larger
rewrite, because they are the ones that actually cost frames.

* **H-1 — the map no longer rebuilds on every GPS fix.**
  `initialCameraPosition` now reads a `static const`. That value is consumed
  *once*, when the platform view is created, and ignored afterwards — so the
  `Obx` was subscribing the whole map widget to the position stream for a value
  that could no longer have any effect. The camera is moved imperatively via
  `attachMapController` / `_moveCameraTo`.

  This also fixed a startup race: `_getCurrentLocation` skipped the camera move
  when `mapController` was still null, so a *fast* fix left the map on its
  default position. Centring is now driven by whichever of the two finishes last.

* **H-2 — marker icons come from `MarkerIconCache`.**
  `_buildClientMarkerIcon` and `_decodeImage` are deleted (~88 lines). Every
  marker used to trigger an asset load, decode, canvas rasterisation and PNG
  encode, per marker per refresh. The controller now shares the cache instance
  the initialization screen pre-warmed.

* **H-3 — marker refreshes are latest-wins.**
  `_refreshMarkers` is called from ~15 sites including the draggable pin's
  `onDragEnd`. It is `async` and ended in `assignAll`, so interleaved runs let a
  slower, older run commit last and overwrite newer markers. It now runs through
  `LatestWins`; superseded runs compute but do not commit.

### Measured effect

Comparing only `Flags=0` frames — real in-app jank, excluding the first-frame
samples (`Flags=1`), which measure cold start rather than map work:

| | Janked frames | Worst | Range |
| --- | --- | --- | --- |
| Before | 5 | 15220 ms | 1231–15220 ms |
| After | 3 | 868 ms | 738–868 ms |

The worst frame improves by roughly 17×, and the whole distribution moves under
one second. Treat this as indicative, not rigorous: single runs, debug mode, an
emulator, and the two sessions did not perform identical interactions.

#### A regression this exposed, and its fix

The first-frame sample (`Flags=1`) got *worse* in the same comparison, 772 ms →
2751 ms, because `await configureDependencies()` had been placed before
`runApp`, blocking the first frame on secure-storage reads and session restore.
The graph is now built inside the splash route instead, so the branding is on
screen while that work happens. This is safe because the splash is the initial
route and does not navigate until `configureDependencies()` has completed, so no
other route can reach the locator first.

### Why the emulator still cannot settle this

The numbers above are suggestive but the environment is not trustworthy:

* a debug build is JIT, not AOT, so frame times are dominated by compilation;
* the large cold-start stalls observed (`Skipped 276 frames`, `Davey 2751ms`
  with `Flags=1`, the first-frame marker) occur *before* `MapsInitializer` runs
  — they are `ProfileInstaller`, GC and JIT, not map work;
* Google Play Services on this emulator fails to fetch map configuration
  (`REQUEST_TIMEOUT`), so tiles never render and the marker path is not
  exercised realistically.

To measure properly: `flutter run --profile` on a **physical device**, with the
DevTools timeline, comparing frame times while panning a map that has a
representative number of clients. Do not trust emulator debug numbers.

### Still to do in this phase

* `MapCubit` / `LocationCubit` — extract camera, marker and selection state out
  of the 1900-line controller now that the expensive parts are fixed.
* The draft-per-keystroke write (audit H-4) still stands: `_saveDraft` is
  attached to nine `TextEditingController`s and performs a full JSON encode plus
  a disk write on every character typed.
* `LocationCubit` — permissions, GPS lifecycle, a position stream that is
  **not** read by the widget that hosts `GoogleMap` (audit H-1).
* New map page: `GoogleMap` outside any state-dependent builder, camera moved
  imperatively via the controller, form overlay as its own widget subtree.
* `ClientFormCubit` — form state with a debounced draft save, replacing the
  listener on nine `TextEditingController`s that wrote the whole draft to disk
  on **every keystroke** (audit H-4).

## Phase 4 — Stock  ⬜ not started

* `features/stock/` on `ApiBackend.stock`, so its token can no longer destroy the
  main session (audit C-1 — the storage fix is in place; the feature still needs
  to be moved onto it).
* Fix the pagination refresh that resets the cursor and then returns early,
  leaving results for the previous query on screen (audit H-8).

## Phase 5 — Sales (prototype features)  ⬜ not started

Dashboard, orders, products and visits are backed by `FakeDataService`, and
`SyncService` targets `https://api.dayco.tn/v1`, which does not exist. These
features keep working, behind a repository interface fed by the local source and
clearly marked as such, so they can be pointed at real endpoints when those
exist. **No endpoints will be invented.**

`SyncService`'s 5-minute `Timer.periodic` and connectivity-triggered syncing
against the dead host are removed (audit H-9).

## Phase 6 — App shell, DI, routing  ⬜ not started

* `get_it` service locator; one registration site, explicit lifetimes, and a
  reset on sign-out so no `permanent: true` singleton outlives the session.
* `main()` that fails loudly rather than calling `runApp` twice in a `catch`,
  with `debugProfileBuildsEnabled` off and the app-wide `SafeArea` removed
  (audit M-7).
* Delete the ~40 ride-hailing / wallet placeholder pages and their routes, left
  over from the template this project was forked from.

## Phase 7 — UI consistency pass  ⬜ not started

Shared loading / empty / error / retry widgets driven by `DataState`, consistent
buttons, forms, cards and spacing, and feedback after actions routed through one
mechanism instead of `Get.snackbar` calls made from inside business logic.
