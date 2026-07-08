# HackerRankKit

An unofficial Swift client for the HackerRank for Work REST API, with typed models and a
no-network mock backend.

[Documentation](https://swiftpackageindex.com/adamtheturtle/HackerRankKit/documentation/hackerrankkit) |
[Swift Package Index](https://swiftpackageindex.com/adamtheturtle/HackerRankKit)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/HackerRankKit.git", from: "0.1.0")
```

Add `HackerRankKit` to your app target and `HackerRankKitMock` to tests or demos that
should run without the network.

## Products

- `HackerRankKit`: Typed API client for tests, candidates, questions, interviews, users,
  teams, and the audit log.
- `HackerRankKitMock`: In-process fake API seeded with canned data.

## Usage

```swift
import HackerRankKit

let client = HackerRankClient(token: "your-personal-access-token")

let tests = try await client.testsPage()
let created = try await client.createTest(name: "Phone screen")
```

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+

## License

MIT. See [LICENSE](LICENSE).
