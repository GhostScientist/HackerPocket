//
//  HNAuthManager.swift
//  HackerPocket Watch App
//
//  Manages Hacker News authentication and comment submission
//  via the unofficial web form interface.
//

import Foundation
import Security

class HNAuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var username: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://news.ycombinator.com"
    private let keychainService = "com.dakotakim.HackerPocket.hn"
    private let session: URLSession

    private var sessionCookies: [HTTPCookie] = []

    init(session: URLSession = .shared) {
        self.session = session
        restoreSession()
    }

    // MARK: - Login

    func login(username: String, password: String) {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(baseURL)/login") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "acct=\(urlEncode(username))&pw=\(urlEncode(password))&goto=news"
        request.httpBody = body.data(using: .utf8)

        // Use a session that captures cookies
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response"
                    return
                }

                // Check for the user cookie which indicates successful login
                if let headerFields = httpResponse.allHeaderFields as? [String: String],
                   let responseURL = httpResponse.url {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
                    let userCookie = cookies.first(where: { $0.name == "user" })

                    if let userCookie = userCookie {
                        self.sessionCookies = cookies
                        self.username = username
                        self.isLoggedIn = true
                        self.saveSession(cookie: userCookie.value, username: username)
                        return
                    }
                }

                // Also check if response body contains "Bad login"
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    if body.contains("Bad login") || body.contains("Unknown") {
                        self.errorMessage = "Invalid username or password"
                    } else if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                        // Some HN login flows redirect without explicit cookie in headers
                        // Try to get cookies from the shared storage
                        if let cookies = config.httpCookieStorage?.cookies(for: URL(string: self.baseURL)!) {
                            let userCookie = cookies.first(where: { $0.name == "user" })
                            if let userCookie = userCookie {
                                self.sessionCookies = cookies
                                self.username = username
                                self.isLoggedIn = true
                                self.saveSession(cookie: userCookie.value, username: username)
                                return
                            }
                        }
                        self.errorMessage = "Login failed. Please check your credentials."
                    } else {
                        self.errorMessage = "Login failed (status \(httpResponse.statusCode))"
                    }
                } else {
                    self.errorMessage = "Login failed. Please try again."
                }
            }
        }.resume()
    }

    // MARK: - Comment Submission

    func submitComment(parentId: Int, text: String, completion: @escaping (Bool, String?) -> Void) {
        guard isLoggedIn else {
            completion(false, "Not logged in")
            return
        }

        // Step 1: Fetch the item page to get the HMAC token
        fetchHMAC(for: parentId) { [weak self] hmac in
            guard let self = self, let hmac = hmac else {
                DispatchQueue.main.async {
                    completion(false, "Could not retrieve form token. Try again.")
                }
                return
            }

            // Step 2: POST the comment
            self.postComment(parentId: parentId, text: text, hmac: hmac, completion: completion)
        }
    }

    func upvote(itemID: Int, completion: @escaping (Bool, String?) -> Void) {
        guard isLoggedIn else {
            completion(false, "Not logged in")
            return
        }

        fetchVoteAuth(for: itemID) { [weak self] auth in
            guard let self, let auth else {
                DispatchQueue.main.async {
                    completion(false, "Could not retrieve vote token. Try again.")
                }
                return
            }
            self.postVote(itemID: itemID, auth: auth, completion: completion)
        }
    }

    func upvote(itemID: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            upvote(itemID: itemID) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HNError.transport(error ?? "Failed to upvote."))
                }
            }
        }
    }

    private func fetchHMAC(for itemId: Int, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/item?id=\(itemId)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        applyCookies(to: &request)

        session.dataTask(with: request) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }

            // Extract hmac from: <input type="hidden" name="hmac" value="...">
            if let range = html.range(of: "name=\"hmac\" value=\"") {
                let start = range.upperBound
                if let end = html[start...].range(of: "\"") {
                    let hmac = String(html[start..<end.lowerBound])
                    completion(hmac)
                    return
                }
            }

            completion(nil)
        }.resume()
    }

    private func fetchVoteAuth(for itemID: Int, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/item?id=\(itemID)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        applyCookies(to: &request)

        session.dataTask(with: request) { data, _, _ in
            guard let data, let html = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(Self.extractVoteAuth(from: html, itemID: itemID))
        }.resume()
    }

    private func postVote(itemID: Int, auth: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = Self.voteURL(itemID: itemID, auth: auth) else {
            completion(false, "Invalid vote URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCookies(to: &request)

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response")
                    return
                }
                guard (200..<400).contains(httpResponse.statusCode) else {
                    completion(false, "Failed to upvote (status \(httpResponse.statusCode))")
                    return
                }
                if let data, let body = String(data: data, encoding: .utf8),
                   body.contains("Unknown or expired link") {
                    completion(false, "Session expired. Please try again.")
                    return
                }
                completion(true, nil)
            }
        }.resume()
    }

    static func extractVoteAuth(from html: String, itemID: Int) -> String? {
        let escapedID = NSRegularExpression.escapedPattern(for: String(itemID))
        let patterns = [
            #"href=["'][^"']*(?:\?|&amp;|&)id=\#(escapedID)(?:&amp;|&)how=up(?:&amp;|&)auth=([^"'&]+)"#,
            #"id=\#(escapedID)(?:&amp;|&)how=up(?:&amp;|&)auth=([^"'&]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  let tokenRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            let token = String(html[tokenRange])
            return token.removingPercentEncoding ?? token
        }
        return nil
    }

    static func voteURL(itemID: Int, auth: String, baseURL: String = "https://news.ycombinator.com") -> URL? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let encodedAuth = auth.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "\(baseURL)/vote?id=\(itemID)&how=up&auth=\(encodedAuth)")
    }

    private func postComment(parentId: Int, text: String, hmac: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/comment") else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyCookies(to: &request)

        let body = "parent=\(parentId)&goto=item%3Fid%3D\(parentId)&hmac=\(urlEncode(hmac))&text=\(urlEncode(text))"
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response")
                    return
                }

                // HN redirects on success (302) or returns 200 with the item page
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        if body.contains("Unknown or expired link") {
                            completion(false, "Session expired. Please try again.")
                            return
                        }
                    }
                    completion(true, nil)
                } else {
                    completion(false, "Failed to post comment (status \(httpResponse.statusCode))")
                }
            }
        }.resume()
    }

    // MARK: - Cookie Management

    private func applyCookies(to request: inout URLRequest) {
        if let storedCookie = loadCookieFromKeychain() {
            request.setValue("user=\(storedCookie)", forHTTPHeaderField: "Cookie")
        } else if !sessionCookies.isEmpty {
            let cookieHeader = sessionCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
    }

    // MARK: - Keychain Storage

    private func saveSession(cookie: String, username: String) {
        let data = "\(username)|\(cookie)".data(using: .utf8)!

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecValueData as String: data,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadCookieFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let stored = String(data: data, encoding: .utf8) else {
            return nil
        }

        let parts = stored.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return String(parts[1])
    }

    private func restoreSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "session",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data,
              let stored = String(data: data, encoding: .utf8) else {
            return
        }

        let parts = stored.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }

        username = String(parts[0])
        isLoggedIn = true
    }

    func logout() {
        isLoggedIn = false
        username = ""
        sessionCookies = []
        errorMessage = nil

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Helpers

    private func urlEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
