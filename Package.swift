// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnigmaXOR",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EnigmaXOR", targets: ["EnigmaXOR"]),
    ],
    targets: [
        .executableTarget(
            name: "EnigmaXOR",
            path: "Sources/EnigmaXOR"
        ),
    ]
)
