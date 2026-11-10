// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoGo",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "GoGo",
            path: "Sources/GoGo",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
