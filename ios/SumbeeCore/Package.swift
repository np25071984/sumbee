// swift-tools-version: 6.0
import PackageDescription

// The app's logic, free of UIKit and SwiftUI, so `swift test` runs it on the Mac without a simulator.
let package = Package(
    name: "SumbeeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SumbeeCore", targets: ["SumbeeCore"])],
    targets: [
        .target(name: "SumbeeCore"),
        .testTarget(name: "SumbeeCoreTests", dependencies: ["SumbeeCore"]),
    ]
)
