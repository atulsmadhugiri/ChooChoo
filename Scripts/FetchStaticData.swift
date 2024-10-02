import Foundation
import TabularData

func downloadZIP(from url: URL, to destination: URL) async throws {
  let (data, _) = try await URLSession.shared.data(from: url)
  try data.write(to: destination)
}

func unzipFile(at zipURL: URL, to destinationURL: URL) throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
  process.arguments = [zipURL.path, "-d", destinationURL.path]
  try process.run()
  process.waitUntilExit()
  if process.terminationStatus != 0 {
    throw NSError(
      domain: "UnzipError",
      code: Int(process.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: "Failed to unzip file."]
    )
  }
}

func main() async {
  let zipURLString =
    "http://web.mta.info/developers/files/google_transit_supplemented.zip"

  guard let zipURL = URL(string: zipURLString) else {
    print("Error: Invalid ZIP URL.")
    return
  }

  let fileManager = FileManager.default
  let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

  let zipFileURL = currentDir.appendingPathComponent(
    "google_transit_supplemented.zip")

  let tripsFileURL = currentDir.appendingPathComponent("trips.txt")
  let outputFileURL = currentDir.appendingPathComponent("trips_processed.txt")

  do {
    print("Downloading ZIP file...")
    try await downloadZIP(from: zipURL, to: zipFileURL)

    print("Unzipping file...")
    try unzipFile(at: zipFileURL, to: currentDir)

    guard fileManager.fileExists(atPath: tripsFileURL.path) else {
      print("Error: 'trips.txt' not found.")
      return
    }

  } catch {
    print("Error: \(error.localizedDescription)")
  }
}

Task {
  await main()
  exit(EXIT_SUCCESS)
}

RunLoop.main.run()
