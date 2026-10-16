import XCTest
@testable import Melodissimo

/// Answers every request from a closure, so no test touches the network.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        do {
            guard let handler = Self.handler else { throw URLError(.notConnectedToInternet) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func reset() {
        handler = nil
        requests = []
    }
}

/// Loads a file from `MelodissimoTests/Fixtures` (copies of the backend repo's `contracts/examples`).
func fixtureData(_ name: String, ext: String = "json") throws -> Data {
    let bundle = Bundle(for: APIClientTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: ext) ?? Bundle.main.url(forResource: name, withExtension: ext),
                            "missing fixture \(name).\(ext)")
    return try Data(contentsOf: url)
}

final class APIClientTests: XCTestCase {

    private let base = URL(string: "https://api.test")!
    private let headers = ClientHeaders(version: "3.4.0", build: 57, installId: "6F1C", contentVersion: 12, schemaVersion: 1,
                                        languages: ["id-ID", "en"], storefront: "IDN")

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func client(headers: ClientHeaders? = nil) -> APIClient {
        APIClient(baseURL: base, session: StubURLProtocol.session(), headers: { headers ?? self.headers })
    }

    private struct Ping: Decodable { let ok: Bool; let at: Date? }

    func testEveryRequestCarriesTheStandardHeaders() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true}"#.utf8)) }
        let result: Ping = try await client().get("v1/bootstrap")
        XCTAssertTrue(result.ok)
        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.test/v1/bootstrap")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Platform"), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Version"), "3.4.0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-App-Build"), "57")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Install-Id"), "6F1C")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Content-Version"), "12")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Schema-Version"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "id-ID, en")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Storefront"), "IDN")
        XCTAssertEqual(request.timeoutInterval, 8)
    }

    func testAnUnknownStorefrontAndNoLanguagesSendNoHeader() {
        var h = headers
        h.storefront = ""
        h.languages = []
        XCTAssertNil(h.fields["X-Storefront"])
        XCTAssertNil(h.fields["Accept-Language"])
        XCTAssertEqual(h.fields.count, 6)
    }

    func testANon2xxAnswerIsATypedErrorWithTheServersCode() async throws {
        StubURLProtocol.handler = { _ in (503, Data(#"{"error": {"code": "not_ready", "message": "Live config has not been published yet"}}"#.utf8)) }
        do {
            let _: Ping = try await client().get("v1/bootstrap")
            XCTFail("should throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .http(status: 503, code: "not_ready", message: "Live config has not been published yet"))
        }
    }

    func testAnErrorWithoutTheJSONEnvelopeStillHasItsStatus() async throws {
        StubURLProtocol.handler = { _ in (502, Data("<html>bad gateway</html>".utf8)) }
        do {
            let _: Ping = try await client().get("x")
            XCTFail("should throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .http(status: 502, code: nil, message: nil))
        }
    }

    func testTransportAndDecodingFailuresAreTyped() async throws {
        do {
            let _: Ping = try await client().get("x")   // no handler: the stub fails the request
            XCTFail("should throw")
        } catch let error as APIError {
            guard case .transport = error else { return XCTFail("expected transport, got \(error)") }
        }
        StubURLProtocol.handler = { _ in (200, Data("[]".utf8)) }
        do {
            let _: Ping = try await client().get("x")
            XCTFail("should throw")
        } catch let error as APIError {
            guard case .decoding = error else { return XCTFail("expected decoding, got \(error)") }
        }
    }

    func testWithoutAnAddressNothingIsSent() async throws {
        let offline = APIClient(baseURL: nil, session: StubURLProtocol.session(), headers: { self.headers })
        do {
            let _: Ping = try await offline.get("x")
            XCTFail("should throw")
        } catch let error as APIError {
            XCTAssertEqual(error, .notConfigured)
        }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testDatesDecodeWithAndWithoutFractionalSeconds() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true, "at": "2026-10-15T08:00:00Z"}"#.utf8)) }
        let plain: Ping = try await client().get("x")
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true, "at": "2026-10-15T08:00:00.123Z"}"#.utf8)) }
        let fractional: Ping = try await client().get("x")
        XCTAssertEqual(plain.at, ISO8601DateFormatter().date(from: "2026-10-15T08:00:00Z"))
        XCTAssertNotNil(fractional.at)
    }

    func testPostSendsJSON() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"ok": true}"#.utf8)) }
        let _: Ping = try await client().post("v1/events", body: ["name": "app_open"])
        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: Environment and install id

    func testBaseURLsAreParsedAndPlaceholdersAreNeverContacted() throws {
        XCTAssertEqual(BackendEnvironment.parseBaseURL("https://api.melodissimo.app")?.host, "api.melodissimo.app")
        XCTAssertNil(BackendEnvironment.parseBaseURL("$(MELODISSIMO_API_BASE)"))
        XCTAssertNil(BackendEnvironment.parseBaseURL(""))
        XCTAssertNil(BackendEnvironment.parseBaseURL("ftp://x.test"))
        XCTAssertNil(BackendEnvironment.parseBaseURL(nil))
        XCTAssertTrue(BackendEnvironment.isPlaceholder(try XCTUnwrap(URL(string: "https://api.example.invalid"))))
        XCTAssertFalse(BackendEnvironment.isPlaceholder(try XCTUnwrap(URL(string: "https://api.melodissimo.app"))))
    }

    func testTheInstallIdIsCreatedOnceAndKept() {
        let suite = "InstallID-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = InstallID.current(defaults: defaults)
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(InstallID.current(defaults: defaults), first)
        defaults.set("not-a-uuid", forKey: InstallID.key)
        XCTAssertNotEqual(InstallID.current(defaults: defaults), "not-a-uuid")
    }

    func testTheCurrentHeadersReadTheBundle() {
        let suite = "Headers-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let h = ClientHeaders.current(contentVersion: 4, defaults: defaults, languages: ["id"])
        XCTAssertEqual(h.platform, "ios")
        XCTAssertEqual(h.contentVersion, 4)
        XCTAssertEqual(h.schemaVersion, ClientHeaders.supportedSchemaVersion)
        XCTAssertGreaterThanOrEqual(h.build, 0)
        XCTAssertEqual(h.installId, InstallID.current(defaults: defaults))
    }

    func testTheBootstrapExampleFixtureIsReadable() throws {
        struct Minimal: Decodable { let ttlSeconds: Int; let serverTime: Date }
        let value = try APIClient.makeDecoder().decode(Minimal.self, from: fixtureData("bootstrap"))
        XCTAssertEqual(value.ttlSeconds, 900)
    }
}
