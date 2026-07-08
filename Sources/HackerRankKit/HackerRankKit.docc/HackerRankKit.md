# ``HackerRankKit``

An unofficial Swift client for the HackerRank for Work REST API.

## Overview

`HackerRankKit` is the lean wire layer for the [HackerRank for Work](https://www.hackerrank.com/work)
v3 API: typed models for tests, candidates, questions, interviews, users, teams, and the
audit log; encode-only request bodies; a raw ``HackerRankError``; and the
``HackerRankClient`` that drives them all. The client wraps a generic paginated transport,
so list calls follow the `next` cursor, idempotent GETs retry on transient failures, and
JSON decoding happens off the main actor.

The library is deliberately presentation-free and locale-free: it carries the facts the
API returns and leaves how to phrase or display them to you. The companion
`HackerRankKitMock` product ships an in-process fake of the API, backed by canned
fixtures, for demo modes and tests with no network.

> Note: This is an unofficial client and is not affiliated with or endorsed by HackerRank.

## Getting started

Construct a client with a personal access token, then call the typed endpoint methods:

```swift
import HackerRankKit

let client = HackerRankClient(token: "your-personal-access-token")

let tests = try await client.testsPage()
let created = try await client.createTest(name: "Phone screen")
let me = try await client.currentUser()
```

For regional deployments, pass a custom `baseURL`.

### Paging

List methods return one ``Page`` plus a `next` cursor. Pass it back to fetch the
following page until `next` is `nil`:

```swift
var cursor: String? = nil
repeat {
    let page = try await client.questionsPage(after: cursor)
    render(page.items)
    cursor = page.next
} while cursor != nil
```

### Testing without a network

Add the `HackerRankKitMock` product and use the mock client, which serves canned fixtures
over an in-process `URLProtocol`:

```swift
import HackerRankKitMock

let client = HackerRankClient.mock()                  // seeded demo data
let badToken = HackerRankClient.mock(unauthorized: true) // every request answers 401
```

## Topics

### The client

- ``HackerRankClient``
- ``HackerRankError``
- ``Page``

### Tests

- ``Test``
- ``TestSection``
- ``TestCandidate``
- ``TestDetail``

### Questions

- ``Question``
- ``QuestionDetail``

### Interviews

- ``Interview``
- ``InterviewDetail``
- ``InterviewPerson``
- ``InterviewTranscript``
- ``InterviewMessage``

### Organization

- ``User``
- ``Team``
- ``AuditLogEntry``

### Created records

- ``CreatedTest``
- ``CreatedUser``
- ``CreatedTeam``
- ``CreatedInterview``
- ``InvitedCandidate``
- ``TeamMembershipResult``
