// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "JVNetworking",
	platforms: [.macOS(.v14)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "JVNetworking",
			targets: ["JVNetworking"]),
	],
	// Dependencies declare other packages that this package depends on.
	dependencies: [
		.package(url: "https://github.com/TheMisfit68/JVSecurity.git", branch: "main"),
		.package(url: "https://github.com/TheMisfit68/JVScripting.git", branch: "main"),
		.package(url: "https://github.com/TheMisfit68/JVUI.git", branch: "main"),
		.package(url: "https://github.com/TheMisfit68/JVSwiftCore.git", branch: "main"),
		.package(url: "https://github.com/emqx/CocoaMQTT.git", branch: "master"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "JVNetworking",
			dependencies: [
				"JVSecurity",
				"JVScripting",
				"JVUI",
				"JVSwiftCore",
				"CocoaMQTT"],
			swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]
		),
		.testTarget(
			name: "JVNetworkingTests",
			dependencies: ["JVNetworking"]
		)
	]
)
