import Foundation

public final class APIClient {
    private let session: URLSession
    private let builder: RequestBuilder
    private let interceptors: [RequestInterceptable]
    private let decoder: JSONDecoder
    private let unauthorizedHandler: () async throws -> Void

    public init(session: URLSession,
                builder: RequestBuilder,
                interceptors: [RequestInterceptable] = [],
                unauthorizedHandler: @escaping () async throws -> Void) {
        self.session = session
        self.builder = builder
        self.interceptors = interceptors
        self.unauthorizedHandler = unauthorizedHandler
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = DateDecoder.iso8601.date(from: dateString) {
                return date
            }

            if let date = DateDecoder.plain.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Invalid date format: \(dateString)")
        }
    }

    public func send<T: Decodable, Body: Encodable>(_ endpoint: Endpoint,
                                                    body: Body,
                                                    headers: [String: String] = [:],
                                                    responseType: T.Type) async throws -> T {
        try await send(endpoint,
                       body: body,
                       headers: headers,
                       responseType: responseType,
                       hasRetried: false)
    }

    public func send<T: Decodable>(_ endpoint: Endpoint,
                                   headers: [String: String] = [:],
                                   responseType: T.Type) async throws -> T {
        let emptyBody: EmptyBody? = nil
        return try await send(endpoint,
                              body: emptyBody,
                              headers: headers,
                              responseType: responseType,
                              hasRetried: false)
    }

    private func send<T: Decodable, Body: Encodable>(_ endpoint: Endpoint,
                                                      body: Body? = nil,
                                                      headers: [String: String] = [:],
                                                      responseType: T.Type,
                                                      hasRetried: Bool) async throws -> T {
        let request = try await builder.makeRequest(endpoint: endpoint, body: body, headers: headers)

        var preparedRequest = request
        for interceptor in interceptors {
            preparedRequest = await interceptor.willSend(preparedRequest)
        }

        do {
            let (data, response) = try await session.data(for: preparedRequest)
            await notifySuccess(data: data, response: response)
            try await handleCommonErrors(response: response, data: data)
            return try decoder.decode(T.self, from: data)
        } catch APIError.unauthorized where !hasRetried {
            try await unauthorizedHandler()
            return try await send(endpoint,
                                  body: body,
                                  headers: headers,
                                  responseType: responseType,
                                  hasRetried: true)
        } catch {
            await notifyFailure(error: error, request: preparedRequest)
            if let apiError = error as? APIError {
                throw apiError
            }

            if let urlError = error as? URLError {
                throw mapURLError(urlError)
            }
            throw APIError.unknown(error)
        }
    }

    public func sendWithoutDecoding<Body: Encodable>(_ endpoint: Endpoint,
                                                     body: Body,
                                                     headers: [String: String] = [:]) async throws {
        let _: EmptyResponse = try await send(endpoint, body: body, headers: headers, responseType: EmptyResponse.self)
    }

    public func sendWithoutDecoding(_ endpoint: Endpoint,
                                    headers: [String: String] = [:]) async throws {
        let emptyBody: EmptyBody? = nil
        let _: EmptyResponse = try await send(endpoint,
                                              body: emptyBody,
                                              headers: headers,
                                              responseType: EmptyResponse.self,
                                              hasRetried: false)
    }

    private func handleCommonErrors(response: URLResponse, data: Data) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet:
            return .networkUnavailable
        case .timedOut:
            return .timeout
        default:
            return .unknown(error)
        }
    }

    private func notifySuccess(data: Data?, response: URLResponse?) async {
        for interceptor in interceptors {
            await interceptor.didReceive(data, response: response)
        }
    }

    private func notifyFailure(error: Error, request: URLRequest) async {
        for interceptor in interceptors {
            await interceptor.didFail(error, request: request)
        }
    }
}

private struct EmptyResponse: Decodable {}
private struct EmptyBody: Encodable {}

private enum DateDecoder {
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plain: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

