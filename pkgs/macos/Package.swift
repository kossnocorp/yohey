// swift-tools-version: 5.9
import PackageDescription

let package = Package(name: "YoheySchedule", targets: [
    .target(name: "YoheySchedule", path: "Sources", exclude: ["Yohey.swift"]),
    .testTarget(name: "YoheyScheduleTests", dependencies: ["YoheySchedule"], path: "Tests"),
])
