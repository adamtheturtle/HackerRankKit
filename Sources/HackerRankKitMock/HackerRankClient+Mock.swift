//
//  HackerRankClient+Mock.swift
//  HackerRankKit
//
//  The `mock(...)` factory that backs a `HackerRankClient` with the in-process fake API.
//

import Foundation
import HackerRankKit

extension HackerRankClient {
    /// A client backed by the in-process fake API (``MockServer``), for demo modes and
    /// tests with no network.
    ///
    /// Pass `unauthorized: true` for a client whose mock server answers 401 for every
    /// request, to exercise the "bad token" path. `key` becomes the client's token; it
    /// defaults to "demo", and tests can pass a unique key each so a suite can run in
    /// parallel without sharing session state.
    public static func mock(unauthorized: Bool = false, key: String = "demo") -> Self {
        Self(token: key, session: MockServer.session(unauthorized: unauthorized))
    }
}
