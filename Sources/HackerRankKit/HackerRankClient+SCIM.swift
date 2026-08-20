//
//  HackerRankClient+SCIM.swift
//  HackerRankKit
//
//  SCIM provisioning (`/Users`, `/Groups`) against ``HackerRankClient/scimBaseURL``.
//

import Foundation
import PaginatedRESTClient

extension HackerRankClient {
    /// Lists users from the SCIM provisioning endpoint (`GET /Users`).
    public func scimUsers(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMUser> {
        let url = try offsetURL(path: "/Users", limit: limit, offset: offset, base: scimBaseURL)
        return try await rest.performWithRetry(SCIMListResponse<SCIMUser>.self, request: try authorizedGET(url))
    }

    /// Retrieves a user from the SCIM provisioning endpoint (`GET /Users/{id}`).
    public func scimUser(id: String) async throws -> SCIMUser {
        try await fetch(SCIMUser.self, path: "/Users/\(Self.pathSegment(id))", base: scimBaseURL)
    }

    /// Creates a user through the SCIM provisioning endpoint (`POST /Users`).
    @discardableResult
    public func createSCIMUser(body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await send(SCIMUser.self, method: "POST", path: "/Users", body: body, base: scimBaseURL)
    }

    /// Replaces a user through the SCIM provisioning endpoint (`PUT /Users/{id}`).
    @discardableResult
    public func updateSCIMUser(id: String, body: SCIMUserWriteRequest) async throws -> SCIMUser {
        try await send(
            SCIMUser.self, method: "PUT", path: "/Users/\(Self.pathSegment(id))", body: body, base: scimBaseURL
        )
    }

    /// Patches a user through the SCIM provisioning endpoint (`PATCH /Users/{id}`).
    @discardableResult
    public func patchSCIMUser(id: String, body: SCIMPatchRequest) async throws -> SCIMUser {
        try await send(
            SCIMUser.self, method: "PATCH", path: "/Users/\(Self.pathSegment(id))", body: body, base: scimBaseURL
        )
    }

    /// Locks a user through the SCIM provisioning endpoint (`DELETE /Users/{id}`).
    public func lockSCIMUser(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "/Users/\(Self.pathSegment(id))", base: scimBaseURL)
    }

    /// Lists groups from the SCIM provisioning endpoint (`GET /Groups`).
    public func scimGroups(limit: Int = 100, offset: Int = 0) async throws -> SCIMListResponse<SCIMGroup> {
        let url = try offsetURL(path: "/Groups", limit: limit, offset: offset, base: scimBaseURL)
        return try await rest.performWithRetry(SCIMListResponse<SCIMGroup>.self, request: try authorizedGET(url))
    }

    /// Retrieves a group from the SCIM provisioning endpoint (`GET /Groups/{id}`).
    public func scimGroup(id: String) async throws -> SCIMGroup {
        try await fetch(SCIMGroup.self, path: "/Groups/\(Self.pathSegment(id))", base: scimBaseURL)
    }

    /// Creates a group through the SCIM provisioning endpoint (`POST /Groups`).
    @discardableResult
    public func createSCIMGroup(body: SCIMGroupWriteRequest) async throws -> SCIMGroup {
        try await send(SCIMGroup.self, method: "POST", path: "/Groups", body: body, base: scimBaseURL)
    }

    /// Patches a group through the SCIM provisioning endpoint (`PATCH /Groups/{id}`).
    @discardableResult
    public func patchSCIMGroup(id: String, body: SCIMPatchRequest) async throws -> SCIMGroup {
        try await send(
            SCIMGroup.self, method: "PATCH", path: "/Groups/\(Self.pathSegment(id))", body: body, base: scimBaseURL
        )
    }

    /// Deprovisions a group through the SCIM provisioning endpoint (`DELETE /Groups/{id}`).
    public func deprovisionSCIMGroup(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "/Groups/\(Self.pathSegment(id))", base: scimBaseURL)
    }
}
