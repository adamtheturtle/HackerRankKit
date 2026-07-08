# Migrating RankBuddy onto HackerRankKit

This package was extracted from `rankbuddy-macos` (issue #61) and is modelled closely on
[CoderPadKit](https://github.com/adamtheturtle/CoderPadKit): two products
(`HackerRankKit` + `HackerRankKitMock`), a flat source layout, a presentation-free error
type, and the same client/mock conventions. It builds and tests green on its own
(`swift test` in this directory — 15 tests). The remaining work needs Xcode and can't be
done from the CLI without editing `project.pbxproj` (hook-blocked / crashes Xcode), so
it's left for you.

## 1. Split into its own repo

```sh
cd HackerRankKit
git init && git add . && git commit -m "Extract HackerRankKit from rankbuddy-macos"
gh repo create adamtheturtle/HackerRankKit --public --source=. --push
git tag 0.1.0 && git push --tags
```

`LICENSE` (MIT), `.spi.yml` (Swift Package Index docs for both targets), the CI workflow,
and a committed `Package.resolved` are already in place, mirroring CoderPadKit.

## 2. Add the package dependency in Xcode

**File ▸ Add Package Dependencies…**, point at the repo (or the local folder). Add:

- `HackerRankKit` → the **rankbuddy-macos** app target.
- `HackerRankKitMock` → the **rankbuddy-macosTests** target (and the app target too, if
  the app keeps an in-app demo mode — see step 5).

## 3. Delete the app's now-duplicated sources

Moved into `HackerRankKit` (flattened — no `Models/`/`Networking/` subfolders):

**`rankbuddy-macos/Networking/`**: `HackerRankClient.swift`,
`HackerRankClient+AllUsers.swift`, `HackerRankClient+AuditLog.swift`,
`HackerRankClient+Search.swift`, `HackerRankError.swift`, `HackerRankPage.swift`,
`WriteRequests.swift` (now `Requests.swift` in the package). The single-resource reads
that were in `HackerRankClient+Test/+Question/+Interview.swift` are now methods on the
client itself.

**`rankbuddy-macos/Models/`** (the whole folder).

Moved into `HackerRankKitMock` (see step 5 before deleting): the `MockHackerRankURLProtocol*`
files and the `URLSession.rankBuddyDemo` extension.

## 4. Re-add the `Account` convenience initializer

The library client is domain-free: `HackerRankClient(token:baseURL:session:)`. The demo
routing is app-specific, so add this file to the **app target** to keep every
`HackerRankClient(account:)` call site working unchanged:

```swift
//
//  HackerRankClient+Account.swift
//  rankbuddy-macos
//

import Foundation
import HackerRankKit
import HackerRankKitMock

extension HackerRankClient {
    /// Builds a client for a stored `Account`, routing mock accounts to the in-process
    /// fake API and real accounts to the live session (tests can inject a session).
    init(account: Account, session: URLSession? = nil) {
        if let session {
            self.init(token: account.token, baseURL: account.baseURL, session: session)
        } else if account.token == Account.badKeyDemoToken {
            self = .mock(unauthorized: true)
        } else if account.isMock {
            self = .mock()
        } else {
            self.init(token: account.token, baseURL: account.baseURL)
        }
    }
}
```

## 5. Adopt the mock (and mind the gaps)

`HackerRankKitMock` replaces `MockHackerRankURLProtocol` with CoderPadKit's shape:
`HackerRankClient.mock()` (seeded) and `.mock(unauthorized: true)` (every request 401).
The demo fixtures were ported verbatim. Two deliberate differences from the old app mock:

- **Only success + unauthorized scenarios.** The old `RANKBUDDY_DEMO_SCENARIO`
  empty/malformed/throttled/server_error modes are **not** in the package (CoderPadKit has
  no equivalent). If the app still needs those for demoing UI states or screenshots, keep a
  thin app-side `URLProtocol` for them; otherwise drop them.
- **No captured request bodies.** The old mock's `lastRequestBody(forPath:)` is gone.
  Write-flow tests that asserted the exact JSON sent should instead assert on the returned
  echo record, or keep a small app-side capturing protocol.

## 6. Re-add user-facing error text

`HackerRankError` is now presentation-free (`Error, CustomStringConvertible, Sendable` with
positional cases and an `isUnauthorized` flag) — it no longer conforms to `LocalizedError`.
Add the app's copy back as an extension in the **app target**:

```swift
import Foundation
import HackerRankKit

extension HackerRankError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No HackerRank token is configured for this account."
        case let .http(status, _):
            switch status {
            case 401, 403: "The token was rejected. Check that it is a valid HackerRank for Work token."
            case 429: "HackerRank is rate-limiting requests. Please try again shortly."
            case 404: "The requested HackerRank resource was not found."
            default: "HackerRank returned an unexpected error (HTTP \(status))."
            }
        case .decode:
            "The response from HackerRank could not be read."
        case let .network(error):
            "Could not reach HackerRank: \(error.localizedDescription)"
        }
    }
}
```

Also update the app's `HackerRankError` references for the renamed cases: `.http(status:body:)`
→ `.http(_, _)` (positional) and `.decoding(_)` → `.decode(_)` (in `AccountHealthMonitor` and
the error tests).

## 7. Make the symbols visible to the app

The models and client are referenced across almost the entire app, so rather than adding
`import HackerRankKit` to ~40 files, add **one** shim to the app target:

```swift
//  HackerRankKitExports.swift
@_exported import HackerRankKit
```

The **test target** doesn't inherit `@_exported`, so add `import HackerRankKit` (and
`import HackerRankKitMock` where the mock is used) to the test files the compiler flags, and
drop any `rankbuddy_macos.` qualifier tests wrote (e.g. `rankbuddy_macos.Test` → `Test`).

## 8. Client-level tests

The package already covers the models, the error type, and end-to-end mock behavior
(`ModelTests`, `MockServerTests`). The app's `TransportErrorMappingTests` /
`ModelDecodingResilienceTests` / `MockHackerRankServerTests` are now largely redundant —
merge anything unique into the package suite and delete the rest, or keep them in the app
test target importing `HackerRankKit`/`HackerRankKitMock`.

## What was intentionally *not* extracted

- **`Account`** and everything above the client (views, stores, caches).
- The extra demo **scenarios** and **request-body capture** (see step 5).

## Design notes

- Structure mirrors CoderPadKit: flat sources, `Logging.swift` (with `loggedDecodeIfPresent`,
  which logs decode drift instead of silently swallowing it), `Requests.swift`, a DocC
  catalog, and the `HackerRankKitMock` companion product.
- The client dropped the `Account` dependency for `token` / `baseURL` / `session`, and
  gained CoderPadKit's static surface (`defaultBaseURL`, `liveSession`, `live(token:)`,
  `makeDecoder`/`makeEncoder`, `decoder`/`encoder`).
- `LenientElement` was inlined (it was buddy-kit's `BuddyAppKit.LenientElement`) so the
  library depends only on `PaginatedRESTClient`.
- All model/response types are `public` and explicitly `Sendable` (public types don't get
  the implicit `Sendable` the internal originals relied on), with public memberwise
  initializers so consumers and previews can build fixtures.
- Package settings mirror the app target: Swift 6 language mode, `MainActor` default
  isolation, and the `NonisolatedNonsendingByDefault` / `InferIsolatedConformances`
  upcoming features.
