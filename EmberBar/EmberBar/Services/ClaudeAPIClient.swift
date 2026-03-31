import Foundation

enum APIError: Error, LocalizedError {
    case noCookie
    case invalidCookie
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case noOrganization

    var errorDescription: String? {
        switch self {
        case .noCookie: return "No session cookie configured"
        case .invalidCookie: return "Session cookie is invalid or expired"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code): return "Server returned status \(code)"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .noOrganization: return "No organization found"
        }
    }
}

actor ClaudeAPIClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    private func buildRequest(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        return request
    }

    func fetchOrganizations(cookie: String) async throws -> [Organization] {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw APIError.invalidCookie
        }

        let request = buildRequest(url: url, cookie: cookie)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.invalidCookie
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode([Organization].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchUsage(cookie: String, orgId: String) async throws -> UsageResponse {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw APIError.invalidResponse(0)
        }

        let request = buildRequest(url: url, cookie: cookie)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.invalidCookie
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func validateCookie(_ cookie: String) async throws -> (orgId: String, orgName: String) {
        let orgs = try await fetchOrganizations(cookie: cookie)
        guard let org = orgs.first else {
            throw APIError.noOrganization
        }
        return (org.uuid, org.name ?? "Personal")
    }
}
