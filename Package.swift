// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tics",
    platforms: [.macOS(.v14)],
    targets: [
        // Los packs de sonido no van como recursos de SwiftPM: los copia scripts/build-app.sh
        // dentro de Tics.app/Contents/Resources, que es donde los busca la app
        .executableTarget(name: "Tics", path: "Sources/Tics"),
        .testTarget(name: "TicsTests", dependencies: ["Tics"], path: "Tests/TicsTests")
    ]
)
