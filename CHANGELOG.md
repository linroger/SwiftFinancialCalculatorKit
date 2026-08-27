# Changelog

All notable changes to FinancialCalculatorKit will be documented in this file.

## [0.2.0] - 2026-08-28

### Fixed
- Black-Scholes normal CDF was missing the `/√2` term, inflating every option price and Greek by ~28%; now verified against the textbook 10.4506 ATM reference value
- Loan payments were computed at 100× the periodic rate; a $300k / 6% / 30-year mortgage now correctly yields $1,798.65/month with a consistent amortization schedule
- TVM solvers rebuilt on the consistent goal convention `FV = PV(1+r)^n + PMT·s`: rate solving uses bracketed bisection (returns "No solution" instead of a fake answer), solving for N no longer ignores the future value, and 0%-rate cases use closed forms
- Solved interest rates are now annualized instead of silently returning a per-period rate labeled "annual"
- Crash fixes: `1...0` ranges on short bond maturities and fractional depreciation lives, division by zero in zero-rate bond pricing, NaN pie-chart percentages, empty cash-flow averages
- IRR and bond YTM validate their brackets and report no-solution instead of returning meaningless midpoints; payback period off-by-one corrected
- Math-expression variables are now actually passed to the parser; evaluation failures show an error instead of "NaN"
- Temperature conversion was an identity function (100°C → "100°F"); now a proper affine conversion, and mi² was added so the km²→mi² quick conversion works
- Currency converter no longer fabricates 1.0 rates for unknown currencies or shows a "Live" badge on fallback data; HTTP responses are validated
- Preferences now genuinely persist across launches (UserDefaults round-trip)
- Sidebar recent-calculation delete and favorite actions now operate on the underlying SwiftData models
- Declining-balance depreciation switches to straight-line so book value reaches salvage; MACRS schedules include the half-year-convention tail and honor the selected rate and property class
- Dashboard statistics include bond, depreciation, and currency calculations; the market overview is labeled as static sample data
- Xcode project file: restored the missing unit-test product reference (which broke `xcodebuild test`) and removed duplicate compile entries

### Added
- Modified IRR (MIRR) calculation, surfaced in investment analysis results
- CSV export via save panel for investment, bond, and depreciation results (previously dead menu items)
- Inverse normal CDF (Acklam) for proper VaR confidence levels
- 22 engine/model regression tests covering options pricing, loans, TVM round-trips, bonds, depreciation, IRR/MIRR, expressions, and preferences persistence

### Changed
- Currency formatters are cached per currency; locale-aware number parsing and separators throughout
- Chart interpolation switched from Catmull-Rom (which overshoots) to monotone; hover highlights exactly one point
- Removed artificial "calculating" delays, preloaded demo data, dead help buttons, and the unused Item.swift template file

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