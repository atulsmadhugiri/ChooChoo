import Foundation

func extractShapeID(from tripID: String) -> String {
  return tripID.components(separatedBy: "_").last ?? ""
}

func processCSV(inputPath: String, outputPath: String) throws {
  let content = try String(contentsOfFile: inputPath, encoding: .utf8)
  var lines = content.components(separatedBy: .newlines)

  guard let header = lines.first else {
    throw NSError(
      domain: "CSVError", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Empty CSV file."])
  }

  let headers = header.split(separator: ",").map { String($0) }

  guard let tripIDIndex = headers.firstIndex(of: "trip_id"),
    let shapeIDIndex = headers.firstIndex(of: "shape_id")
  else {
    throw NSError(
      domain: "CSVError", code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Required headers not found."])
  }

  let processedLines = lines.dropFirst().compactMap { line -> String? in
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    var fields = line.components(separatedBy: ",")

    if fields.count < headers.count {
      fields += Array(repeating: "", count: headers.count - fields.count)
    }

    if fields[shapeIDIndex].isEmpty {
      let tripID = fields[tripIDIndex]
      fields[shapeIDIndex] = extractShapeID(from: tripID)
    }

    return fields.joined(separator: ",")
  }

  let outputContent = ([header] + processedLines).joined(separator: "\n")

  try outputContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
  print("CSV processing complete. Output saved to \(outputPath)")
}

func main() {
  let arguments = CommandLine.arguments
  guard arguments.count == 3 else {
    print("Usage: swift script.swift <input.csv> <output.csv>")
    return
  }

  let inputPath = arguments[1]
  let outputPath = arguments[2]

  do {
    try processCSV(inputPath: inputPath, outputPath: outputPath)
  } catch {
    print("Error: \(error.localizedDescription)")
  }
}

main()
