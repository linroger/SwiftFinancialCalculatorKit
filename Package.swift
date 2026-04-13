// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FinancialCalculatorKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "FinancialCalculatorKit",
            targets: ["FinancialCalculatorKit"]),
    ],
    dependencies: [
        // LaTeX rendering for mathematical formulas
        .package(url: "https://github.com/colinc86/LaTeXSwiftUI", from: "1.5.0"),
        
        // Advanced mathematical types and functions
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        
        // Mathematical expression parser
        .package(url: "https://github.com/bradhowes/swift-math-parser", from: "3.7.3")
    ],
    targets: [
        .executableTarget(
            name: "FinancialCalculatorKit",
            dependencies: [
                "LaTeXSwiftUI",
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "RealModule", package: "swift-numerics"),
                .product(name: "ComplexModule", package: "swift-numerics"),
                .product(name: "MathParser", package: "swift-math-parser")
            ],
            path: "FinancialCalculatorKit"),
        .testTarget(
            name: "FinancialCalculatorKitTests",
            dependencies: ["FinancialCalculatorKit"],
            path: "FinancialCalculatorKitTests"),
    ]
)