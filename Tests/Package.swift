// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChooChoo",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "EncodingUtils", targets: ["EncodingUtils"])
    ],
    targets: [
        .target(
            name: "EncodingUtils",
            path: "Utilities",
            exclude: [
                "FormatterUtils.swift",
                "LoggingUtils.swift",
                "MTAUtils.swift",
                "NetworkUtils.swift"
            ],
            sources: ["EncodingUtils.swift"]
        ),
        .testTarget(
            name: "EncodingUtilsTests",
            dependencies: ["EncodingUtils"],
            path: "EncodingUtilsTests"
        )
    ]
)
