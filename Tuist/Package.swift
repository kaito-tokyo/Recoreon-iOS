// swift-tools-version: 6.0
import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings

    let packageSettings = PackageSettings(
        productTypes: [:]
    )
#endif

let package = Package(
    name: "Recoreon",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.1"),
        .package(path: "../Packages/HLSServer"),
    ]
)
