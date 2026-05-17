import Foundation
import QuartzCore

/// HTTP request/response logging through the shared `Logger`.
final class KBApiLogger: KBApiLoggerBase, @unchecked Sendable {
    func log(request: URLRequest, id: String) {
        let message: String
        if isVerboseLog {
            message = "Request \(id)\n\(request.kbCURL)"
        } else {
            message = "Request \(id) \(shortUrl(request.url))"
        }
        logger.releaseInfo(message)
    }

    func log(response: HTTPURLResponse, data: Data?, id: String, startTime: CFTimeInterval) {
        let duration = String(format: "%.04fs", CACurrentMediaTime() - startTime)
        let baseInfo = "Response \(id) \(response.statusCode) \(duration)"
        let message: String
        if isVerboseLog {
            message = "\(baseInfo)\n\(logMessage(from: response, data: data))"
        } else {
            message = "\(baseInfo) \(shortUrl(response.url))"
        }
        if successStatusCodes.contains(response.statusCode) {
            logger.releaseInfo(message)
        } else {
            logger.releaseError(message)
        }
    }

    func log(error: Error, id: String, response: HTTPURLResponse?) {
        var parts = ["Error \(id)", String(describing: error)]
        if let response {
            parts.append("HTTP \(response.statusCode) \(shortUrl(response.url))")
        }
        logger.releaseError(parts.joined(separator: "\n"))
    }
}
