import Foundation
import Testing
@testable import SayAgainKit

/// Answers URLSession requests from a closure, so the client is tested without a server.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.read)
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Example bodies from `contract/feedback`, shared with the Worker's tests.
enum Contract {
    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "contract/feedback")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appending(path: name))
    }
}

@Suite("Remote feedback service", .serialized)
struct RemoteFeedbackServiceTests {
    let service: RemoteFeedbackService = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return RemoteFeedbackService(endpoint: URL(string: "https://worker.test")!, session: URLSession(configuration: configuration))
    }()

    @Test func postsQuestionAndRetellingAsJSON() async throws {
        StubURLProtocol.handler = { _ in (200, try Contract.data("understood.json")) }
        _ = try await service.check(questionID: "intro-001", retelling: "my background")

        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://worker.test/v1/feedback")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONSerialization.jsonObject(with: try #require(StubURLProtocol.lastBody)) as? [String: String]
        #expect(body == ["questionId": "intro-001", "retelling": "my background"])
    }

    @Test(arguments: [
        ("understood.json", FeedbackVerdict.understood, 0),
        ("partly.json", .partly, 1),
        ("missed.json", .missed, 2)
    ])
    func decodesEveryContractExample(file: String, verdict: FeedbackVerdict, missedCount: Int) async throws {
        StubURLProtocol.handler = { _ in (200, try Contract.data(file)) }
        let feedback = try await service.check(questionID: "intro-001", retelling: "x")
        #expect(feedback.verdict == verdict)
        #expect(feedback.missedPoints.count == missedCount)
        #expect(!feedback.feedback.isEmpty)
    }

    @Test(arguments: [
        (429, #"{"error":"rate_limited"}"#, FeedbackServiceError.rateLimited),
        (503, #"{"error":"busy"}"#, .busy),
        (403, #"{"error":"not_available"}"#, .notAvailable),
        (502, #"{"error":"cannot_check"}"#, .cannotCheck),
        (400, #"{"error":"invalid_request"}"#, .unexpected(status: 400)),
        (500, "Internal Server Error", .unexpected(status: 500))
    ])
    func mapsWorkerErrors(status: Int, body: String, expected: FeedbackServiceError) async {
        StubURLProtocol.handler = { _ in (status, Data(body.utf8)) }
        await #expect(throws: expected) {
            try await service.check(questionID: "intro-001", retelling: "x")
        }
    }

    @Test func networkFailureIsOffline() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: FeedbackServiceError.offline) {
            try await service.check(questionID: "intro-001", retelling: "x")
        }
    }

    @Test func garbageWithStatus200IsCannotCheck() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"verdict":"great"}"#.utf8)) }
        await #expect(throws: FeedbackServiceError.cannotCheck) {
            try await service.check(questionID: "intro-001", retelling: "x")
        }
    }
}

@Suite("Retelling rules")
struct RetellingTests {
    @Test func trimsWhitespace() {
        #expect(Retelling.prepared("  my background \n") == "my background")
    }

    @Test(arguments: ["", "   ", "\n\t"])
    func blankIsNotSent(text: String) {
        #expect(Retelling.prepared(text) == nil)
    }

    @Test func limitMatchesTheWorker() {
        #expect(Retelling.prepared(String(repeating: "a", count: Retelling.maxLength)) != nil)
        #expect(Retelling.prepared(String(repeating: "a", count: Retelling.maxLength + 1)) == nil)
    }

    @Test func kidsCategoryStaysOnDevice() {
        #expect(!Retelling.isAvailable(for: .school))
        for category in QuestionCategory.allCases where category != .school {
            #expect(Retelling.isAvailable(for: category))
        }
    }

    @Test(arguments: [(FeedbackVerdict.understood, Rating.gotIt), (.partly, .partly), (.missed, .missed)])
    func verdictMapsToRating(verdict: FeedbackVerdict, rating: Rating) {
        #expect(verdict.rating == rating)
    }

    @Test func everyErrorHasAMessageWithoutLongDashes() {
        let errors: [FeedbackServiceError] = [.offline, .rateLimited, .busy, .notAvailable, .cannotCheck, .unexpected(status: 500)]
        for error in errors {
            #expect(!error.message.isEmpty)
            #expect(!error.message.contains("\u{2014}") && !error.message.contains("\u{2013}"))
        }
    }
}

@Suite("Practice session with retelling")
struct PracticeRetellTests {
    private func session() -> PracticeSession {
        PracticeSession(questions: QuestionBank.fixture.questions, seed: 1)
    }

    @Test(arguments: [
        (FeedbackVerdict.understood, true, Rating.gotIt),
        (.partly, true, .partly),
        (.missed, false, .missed)
    ])
    func retellRevealsAndSuggestsRating(verdict: FeedbackVerdict, correct: Bool, rating: Rating) throws {
        var session = session()
        let id = try #require(session.current?.id)
        session.retell(verdict: verdict)
        #expect(session.phase == .revealed(choiceCorrect: correct))
        #expect(session.suggestedRating == rating)

        let suggested = try #require(session.suggestedRating)
        let rated = session.rate(suggested)
        let outcome = try #require(rated)
        #expect(outcome == .init(questionID: id, choiceCorrect: correct, rating: rating))
        #expect(session.retellVerdict == nil, "Next question starts without a verdict")
    }

    @Test func retellIsIgnoredOnceRevealed() throws {
        var session = session()
        let gist = try #require(session.current?.gist)
        session.choose(gist)
        session.retell(verdict: .missed)
        #expect(session.phase == .revealed(choiceCorrect: true))
        #expect(session.retellVerdict == nil)
    }

    @Test func choiceStillSuggestsItsOwnRating() throws {
        var session = session()
        let current = try #require(session.current)
        session.choose(current.distractors[0])
        #expect(session.suggestedRating == .missed)
    }
}

@Suite("Scripted feedback service")
struct ScriptedFeedbackServiceTests {
    @Test(arguments: [
        ("missed: about work", FeedbackVerdict.missed),
        ("Partly my background", .partly),
        ("my background and why I came", .understood)
    ])
    func firstWordPicksTheVerdict(text: String, verdict: FeedbackVerdict) async throws {
        let service = ScriptedFeedbackService()
        #expect(try await service.check(questionID: "q", retelling: text).verdict == verdict)
        #expect(service.calls.map(\.retelling) == [text])
    }

    @Test func offlineThrows() async {
        await #expect(throws: FeedbackServiceError.offline) {
            try await ScriptedFeedbackService().check(questionID: "q", retelling: "offline please")
        }
    }
}
