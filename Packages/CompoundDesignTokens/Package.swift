// swift-tools-version: 6.0
// Vendored from compound-design-tokens v11.0.0 without the UIKit-only colour files.
import PackageDescription

let package = Package(
    name: "CompoundDesignTokens",
    platforms: [.watchOS(.v11)],
    products: [
        .library(name: "CompoundDesignTokens", targets: ["CompoundDesignTokens"])
    ],
    targets: [
        .target(name: "CompoundDesignTokens",
                resources: [.process("Colors.xcassets"), .process("Icons.xcassets")])
    ]
)
