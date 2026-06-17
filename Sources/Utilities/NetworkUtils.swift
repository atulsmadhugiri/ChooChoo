import Foundation

struct NetworkUtils {
  enum NetworkError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse(URL)
    case badStatus(URL, Int)

    var errorDescription: String? {
      switch self {
      case .invalidURL(let endpoint):
        return "Invalid URL: \(endpoint)"
      case .invalidResponse(let url):
        return "No HTTP response from \(url.absoluteString)"
      case .badStatus(let url, let statusCode):
        return "\(url.absoluteString) returned \(statusCode)"
      }
    }
  }

  static func sendNetworkRequest(to endpoint: String) async throws -> Data {
    guard let url = URL(string: endpoint) else {
      throw NetworkError.invalidURL(endpoint)
    }
    return try await sendNetworkRequest(to: url)
  }

  static func sendNetworkRequest(to url: URL) async throws -> Data {
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 10
    )
    request.networkServiceType = .responsiveData
    request.httpMethod = "GET"
    request.setValue("ChooChoo/1.0", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse(url)
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw NetworkError.badStatus(url, httpResponse.statusCode)
    }
    return data
  }
}
