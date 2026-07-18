// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ProjectBarCore", targets: ["ProjectBarCore"]),
        .executable(name: "projectbar-ingest", targets: ["ProjectBarIngest"]),
        .executable(name: "ProjectBar", targets: ["ProjectBar"])
    ],
    targets: [
        .target(
            name: "ProjectBarCore",
            path: "Sources/ProjectBarCore"
        ),
        .executableTarget(
            name: "ProjectBarIngest",
            dependencies: ["ProjectBarCore"],
            path: "Sources/ProjectBarIngest"
        ),
        .executableTarget(
            name: "ProjectBar",
            dependencies: ["ProjectBarCore"],
            path: "Sources/ProjectBar",
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "ProjectBarCoreTests",
            dependencies: ["ProjectBarCore"],
            path: "Tests/ProjectBarCoreTests"
        )
    ]
)
