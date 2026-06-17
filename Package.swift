// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ChooChoo",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
  ],
  products: [
    .library(name: "ChooChooCore", targets: ["ChooChooCore"]),
    .executable(name: "ChooChooAudit", targets: ["ChooChooAudit"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.29.0")
  ],
  targets: [
    .target(
      name: "ChooChooCore",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf")
      ],
      path: ".",
      exclude: [
        "ChooChoo.xcodeproj",
        "ChooChooLink",
        "Info.plist",
        "LICENSE",
        "Misc",
        "README.md",
        "Resources",
        "Sources/Assets.xcassets",
        "Sources/ChooChooApp.swift",
        "Sources/LocationFetcher.swift",
        "Sources/Models",
        "Sources/Preview Content",
        "Sources/Views",
        "Tests",
        "Tools",
      ],
      sources: [
        "Generated/gtfs-realtime.pb.swift",
        "Generated/gtfs-realtime-service-status.pb.swift",
        "Generated/nyct-subway.pb.swift",
        "Sources/Entities/MTALine.swift",
        "Sources/Entities/MTAServiceAlert.swift",
        "Sources/Entities/MTAStopValue.swift",
        "Sources/Entities/MTATrain.swift",
        "Sources/TrainArrivalEntry.swift",
        "Sources/Utilities/EncodingUtils.swift",
        "Sources/Utilities/MTAUtils.swift",
        "Sources/Utilities/NetworkUtils.swift",
      ]
    ),
    .executableTarget(
      name: "ChooChooAudit",
      dependencies: ["ChooChooCore"],
      path: "Tools/ChooChooAudit"
    ),
    .testTarget(
      name: "ChooChooCoreTests",
      dependencies: ["ChooChooCore"],
      path: "Tests/EncodingUtilsTests"
    ),
  ]
)
