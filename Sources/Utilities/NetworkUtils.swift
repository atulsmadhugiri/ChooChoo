import Foundation

struct NetworkUtils {
  static func sendNetworkRequest(to endpoint: String) async throws -> Data {
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "GET"

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
    return data
  }
}
