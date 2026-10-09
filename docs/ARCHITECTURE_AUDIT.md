# STDP DAYCO Commercial — Architecture Audit

Audit of the repository at commit `29b0226`, 112 Dart files / ~21.6k LOC.
This document records what the application actually does, what is broken, and
why — it is the basis for the refactoring plan in `REFACTORING_PLAN.md`.

---

## 1. What the application actually is

A field application for STDP DAYCO commercial representatives. The real,
backend-connected workflow is:

1. **Login** with `codeClient` + password against `https://www.stdp-dayco.com`.
2. **Load the connected commercial's portfolio** — B2B clients, sub-clients and
   prospects.
3. **Cartography** — plot those clients on a Google map, pick/drag a location,
   create or update a client or prospect at that location, attach a photo.
4. **Stock consultation** against a *second*, separate backend
   `https://b2b.stdp-dayco.com`.

### 1.1 Two backends, not one

| Concern | Base URL | Auth |
| --- | --- | --- |
| Auth, clients, sub-clients, prospects, files | `https://www.stdp-dayco.com` | `POST /api/v1/auth/login` → Bearer |
| Stock consultation | `https://b2b.stdp-dayco.com` | `POST /api/v1/auth/login` + `X-Device-Id` → Bearer |

This distinction is load-bearing and is the root cause of finding **C-1** below.

### 1.2 Real API surface (to be preserved verbatim)

`lib/features/auth/data/services/auth_service.dart`:

```
POST   /api/v1/auth/login
GET    /api/v1/user/{id}                       (404-fallback → /api/v1/users/{id})
POST   /api/v1/auth/register/client
POST   /api/v1/sub-clients
GET    /api/v1/clients/{id}
PUT    /api/v1/clients/{id}                    (405-fallback → PATCH)
GET    /api/v1/clients/my-clients
GET    /api/v1/clients/commercial/{id}/clients
GET    /api/v1/sub-clients/{id}
PUT    /api/v1/sub-clients/{id}
DELETE /api/v1/sub-clients/{id}
GET    /api/v1/sub-clients/parent/{parentId}
GET    /api/v1/sub-clients/commercial/{commercialId}
POST   /api/v1/files/{entityType}/{entityId}/image   (404-fallback → /api/v1/files/upload/...)
GET    /api/v1/files/download/{...}
```

`lib/features/commercial/data/services/commercial_stock_service.dart`:

```
POST /api/v1/auth/login                                              (b2b host)
GET  /api/v1/stocks/admin/all?page&size&search&entrepot
GET  /api/v1/stocks/produit/{referenceOrId}
GET  /api/v1/stocks/produit/{referenceOrId}/disponibilite
GET  /api/v1/stocks/admin/produit/{produitId}/reservations-en-attente
```

`lib/features/commercial/data/services/map_service.dart` — Google Directions:

```
GET https://maps.googleapis.com/maps/api/directions/json
```

The response-shape tolerances (`content` / `data` / bare-array list unwrapping,
the 404 and 405 fallbacks) are **deliberate compatibility behaviour** and must
survive the refactor.

### 1.3 Map provider and key — preserved

Provider is `google_maps_flutter` (^2.14.2). The key
`AIzaSyBQyBRLDvdrrGQk3NT8Sm9c5lX7Nizvj24` appears in two places:

- `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- `lib/features/commercial/data/services/map_service.dart` (Directions API)

Both are kept. Note: **iOS has no key configured at all**, so the map is
non-functional on iOS today.

### 1.4 Real vs. prototype features

The repo contains two parallel worlds, which is the single most misleading thing
about it:

| Feature | Backing | Status |
| --- | --- | --- |
| Auth / login | real API | **real** |
| Clients, sub-clients, prospects | real API | **real** |
| Cartography / map | real API + Google | **real** |
| Stock consultation | real b2b API | **real** |
| Dashboard, orders, products, visits, deliveries | `FakeDataService` (654 LOC of hardcoded Tunisian sample data) | **prototype** |
| Offline sync (`SyncService`, sqflite) | `https://api.dayco.tn/v1` — a placeholder host that does not exist, marked `// Replace with actual API` | **dead** |

`register()`, `forgotPassword()`, `resetPassword()` and the OTP flow in
`AuthController` are `Future.delayed` simulations, not API calls.

