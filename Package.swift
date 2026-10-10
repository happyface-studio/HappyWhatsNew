// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HappyWhatsNew",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "HappyWhatsNew",
            targets: ["HappyWhatsNew"]
        ),
    ],
    targets: [
        .target(
            name: "HappyWhatsNew"
        ),
        .testTarget(
            name: "HappyWhatsNewTests",
            dependencies: ["HappyWhatsNew"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
