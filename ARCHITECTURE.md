# FinancialCalculatorKit Architecture

## Overview

FinancialCalculatorKit is a comprehensive native macOS financial calculator application built with SwiftUI and SwiftData. It provides advanced financial calculation capabilities with a modern, intuitive user interface following Apple's Human Interface Guidelines.

## Architecture Pattern

The application follows the **Model-View-ViewModel (MVVM)** pattern with the following key components:

### Models
- **Data Layer**: SwiftData-based persistence with specialized calculation models
- **Business Logic**: Financial calculation engines and algorithms
- **Type Safety**: Strong typing with custom enums and protocols

### Views
- **SwiftUI Components**: Native macOS UI components
- **Custom Styling**: Consistent visual design system
- **Responsive Layout**: Adaptive layouts for different window sizes

### ViewModels
- **State Management**: Observable objects managing application state
- **Data Binding**: Two-way binding between views and data
- **User Interactions**: Handling user input and calculations

## Current Project Structure

```
FinancialCalculatorKit/
├── FinancialCalculatorKitApp.swift      # App entry point
├── ContentView.swift                    # Main app container
├── Models/
│   ├── Calculation/                     # Financial calculation models
│   │   ├── FinancialCalculation.swift   # Base calculation model
│   │   ├── TimeValueCalculation.swift   # TVM calculations
│   │   ├── LoanCalculation.swift        # Loan & mortgage calculations
│   │   ├── BondCalculation.swift        # Bond pricing calculations
│   │   ├── InvestmentCalculation.swift  # Investment analysis
│   │   └── DepreciationCalculation.swift # Asset depreciation
│   └── Enums/                          # Type definitions
│       ├── CalculationType.swift        # Calculation categories
│       ├── Currency.swift              # Currency support
│       └── PaymentFrequency.swift      # Payment timing
├── Services/
│   └── CalculationEngine.swift         # Core calculation algorithms
├── ViewModels/
│   └── MainViewModel.swift             # Application state management
├── Views/
│   ├── Calculator/                     # Calculator interfaces
│   │   ├── TimeValueCalculatorView.swift
│   │   ├── LoanCalculatorView.swift
│   │   ├── BondCalculatorView.swift
│   │   ├── InvestmentCalculatorView.swift
│   │   ├── DepreciationCalculatorView.swift
│   │   ├── CurrencyConverterView.swift
│   │   └── UnitConverterView.swift
│   ├── Charts/                         # Data visualization
│   │   └── FinancialChartView.swift    # Interactive charts
│   └── Components/                     # Reusable UI components
│       ├── InputFieldView.swift        # Form input components
│       ├── ResultDisplayView.swift     # Result presentation
│       └── FinancialStyles.swift       # Custom styles
└── Utilities/
    ├── Extensions/                     # Swift extensions
    │   ├── Date+Financial.swift        # Date calculations
    │   └── Double+Financial.swift      # Number operations
    └── Formatters.swift                # Number & date formatting
```

## Key Design Principles

### 1. Separation of Concerns
- **Models**: Pure data and business logic
- **Views**: UI presentation only
- **ViewModels**: State management and data transformation

### 2. Protocol-Oriented Programming
- `FinancialCalculationProtocol`: Common interface for all calculations
- Generic algorithms that work across calculation types
- Extensible design for new calculation types

### 3. Type Safety
- Strong enums for all categorical data
- Currency-aware calculations
- Validation at the type level

### 4. Performance Optimization
- Lazy loading of complex calculations
- Efficient data structures
- Minimal recomputation through proper state management

## Data Flow

```
User Input → View → ViewModel → Model → Calculation Engine → Result → ViewModel → View
```

1. **User Input**: Form fields capture user parameters
2. **View Binding**: SwiftUI bindings update ViewModel state
3. **Validation**: Input validation before calculation
4. **Calculation**: Core algorithms process the data
5. **Result Processing**: Results formatted for display
6. **UI Update**: Views automatically update via @Observable

## Current Calculator Types

### 1. Time Value of Money
- Present Value (PV) calculations
- Future Value (FV) calculations
- Payment (PMT) calculations
- Interest rate solving
- Number of periods calculation

### 2. Loan & Mortgage Analysis
- Monthly payment calculation
- Amortization schedules
- Total interest calculations
- Extra payment scenarios
- Refinancing analysis

### 3. Bond Pricing & Analysis
- Bond pricing calculations
- Yield to maturity (YTM)
- Duration and convexity
- Accrued interest
- Credit spread analysis

### 4. Investment Analysis
- Net Present Value (NPV)
- Internal Rate of Return (IRR)
- Modified IRR (MIRR)
- Payback period
- Profitability index

### 5. Depreciation
- Straight-line depreciation
- Declining balance method
- Sum-of-years digits
- MACRS (US tax depreciation)

### 6. Currency & Unit Conversion
- Real-time exchange rates
- Multi-currency support
- International unit conversions
- Historical rate tracking

## Technology Stack

### Core Framework
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Native data persistence
- **Swift Charts**: Interactive data visualization
- **Combine**: Reactive programming (where needed)

### External Dependencies
- **LaTeXSwiftUI**: Mathematical formula rendering
- **swift-numerics**: High-precision mathematical types
- **swift-math-parser**: Expression parsing and evaluation
- **Expression**: Lightweight formula evaluation

### Development Tools
- **Xcode 16+**: Primary development environment
- **Swift 6**: Modern Swift features
- **macOS 15+**: Target platform

## Planned Enhancements

### Phase 1: Core Improvements (Immediate)
- [x] Enhanced mathematical precision using swift-numerics
- [x] LaTeX formula display for educational content
- [x] Custom expression parsing for user-defined formulas
- [ ] Improved error handling and validation
- [ ] Enhanced UI/UX with modern macOS design patterns

### Phase 2: Advanced Features
- [ ] Monte Carlo simulations for risk analysis
- [ ] Options pricing models (Black-Scholes, Binomial)
- [ ] Portfolio optimization algorithms
- [ ] Technical analysis indicators
- [ ] Financial ratio analysis
- [ ] Cash flow modeling tools

### Phase 3: User Experience
- [ ] Dark mode support
- [ ] Accessibility enhancements
- [ ] Keyboard shortcuts
- [ ] Export capabilities (PDF, Excel, CSV)
- [ ] Calculation history and favorites
- [ ] Templates and presets

### Phase 4: Integration
- [ ] Data import from financial platforms
- [ ] API integration for real-time data
- [ ] Plugin architecture for custom calculations
- [ ] Scripting support for automation

## Performance Considerations

### Memory Management
- Lazy loading of calculation results
- Efficient collection operations
- Proper reference counting

### Computation Optimization
- Caching of expensive calculations
- Parallel processing where applicable
- Progressive calculation for large datasets

### UI Responsiveness
- Async calculation operations
- Progressive UI updates
- Smooth animations and transitions

## Testing Strategy

### Unit Tests
- Individual calculation verification
- Edge case handling
- Performance benchmarks

### Integration Tests
- End-to-end calculation workflows
- Data persistence validation
- UI interaction testing

### User Acceptance Tests
- Real-world calculation scenarios
- Professional use case validation
- Accuracy verification against known tools

## Security & Privacy

### Data Protection
- Local-only data storage by default
- Optional cloud sync with user consent
- No sensitive data transmission without encryption

### Input Validation
- Comprehensive input sanitization
- Range checking for all parameters
- Protection against calculation overflow

---

*Last Updated: June 9, 2025*
*Version: 1.0.0*