~40 of the 750 lines of `lib/routes/app_pages.dart` are routes; the rest are
**placeholder stub pages inherited from a ride-hailing template** — driver
profile, ride requests, active ride, withdraw earnings, wallet, add money,
payment methods — each rendering `"… Page - Replace with actual implementation"`.

---

## 2. Findings

Severity: **C** critical (data loss / broken behaviour), **H** high (user-visible
instability or lag), **M** medium (maintainability / correctness risk).

### C-1 — The stock backend overwrites the main session token

`CommercialStockService.loginAndGetToken()` writes the b2b host's token into
`SharedPreferences` under **the same keys the main `AuthService` uses**:

```dart
await prefs.setString('access_token', accessToken);   // same key as main auth
await prefs.setString('refresh_token', refreshToken);
await prefs.setString('user_email', ...);
```

Two different hosts share one token slot. Signing in to stock silently replaces
the credentials used for every client/prospect/map call, so subsequent calls to
`www.stdp-dayco.com` carry a token issued by `b2b.stdp-dayco.com` and fail with
401. This is a direct cause of the reported "inconsistent states" and apparently
random logouts. **Tokens must be namespaced per backend.**

### C-2 — The project does not compile

`lib/core/theme/animation_config.dart` referenced `CupertinoPageTransitionsBuilder`
without importing `cupertino.dart` (it moved to `package:flutter/cupertino.dart`)
and `FadeUpwardsPageTransitionsBuilder`, removed in Flutter 3.47. The file is
reached from `main.dart`, so `flutter build` fails on a clean checkout.
*(Fixed — see §4.)*

### C-3 — `dev_dependencies` is corrupted; no test can run

In `pubspec.yaml` the `flutter_launcher_icons:` configuration block was nested
**inside** `dev_dependencies`, so `flutter_test` and `flutter_lints` were parsed
as launcher-icon settings rather than dependencies. `package:flutter_test` was
unresolvable and the test suite could not be compiled at all — there was no way
to write a regression test for anything. The nested block also pointed at
`assets/images/logo.svg`, which does not exist and is an unsupported format.
*(Fixed — see §4.)*

### H-1 — Every GPS fix rebuilds the whole Google map

`commercial_map_page.dart:669`:

```dart
Obx(() => GoogleMap(
      mapType: controller.selectedMapType.value,
      initialCameraPosition: CameraPosition(
        target: controller.currentPosition.value != null   // ← tracked
            ? LatLng(...currentPosition...)
            : const LatLng(36.8065, 10.1815),
      ),
      ...
    ))
```

The `Obx` closure reads `currentPosition`, so **every position update rebuilds
the `GoogleMap` platform view** — even though the value is only used for
`initialCameraPosition`, which is ignored after creation. This is the primary
source of the map lag and flicker. The camera should be moved imperatively via
the `GoogleMapController`, and the widget subtree must not depend on the
position stream.

### H-2 — Marker icons are rasterised from scratch, per marker, on every refresh

`_buildClientMarkerIcon()` does, **for every single marker**:

1. `rootBundle.load('assets/images/picker.png')` — no cache,
2. `instantiateImageCodec` decode,
3. `PictureRecorder` + `Canvas` draw,
4. `picture.toImage()` rasterise,
5. `toByteData(format: png)` PNG-encode.

`_refreshMarkers()` loops over every registered pin and every sub-client and
awaits that pipeline for each. With 100 clients that is 100 asset loads, 100
decodes, 100 rasterisations and 100 PNG encodes — **per refresh**.

`_refreshMarkers()` is invoked from ~20 call sites, including `onDragEnd` of the
draggable marker (i.e. continuously while dragging) and after each draft change.
Icons depend only on `(markerType, imageBase64)`, so they are trivially
cacheable. Nothing is cached.

### H-3 — `_refreshMarkers()` has no re-entrancy guard (marker desync)

It is `async`, awaits per-marker work, and finishes with
`markers.assignAll(nextMarkers)`. Concurrent invocations interleave, and a
*slower, older* run can complete last and clobber the newer marker set. This is
the "UI not reflecting actual state" symptom on the map. It needs sequencing
(latest-wins) rather than fire-and-forget `unawaited(...)`.

