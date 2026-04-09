// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sshhh",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "sshhh", targets: ["sshhh"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", revision: "5d9176eb35bcbe009c7b26202f0e92c85ff2dedf")
    ],
    targets: [
        .executableTarget(
            name: "sshhh",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "sshhhTests",
            dependencies: ["sshhh"],
            path: "Tests"
        ),
        .executableTarget(
            name: "IntegrationTests",
            dependencies: [],
            path: "IntegrationTests"
        )
    ]
)
