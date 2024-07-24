// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "HLSServer",
  platforms: [.iOS(.v17)],
  products: [
    .library(
      name: "HLSServer",
      targets: ["HLSServer"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-nio.git", exact: "2.68.0")
  ],
  targets: [
    .target(
      name: "HLSServer",
      dependencies: [
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOPosix", package: "swift-nio"),
      ]
    ),
    .testTarget(
      name: "HLSServerTests",
      dependencies: ["HLSServer"]
    ),
  ]
)