### H-4 — Every keystroke writes the whole form draft to disk

`_attachDraftListeners()` registers `_saveDraft` on nine `TextEditingController`s.
`_saveDraft()` is un-debounced and does
`SharedPreferences.getInstance()` → build a map → `jsonEncode` → disk write.
So typing a 20-character company name performs 20 full JSON serialisations and 20
disk writes, on the UI thread's microtask queue. This is the form-typing lag.

### H-5 — The page re-creates its controller on every build

`commercial_map_page.dart` is a `StatelessWidget` whose `build()` runs:

```dart
final controller = Get.put(CommercialMapController());
final scaffoldKey = GlobalKey<ScaffoldState>();
```

`Get.put` is called on **every rebuild**, re-registering the controller, and a
fresh `GlobalKey` is allocated each time. The `commercialMap` route is also the
only route with **no binding** at all. Controller lifetime is therefore tied to
widget rebuilds instead of to the route.

### H-6 — Leaked listeners and undisposed controllers

`onClose()` disposes nine of the ten `TextEditingController`s —
**`noteController` is never disposed** — and never removes the nine
`addListener(_saveDraft)` subscriptions registered in `onInit`.

### H-7 — Double-submit is unguarded

`AuthController.login()` sets `isLoginLoading` *after* validation but has no
in-flight guard, so a double tap fires two full login round-trips (and two
`getUserDetails` calls). The same pattern recurs in the client-creation and
client-update paths on the map controller.

### H-8 — Pagination refresh is silently dropped, leaving stale results

`CommercialStockController.refreshStocks()` resets `_currentPage = 0` and
`hasMore = true`, then calls `_loadPage(reset: true)`, which begins with:

```dart
if (isLoading.value || isLoadingMore.value) return;
```

A refresh issued while a load is in flight therefore **returns without loading**
— but the paging cursor has already been reset. Because `refreshStocks` is the
debounced handler for `searchQuery`, typing a new query while the previous page
is loading leaves the list showing results for the *old* query with a corrupted
cursor.

### H-9 — Dead background work on a non-existent host

`SyncService` is registered `permanent: true` and starts a
`Timer.periodic(Duration(minutes: 5))` plus a `Connectivity().onConnectivityChanged`
subscription that calls `syncAll()` on every connectivity change. Every request
it makes targets `https://api.dayco.tn/v1`, a placeholder that does not resolve,
with no auth header. All failures are swallowed into `print('Sync error: $e')`.
This is unbounded background activity producing nothing.

### H-10 — Brands are written in two different vocabularies

The same `marques` field was serialised two ways:

| Call site | Representation | Example |
| --- | --- | --- |
| sub-client **create** (`_buildSubClientPayload`) | `brand.name` | `mercedBenz` |
| sub-client **update** (`updateSubClientFromForm`) | `brand.displayName` | `Mercedes-Benz` |
| B2B create / update | `brand.displayName` | `Mercedes-Benz` |

So a prospect created in the field stored `"mercedBenz"`, and the first edit of
that record silently rewrote it to `"Mercedes-Benz"`. Any backend-side grouping,
filtering or reporting on `marques` sees two distinct values for one brand.
Reading already tolerated both forms (`_mapBrandValues` normalised either), which
is why this was invisible in the app itself.

### M-0 — Brand selections persist enum *indices*

`CarBrandsModel.toJson()` wrote `brand.index` and `fromJson` read
`CarBrand.values[index]`. The catalog is a hand-maintained list of 45 brands
grouped by country, so inserting one brand in the middle — the obvious way to
add a brand — silently remaps every brand already stored on every client.
`CarBrand.values[index]` also raises `RangeError` on an out-of-range value,
taking the whole client payload down rather than skipping one brand.

### M-1 — The `domain/` layer is entirely dead code

`features/auth/domain/{entities,repositories,usecases}` plus
`features/auth/data/{datasources,repositories}` are referenced by **nothing**.
Verified: no import of `LoginUseCase`, `AuthRepository`, `AuthRemoteDataSource`
or `UserEntity` exists outside those files. The live path is
`AuthController → AuthService` directly. The Clean Architecture scaffolding is
decorative.

### M-2 — God objects

