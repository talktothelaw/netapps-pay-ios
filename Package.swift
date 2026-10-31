// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NetAppsPaySDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "NetAppsPaySDK",
            targets: ["NetAppsPaySDK"]
        ),
    ],
    targets: [
        .target(
            name: "NetAppsPaySDK",
            resources: [
                .copy("Resources/moniflow_logo.png")
            ]
        ),
        .testTarget(
            name: "NetAppsPaySDKTests",
            dependencies: ["NetAppsPaySDK"]
        ),
    ]
)
