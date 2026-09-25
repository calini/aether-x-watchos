// swift-tools-version:5.9
// Mirrors matrix-rust-components-swift so app code can `import MatrixRustSDK` unchanged.
// The generated bindings require the Swift 5 language mode.
import PackageDescription

let package = Package(
    name: "MatrixRustSDK",
    platforms: [.watchOS("11.0")], // .v11 needs PackageDescription 6.0; this package pins 5.9 for the Swift 5 language mode.
    products: [
        .library(name: "MatrixRustSDK", targets: ["MatrixRustSDK"])
    ],
    targets: [
        .binaryTarget(name: "MatrixSDKFFI", path: "MatrixSDKFFI.xcframework"),
        .target(name: "MatrixRustSDK",
                dependencies: ["MatrixSDKFFI"],
                path: "Sources/MatrixRustSDK",
                linkerSettings: [.linkedLibrary("c++")])
    ]
)