- `commercial_map_controller.dart` — 1946 LOC. Holds map state, ten form
  controllers, geolocation, image picking, HTTP calls, `SharedPreferences`
  persistence, navigation (`Get.offAllNamed`), and `Get.snackbar` presentation.
- `commercial_map_page.dart` — 2103 LOC, 21 `Obx` blocks in one file.

### M-3 — Business logic and presentation fused

Controllers call `Get.snackbar` and `Get.toNamed` directly, so business logic
cannot be tested without a `GetMaterialApp` and a render tree. Error handling is
`throw Exception('string')` throughout, and the UI recovers the message with
`e.toString().replaceFirst('Exception: ', '')` — a string contract, not a typed
one.

### M-4 — Credentials and tokens in plaintext logs and storage

`AuthController.login()` runs `print("Login request: ${loginRequest.toJson()}")`,
which **logs the user's password in cleartext**. `AuthService.login()` prints the
whole response (including tokens) plus `print("000000000000000000000000000")`.
Tokens live in `SharedPreferences`, which is not encrypted.

### M-5 — No HTTP interceptors; per-request preference reads

Each `AuthService` method independently calls
`await SharedPreferences.getInstance()` to read the token and build an `Options`
object. There is no `Dio` interceptor, no central 401 handling, no token refresh
(a `refresh_token` is stored but **never used**), no retry, and no cancellation.
`AuthService` is also instantiated ad hoc (`AuthService()`) in the splash page,
the auth controller and the map controller — three separate `Dio` instances with
three separate connection pools.

### M-6 — Empty placeholder files committed as if implemented

`core/services/location_service.dart`, `core/constants/api_endpoints.dart`,
`core/constants/app_colors.dart`, `core/constants/app_strings.dart`,
`core/env/env_staging.dart` and `core/bindings/app_binding.dart` contain only a
comment line. `core/env/env_dev.dart` points at `10.0.2.2:8080` and is unused;
every service hardcodes its own base URL instead.

### M-7 — Unsafe initialisation and swallowed startup errors

`main()` wraps initialisation in `try/catch` and on failure calls
`runApp(const MyApp())` **again** with a `print`. `debugProfileBuildsEnabled = true`
is left on in the committed code. `MyApp` wraps `GetMaterialApp` in a `SafeArea`
(so system-bar insets apply to the whole app, including the map) and resolves the
locale by calling `Get.find<LanguageService>()` inside `build()` in a `try/catch`.

---

## 3. Root-cause summary

The symptoms the brief describes map onto a small number of structural causes:

| Reported symptom | Actual cause |
| --- | --- |
| Map lag / flicker | H-1 (map rebuilt on every GPS fix), H-2 (uncached marker rasterisation) |
| UI not matching state | H-3 (racing marker refresh), H-8 (dropped refresh) |
| Form typing lag | H-4 (disk write per keystroke) |
| Duplicated requests | H-7 (no in-flight guard), M-5 (no request de-duplication) |
| Stuck loading indicators | `finally`-less error paths + H-8's early return after state reset |
| Background activity | H-9 (timer + connectivity sync against a dead host) |
| Memory leaks | H-6 (undisposed controller, unremoved listeners), `permanent: true` everywhere |
| Unmaintainable code | M-1 (dead layer), M-2 (god objects), M-3 (fused concerns) |
| Random logouts | **C-1 (token slot collision between two backends)** |
| Brand data drifting | H-10 (two serialisations), M-0 (index-based persistence) |

---

## 4. Already fixed in this pass

1. **C-3** — `pubspec.yaml` `dev_dependencies` restored (`flutter_test`,
   `flutter_lints ^6.0.0`) and the misnested `flutter_launcher_icons` block
   removed; the canonical config in `flutter_launcher_icons.yaml` (which
   correctly points at `logo.png`) is now the only one. Added `bloc_test` and
   `mocktail` for the test suite, and `flutter_bloc`, `bloc`, `equatable`,
   `get_it`, `flutter_secure_storage` for the target architecture.
2. **C-2** — `animation_config.dart` now imports `package:flutter/cupertino.dart`
   and uses `FadeForwardsPageTransitionsBuilder`. `flutter analyze` goes from
   **23 errors to 0**.

The project now compiles and the test suite can be built for the first time.

