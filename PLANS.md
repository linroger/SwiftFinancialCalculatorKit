# FinancialCalculatorKit Overhaul Plan

## Objective
Turn FinancialCalculatorKit from a compile-only, partially implemented macOS finance app into a trustworthy, polished desktop product with accurate calculations, honest UI, durable persistence, meaningful tests, refreshed documentation, and at least one new planning workflow.

## Architecture Map

### App Shell
- `FinancialCalculatorKit/FinancialCalculatorKitApp.swift`
  Creates the SwiftData model container, registers custom value transformers, and launches the main window.
- `FinancialCalculatorKit/ContentView.swift`
  Currently acts as the root container, sidebar, detail router, recent history view, preferences UI, help UI, and new-calculation flow all at once.
- `FinancialCalculatorKit/ViewModels/MainViewModel.swift`
  Holds app-wide selection, error state, sheet state, search state, and user preferences, but persistence methods are still placeholders.

### Domain Models
- `FinancialCalculatorKit/Models/Calculation/*.swift`
  Each calculator has a dedicated SwiftData model with a `result`, validation, and supporting enums or transformers.
- `FinancialCalculatorKit/Models/Enums/*.swift`
  Shared enums for calculator routing, currencies, and payment frequencies.

### Shared Logic
- `FinancialCalculatorKit/Services/CalculationEngine.swift`
  Central math engine for TVM, loan, bond, investment, options, and expression evaluation. Some formulas and variable-handling paths need validation.
- `FinancialCalculatorKit/Utilities/*`
  Shared formatters and number/date extensions.

### UI Surfaces
- `FinancialCalculatorKit/Views/DashboardView.swift`
  Marketing-style dashboard with stats, quick actions, mock market overview, calculator grid, and recent activity.
- `FinancialCalculatorKit/Views/Calculator/*.swift`
  Large calculator-specific screens. Several contain placeholder or partially implemented UX.
- `FinancialCalculatorKit/Views/Components/*.swift`
  Reusable financial styling, input fields, and result rendering.
- `FinancialCalculatorKit/Views/Charts/FinancialChartView.swift`
  Shared charting components used by result-heavy calculators.

## Current High-Risk Problems
1. `ContentView.swift` is a monolith and is not a healthy macOS scene boundary.
2. User preferences are not persisted.
3. Recent-calculation deletion is unimplemented.
4. Dashboard labels mock values as “Live Data.”
5. Expression evaluation ignores passed variables.
6. Some calculations appear to use inconsistent percentage/rate conversions.
7. Several UI surfaces still advertise or contain placeholder functionality.
8. Xcode project file has duplicate source entries, producing warning noise.
9. Tests are placeholders and do not validate calculator correctness.
10. Git history is not in a healthy state because `HEAD` is invalid.

## Execution Phases

### Phase 1: Foundation Stabilization
- Create harness and run scripts.
- Clean Xcode project duplication.
- Split the root shell into smaller macOS-native files and make primary navigation stable.
- Make help and dashboard content honest about what is implemented.

### Phase 2: Shared Data and Persistence
- Implement preference persistence.
- Make create/edit/favorite/delete/search/history flows work across stored calculations.
- Normalize recent activity aggregation so dashboard and sidebar agree.

### Phase 3: Calculator Accuracy and UX Audit
- Verify and fix shared financial formulas.
- Remove placeholders and incomplete text.
- Improve validation, chart explanations, and result presentation.

### Phase 4: Product Expansion
- Add at least one new high-value planning workflow, likely retirement or savings planning.
- Ensure the new workflow participates in persistence, docs, and tests.

### Phase 5: Release Readiness
- Add meaningful tests.
- Update README and architecture docs.
- Run serialized smoke checks and final build/test flows.
- Prepare clean Git state for commit and push.

## First Implementation Slice
The first coding slice should be: project hygiene + app shell stabilization.

### Why this slice first
- It reduces blast radius for every later calculator fix.
- It resolves obvious trust issues without deep domain rewrites.
- It creates a stable base for persistence and new features.

### Expected deliverables
- Harness and scripts checked in.
- Duplicate PBX source warnings removed.
- `ContentView.swift` split into smaller files with explicit macOS responsibilities.
- Dashboard/help content aligned with actual capabilities.
- Serialized build/test smoke checks passing.

## Verification Expectations
- `swift build`
- `xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit -destination 'platform=macOS' -derivedDataPath .derivedData build`
- `xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit -destination 'platform=macOS' -derivedDataPath .derivedData test`
- Launch app via `script/build_and_run.sh --verify`
- Manual walkthrough of dashboard, sidebar selection, preferences, help, and at least one calculator
