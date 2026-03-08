// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NetAppsPaySDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "NetAppsPaySDK",
            targets: ["NetAppsPaySDK"]
        ),
    ],
    targets: [
        .target(
            name: "NetAppsPaySDK"
        ),
        .testTarget(
            name: "NetAppsPaySDKTests",
            dependencies: ["NetAppsPaySDK"]
        ),
    ]
)
