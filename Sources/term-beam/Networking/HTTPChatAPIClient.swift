import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - HTTP API Client Implementation

actor HTTPChatAPIClient: ChatAPIClientProtocol {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }

        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listRooms() async throws -> [RoomResponse] {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw ChatError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([RoomResponse].self, from: data)
    }

    func createRoom(name: String, password: String?) async throws -> RoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateRoomRequest(name: name, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try JSONDecoder().decode(RoomResponse.self, from: data)
    }

    func joinRoom(roomId: String, username: String, password: String?) async throws -> JoinRoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/join") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = JoinRoomRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try JSONDecoder().decode(JoinRoomResponse.self, from: data)
    }

    func leaveRoom(roomId: String, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/leave/\(userId)") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func getRoomUsers(roomId: String) async throws -> [UserResponse] {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)/users") else {
            throw ChatError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([UserResponse].self, from: data)
    }

    func getRoomInfo(roomId: String) async throws -> RoomResponse {
        guard let url = URL(string: "\(baseURL)/api/rooms/\(roomId)") else {
            throw ChatError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode(RoomResponse.self, from: data)
    }

    func getMessageHistory(roomId: String, limit: Int? = nil) async throws -> [Message] {
        var urlString = "\(baseURL)/api/rooms/\(roomId)/messages"
        if let limit = limit {
            urlString += "?limit=\(limit)"
        }

        guard let url = URL(string: urlString) else {
            throw ChatError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try JSONDecoder().decode([Message].self, from: data)
    }

    // MARK: - Private Helpers

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let data = data,
               let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ChatError.serverError(errorResponse.reason)
            }
            throw ChatError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
}
