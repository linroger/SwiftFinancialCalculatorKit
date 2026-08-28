# Changelog

All notable changes to FinancialCalculatorKit will be documented in this file.

## [0.6.0] - 2026-08-28

### Added
- **Debt Payoff Planner**, a new calculator: enter several debts and compare avalanche (highest rate first), snowball (smallest balance first), and minimums-only side by side. Every strategy spends the same monthly budget — minimums plus your extra — and rolls each cleared minimum into the next target, so the comparison is honest. Reports months to debt-free, total interest, payoff order with per-debt interest, and a chart of all three balance curves converging on zero. Refuses to pretend when a budget cannot outpace the accruing interest, and says how much more per month is needed.
- Saved debt plans persist through SwiftData (debts stored as JSON, no value transformer needed) and appear in the sidebar, dashboard statistics, and recent activity like every other calculation
- 9 tests for the payoff engine, including a conservation check that total paid equals principal plus accrued interest for every strategy

## [0.5.0] - 2026-08-28

### Added
- **Refinance analyzer** in the Loan Calculator: compares the loan on screen against a new offer. A slider for "payments already made" derives today's balance and remaining term from the existing loan, so nothing has to be re-entered. Reports the payment comparison, break-even month on closing costs with a cumulative-position chart showing the crossover, and lifetime cost — the two are kept separate because a lower payment over a longer term routinely costs more overall, and the analyzer says so plainly when that happens. Also models keeping your current payment on the new loan, which directs the whole rate cut at principal.
- 7 tests for the refinance math, including a closed-form-vs-iterative amortization cross-check and the term-extension case where the payment falls while lifetime cost rises

## [0.4.0] - 2026-08-28

### Added
- **Monte Carlo retirement analysis**: simulates up to 10,000 market paths to report the probability a plan actually funds its income for life, a percentile fan chart of balances over time, the pessimistic/median/optimistic ending balance, the median age money runs out on failed paths, and the income level the plan sustains at 90% confidence. This captures sequence-of-returns risk, which a single deterministic projection cannot show. Runs off the main thread with a real progress indicator, and is reproducible — a seeded generator means the same plan always yields the same numbers.
- **Return volatility** input in the Retirement Planner, feeding the simulation
- **Menu-bar commands**: a Calculators menu with ⌘0 for the dashboard, ⌘1–⌘9 to jump to each calculator, ⌘⇧F to filter favorites, plus ⌘N and ⌘⇧/ — the keyboard shortcuts the help screen documents are now real
- 7 tests covering the simulation: seeded determinism, agreement with the deterministic projection at zero volatility, the direction volatility pushes confidence in both a funded and an unfundable plan, percentile interpolation, band ordering, and the sampler's distribution (mean/variance within 0.05 over 20k draws)

### Notes
- Cross-checked the simulation against an independent reference implementation: both put this baseline plan's deterministic break-even at ~5,930/month and agree on success rates across volatility levels

## [0.3.0] - 2026-08-28

### Added
- **Retirement Planner**: accumulation projection, growing-annuity required nest egg, sustainable income in today's dollars, additional-savings-needed gap analysis, depletion-age simulation, and a balance-over-time chart — wired into navigation, persistence, sidebar recents, dashboard, help, and README
- Loan balance-over-time chart rendered from the real amortization schedule
- CSV export for Time Value and Options calculators (every calculator can now export)
- Default payment frequency is now settable in Preferences
- Regression tests: retirement math (closed-form vs brute-force), temperature fixed points, CSV escaping, SwiftData round-trip — 36 tests total

### Fixed
- Amortization table crashed when searching while on page 2+ of a long schedule
- Loan Term and Number of Years fields fought the user while typing ("30" snapped to "3.0")
- Leftover artificial calculation delays could resurrect stale results after inputs changed; all calculations are now synchronous and every input edit invalidates the displayed result
- Down payment silently carried into standard-loan math after switching from Mortgage
- Bond "No solution" results no longer enable analytics computed at a fabricated 0% yield, and insights no longer describe a YTM that does not exist
- IRR now finds roots of non-conventional cash flows (interior bracket scan); "No IRR found" is no longer treated as a real 0% IRR by the insights
- TVM analytics no longer silently truncate horizons beyond 1200 periods — the full plan is simulated and the chart is down-sampled instead
- Extreme numeric inputs can no longer trap Int conversions (input caps: years ≤ 1000, loan term ≤ 100)
- Currency converter: switching the base currency can no longer show or save the old base's rate relabeled as the new pair (in-flight fetches are cancelled and stale responses discarded); the view starts in an honest "rate unavailable" state instead of a fabricated 1.0; amounts use per-currency formatting (no phantom yen decimals)
- Currency pickers in every calculator show all 16 currencies, so a saved default like KRW can no longer render a blank selection
- MACRS reports the full cost basis as the depreciable base (salvage is ignored by convention) and salvage is clamped strictly below asset cost
- Payback period now also appears in combined NPV & IRR mode; the sensitivity sheet computes the real NPV instead of relabeling an IRR percentage as dollars
- Duration/convexity include the fractional trailing coupon; VaR returns the conventional positive loss
- Duplicate field labels and doubled help icons removed; icon-only toolbar menus have tooltips and accessibility labels; unit-category picker no longer truncates

### Changed
- Preferences panel now contains only settings that actually do something; decimal-places and thousands-separator preferences are honored by all currency formatting
- Removed dead spinner states, unused view-model fields, and the unused LoadingResultView/ExportFormat code

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