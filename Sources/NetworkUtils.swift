import Foundation

enum RealTimeFeedEndpoints: String {
  case l = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l"
}

struct NetworkUtils {
  static func sendNetworkRequest(to endpoint: RealTimeFeedEndpoints) async throws -> Data {
    var request = URLRequest(url: URL(string: endpoint.rawValue)!)
    request.httpMethod = "GET"
    request.addValue(Secrets.ACCESS_KEY, forHTTPHeaderField: "x-api-key")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
    return data
  }
}
