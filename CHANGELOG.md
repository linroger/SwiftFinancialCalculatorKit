# Changelog

All notable changes to FinancialCalculatorKit will be documented in this file.

## [Unreleased]

### Added
- Project architecture documentation and comprehensive README
- Core financial calculation models (FinancialCalculation, TimeValueCalculation, LoanCalculation)
- Comprehensive financial calculation engine with TVM, loan, bond, and investment calculations
- Native macOS interface with NavigationSplitView and sidebar navigation
- User preferences system with currency, formatting, and UI options
- Built-in help system with comprehensive documentation
- Error handling and validation framework
- SwiftData persistence layer with proper enum handling

### Changed
- Replaced default SwiftData template with financial calculator architecture
- Implemented protocol-based design for calculation models to work with SwiftData
- Created modern macOS UI following Apple Human Interface Guidelines

### Removed
- Default SwiftData template Item model

### Technical Achievements
- Successfully integrated SwiftData with custom financial models
- Implemented comprehensive financial mathematics engine
- Created modular, maintainable architecture with MVVM pattern
- Built foundation for charts, data import/export, and advanced features

## [0.1.0] - 2025-06-08

### Added
- Initial Xcode project creation
- Basic SwiftData template structure
- Project configuration for macOS target

### Technical Notes
- Using SwiftUI for native macOS interface
- SwiftData for local data persistence
- Prepared for SwiftCharts integration
- Target: macOS 15.0+, Swift 6.0+