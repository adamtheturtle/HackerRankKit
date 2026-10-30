# HackerRankKit

An unofficial Swift client for the HackerRank for Work REST API, with typed models and a no-network mock backend.

[Documentation](https://swiftpackageindex.com/adamtheturtle/HackerRankKit/documentation/hackerrankkit) | [Swift Package Index](https://swiftpackageindex.com/adamtheturtle/HackerRankKit)

## Installation

```swift
.package(url: "https://github.com/adamtheturtle/HackerRankKit.git", from: "0.8.0")
```

Releases before 0.8.0 modelled a wire contract that did not match the API, so 0.8.0 is the earliest version worth starting from.
Upgrading from an earlier one?
See [UPGRADING.md](UPGRADING.md).

Add `HackerRankKit` to your app target and `HackerRankKitMock` to tests or demos that should run without the network.

## Products

- `HackerRankKit`: Typed API client for tests, candidates, questions, interviews, users, teams, and the audit log.
- `HackerRankKitMock`: In-process fake API seeded with canned data.

## Usage

```swift
import HackerRankKit

let client = try HackerRankClient(token: "your-personal-access-token")

let tests = try await client.testsPage()
// `duration`, `roleIDs`, and `experience` are required by the create API alongside the name.
let created = try await client.createTest(
    name: "Phone screen",
    duration: 60,
    roleIDs: ["backend-engineer"],
    experience: ["Senior"]
)
```

## Project AI prompts

Pass `QuestionWriteOptions(customSystemPrompt: "Give hints without solving the task.")`
when creating or updating a project question.
Prompts may contain up to 15,000 characters and are sent as the top-level
`custom_system_prompt` field, as confirmed by HackerRank support.
`nil` omits the field; `""` explicitly clears it.
Whitespace is preserved.
`Question.customSystemPrompt` exposes the value when HackerRank returns it.

## Requirements

- Swift 6.2+
- macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+

## License

MIT.
See [LICENSE](LICENSE).
