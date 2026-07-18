// swift-tools-version: 6.2
import PackageDescription

/// Shared Swift settings. The `nonisolated` annotations throughout the sources are
/// written against `MainActor` default isolation so the request, pagination, and
/// decoding paths can run off the main actor.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
    // SWIFT_APPROACHABLE_CONCURRENCY: the file's `nonisolated` async methods run on
    // the caller's actor (SE-0461) rather than hopping to the main actor.
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

/// An unofficial Swift client for the HackerRank for Work REST API.
///
/// `HackerRankKit` is the lean wire layer: typed models, request bodies, a raw error
/// type, and the `HackerRankClient` that drives them over the `PaginatedRESTClient`
/// transport. `HackerRankKitMock` is an opt-in in-process fake of the API, backed by
/// canned fixtures, for demo modes and tests with no network.
///
/// Both targets use the Swift 6 language mode with `MainActor` default actor
/// isolation, against which the source's `nonisolated` annotations are written so the
/// networking and decoding can run off the main actor.
let package = Package(
    name: "HackerRankKit",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "HackerRankKit", targets: ["HackerRankKit"]),
        .library(name: "HackerRankKitMock", targets: ["HackerRankKitMock"])
    ],
    dependencies: [
        .package(url: "https://github.com/adamtheturtle/PaginatedRESTClient.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "HackerRankKit",
            dependencies: [
                .product(name: "PaginatedRESTClient", package: "PaginatedRESTClient")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HackerRankKitMock",
            dependencies: ["HackerRankKit"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HackerRankKitTests",
            dependencies: ["HackerRankKit", "HackerRankKitMock"],
            swiftSettings: swiftSettings
        )
    ]
)