3. **H-10 / M-0** — `CarBrandCodec` (in `lib/core/catalog/car_brand.dart`) is now
   the single place brands are serialised. It writes `displayName` — the form two
   of the three original call sites already used — and parses both forms
   case-, accent- and punctuation-insensitively, so records written as
   `"mercedBenz"` still resolve. `CarBrandsModel` now persists stable enum names,
   still reads the legacy index form, skips out-of-range indices instead of
   throwing, and no longer aliases its list in `copyWith`.

---

## 5. Notes for whoever works on this next

### `Picture.toImage` and codec ownership

`ui.Codec.dispose()` must not be called before the `ui.Image` obtained from
`codec.getNextFrame()` has been consumed: the image is owned by the codec, and
drawing an invalidated image makes the subsequent `Picture.toImage()` **never
complete** rather than throw. That is a silent hang, and it is easy to introduce
while "tidying up" resource handling.

### `Future.whenComplete` and `Map.remove`

`whenComplete` *awaits* a `Future` returned by its callback. Writing

```dart
return future.whenComplete(() => _pending.remove(key));   // WRONG
```

against a `Map<K, Future<T>>` returns the removed future from the callback. If
the map holds the very future being completed, it waits on itself and never
resolves. Always use a block body for this:

```dart
return future.whenComplete(() { _pending.remove(key); });
```

### Tests that rasterise

Anything touching `instantiateImageCodec`, `Picture.toImage` or
`Image.toByteData` must run inside `testWidgets` + `tester.runAsync`. Under a
plain `test()` those futures never resolve and the test simply times out with no
error message.

### Android toolchain

The project did not build on this machine. Three constraints interact:

* Flutter 3.47 requires **Gradle ≥ 8.14**; the wrapper pinned `8.12`.
* `JAVA_HOME` points at Android Studio's bundled JBR, which is **JDK 25**.
  Java 25 requires **Gradle ≥ 9.1**.
* Gradle 9 requires **AGP 9**, and Flutter's own diagnostic reports that AGP 9
  reads only the new DSL, which "results in a build failure when applying the
  Flutter Gradle plugin" while `android.newDsl=false` is set in
  `gradle.properties`.

Resolved by taking the middle path, climbing each of Flutter's minimum-version
floors in turn:

| Component | Was | Now | Floor it cleared |
| --- | --- | --- | --- |
| Gradle (`gradle-wrapper.properties`) | 8.12 | **8.14.3** | Flutter minimum 8.14.0 |
| AGP (`settings.gradle.kts`) | 8.9.1 | **8.11.1** | Flutter minimum 8.11.1 |
| Kotlin (`settings.gradle.kts`) | 2.1.0 | **2.2.20** | Flutter minimum 2.2.20 |
| Build JDK | 25 (Studio JBR) | **19** (`flutter config --jdk-dir`) | Gradle 8.14 supports ≤ Java 24 |

`android.newDsl=false` is left alone, since AGP stays on 8.x.

Verified: `flutter build apk --debug` succeeds, and the app installs and runs on
`emulator-5554` (Android 17 / API 37) through to the login screen with no Dart
exceptions.

#### A failure mode worth remembering

One build failed with
`Failed to install ... build-tools;35.0.0` /
`java.io.EOFException: Unexpected end of ZLIB input stream`.

That was not a toolchain incompatibility. AGP 8.11.1 needs build-tools 35.0.0,
which was absent, and **two builds were installing it concurrently** (a CLI
build and an IDE `flutter run`), each unpacking into its own
`<sdk>/.temp/PackageOperationNN` and corrupting the result. The fix is to run
one build at a time, delete the leftover `PackageOperation*` directories, and
let a single install finish.

Note also that Flutter appends a generic
"Gradle build failed due to Java/Gradle incompatibility … Java version used for
the build is 25.0.3" epilogue to *any* Gradle failure. It was misleading here:
every Gradle JVM was in fact `jdk-19`. Check the real `What went wrong:` block
before acting on that epilogue.

Two caveats for whoever picks this up:

* `gradle.properties` hardcodes `org.gradle.java.home=C:\Program Files\Java\jdk-19`,
  an absolute path that exists only on this machine. Any other checkout or CI
  runner will fail on it. It should be replaced by a per-developer
  `android/local.properties` entry or an environment variable.
