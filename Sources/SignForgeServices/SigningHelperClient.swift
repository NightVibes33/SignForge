import Foundation

struct SigningHelperClient {
    var baseURL = URL(string: "http://127.0.0.1:8765/")!
    var session: URLSession = .shared

    func exportP12(certificatePEM: String, privateKeyPEM: String, password: String) async throws -> Data {
        let body = HelperP12Request(certificatePEM: certificatePEM, privateKeyPEM: privateKeyPEM, password: password)
        let response: HelperArtifactResponse = try await post("p12", body: body)
        return Data(base64Encoded: response.base64) ?? Data()
    }

    func resignIPA(ipaBase64: String, p12Base64: String, p12Password: String, mobileProvisionBase64: String, entitlementsPlist: String?) async throws -> Data {
        let body = HelperResignRequest(ipaBase64: ipaBase64, p12Base64: p12Base64, p12Password: p12Password, mobileProvisionBase64: mobileProvisionBase64, entitlementsPlist: entitlementsPlist)
        let response: HelperArtifactResponse = try await post("resign", body: body)
        return Data(base64Encoded: response.base64) ?? Data()
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ path: String, body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

struct HelperP12Request: Codable { let certificatePEM: String; let privateKeyPEM: String; let password: String }
struct HelperResignRequest: Codable { let ipaBase64: String; let p12Base64: String; let p12Password: String; let mobileProvisionBase64: String; let entitlementsPlist: String? }
struct HelperArtifactResponse: Codable { let filename: String; let base64: String; let log: String }
