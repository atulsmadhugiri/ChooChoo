// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChooChooTests",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .testTarget(
            name: "EncodingUtilsTests",
            dependencies: [
                .product(name: "ChooChooCore", package: "ChooChoo")
            ],
            path: "EncodingUtilsTests"
        )
    ]
)
