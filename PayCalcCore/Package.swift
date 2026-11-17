// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayCalcCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PayCalcCore", targets: ["PayCalcCore"]),
    ],
    targets: [
        .target(name: "PayCalcCore"),
        .testTarget(name: "PayCalcCoreTests", dependencies: ["PayCalcCore"]),
    ]
)
