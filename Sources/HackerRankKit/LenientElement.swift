//
//  LenientElement.swift
//  HackerRankKit
//

import Foundation

/// Wraps a decodable element so a per-element decode failure yields `nil` instead of
/// aborting the whole array — letting the page decoder drop an individual invalid
/// element while keeping the rest.
///
/// `nonisolated` because models decode off the main actor inside the REST client, while
/// the target's default actor isolation is `MainActor`; without this, the synthesized
/// `Decodable` conformance would be `MainActor`-isolated and unusable from an off-main
/// `init(from:)`. The type is a value type whose only stored property is an immutable
/// `Wrapped?`, so it stays trivially `Sendable` whenever `Wrapped` is.
nonisolated struct LenientElement<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: any Decoder) {
        value = try? decoder.singleValueContainer().decode(Wrapped.self)
    }
}
