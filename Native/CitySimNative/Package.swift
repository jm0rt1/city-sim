// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CitySimNative",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CitySimNative", targets: ["CitySimNative"])
    ],
    targets: [
        .executableTarget(
            name: "CitySimNative",
            path: "Sources/CitySimNative"
        ),
        .testTarget(
            name: "CitySimNativeTests",
            dependencies: ["CitySimNative"],
            path: "Tests/CitySimNativeTests"
        )
    ]
)