* JDK 19 is long past end-of-life and is a stopgap, chosen because it is the
  only non-25 JDK installed here. Installing **JDK 21 (LTS)** and pointing both
  `flutter config --jdk-dir` and `org.gradle.java.home` at it is the right
  durable fix; AGP 8.9 and Gradle 8.14 both support it.

### Release build is not releasable

`android/app/build.gradle.kts` still carries the Flutter template defaults:

* `applicationId` and `namespace` are `com.example.dayco_mobile` — a placeholder.
  Note the Google Maps key is restricted by package name, so changing this
  requires updating the key's restriction in the Google Cloud console first or
  the map stops working.
* the `release` build type signs with the **debug** keystore, so no release
  artifact can be published.
* `android:usesCleartextTraffic="true"` is set in the main manifest, permitting
  plain HTTP app-wide. Both production backends are HTTPS; this belongs in the
  (already-present) `src/debug` manifest, for the local `10.0.2.2:8080` config.
* `android:label` is `dayco_mobile` rather than a presentable product name.
* `android.enableJetifier=true` is set, which is deprecated and slows every
  build; it is only needed for pre-AndroidX dependencies.

### The map renders blank: the API key does not authorise this build

Symptom: the map area is empty but the "Google" watermark is drawn. That
combination means the Maps SDK initialised correctly and the *tile
authorisation* failed — it is never a Flutter-side bug.

Probing the key directly (the app makes this exact call itself, from
`map_service.dart`) returns:

```
$ curl "https://maps.googleapis.com/maps/api/directions/json?origin=...&key=AIza...izvj24"
{
  "error_message": "This IP, site or mobile application is not authorized to
                    use this API key. Request received from IP address ...,
                    with empty referer",
  "status": "REQUEST_DENIED"
}
```

So the key carries an **Android apps** application restriction. Such a key
authorises a request only when *both* match:

* the package name — here `com.example.dayco_mobile`; and
* the SHA-1 of the certificate the APK was signed with.

Debug keystores are generated per machine. This machine's
`~/.android/debug.keystore` was created on 2026-09-30, so its fingerprint was
almost certainly never registered against the key:

```
SHA-1: 69:92:D7:66:EE:66:09:B7:55:10:BF:83:24:FC:50:F6:3A:69:6E:0B
```

**Fix** (Google Cloud Console → APIs & Services → Credentials → the key →
Application restrictions → Android apps → Add):

| Field | Value |
| --- | --- |
| Package name | `com.example.dayco_mobile` |
| SHA-1 | `69:92:D7:66:EE:66:09:B7:55:10:BF:83:24:FC:50:F6:3A:69:6E:0B` |

Every developer machine and every CI signing certificate needs its own entry,
and the **release** keystore's SHA-1 must be added before shipping. Also
confirm "Maps SDK for Android" is enabled on the project and that billing is
active — both also produce a blank map.

Obtain a machine's debug fingerprint with:

```
keytool -list -v -keystore ~/.android/debug.keystore \
        -alias androiddebugkey -storepass android -keypass android
```

### The same key cannot work for the Directions API

`map_service.dart` calls `https://maps.googleapis.com/maps/api/directions/json`
over plain HTTP with the **same** Android-restricted key. That can never
succeed: Android application restrictions apply to the Maps SDK, and web
service APIs called over HTTPS are rejected with the `REQUEST_DENIED` above —
which is exactly what the probe shows.

So every route, route-optimisation and directions-info call in the app is
failing, and has been failing silently (the errors were swallowed by
`print('Error getting route: ...')`, now at least logged via `AppLogger`).

Fixing this needs a **second credential**, because one key cannot hold both an
Android restriction and a server restriction:

* keep the existing Android-restricted key for the map itself, and
* add an IP-restricted (server) key for the Directions web service, ideally
  proxied through the backend so it is not shipped in the APK at all.

This is a deliberate open item rather than a change made unilaterally — it
needs a new credential, which is the project owner's decision.

### iOS has no Google Maps key

`ios/Runner` configures no `GMSServices` API key, so the map does not work on
iOS at all. The Android key is in `AndroidManifest.xml`. This is unresolved and
needs the key to be added to the iOS target before any iOS release.
