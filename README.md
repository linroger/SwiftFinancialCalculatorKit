# FinancialCalculatorKit

A comprehensive, feature-rich financial calculator app for macOS built with SwiftUI and SwiftCharts.

## Features

### Core Financial Calculations
- **Time Value of Money (TVM)**
  - Present Value (PV)
  - Future Value (FV) 
  - Payment (PMT)
  - Interest Rate (I/Y)
  - Number of Periods (N)

- **Advanced Financial Functions**
  - Net Present Value (NPV)
  - Internal Rate of Return (IRR)
  - Modified Internal Rate of Return (MIRR)
  - Bond pricing and yield calculations
  - Depreciation calculations (Straight-line, Declining balance, MACRS)
  - Loan amortization schedules
  - Mortgage calculations

### Data Analysis & Visualization
- **Charts and Graphs** (powered by SwiftCharts)
  - Cash flow timelines
  - Amortization schedules
  - Investment growth projections
  - Bond price sensitivity analysis

- **Data Tables**
  - Sortable calculation results
  - Amortization schedules
  - Payment breakdowns

### Market Data Integration
- **Stock Ticker History**
  - Real-time and historical stock prices
  - Financial metrics and ratios
  - Price charts and analysis

- **Currency & Unit Conversions**
  - Real-time exchange rates
  - Historical currency data
  - Unit conversions for international calculations

### Data Management
- **CSV Import/Export**
  - Import calculation parameters
  - Export results and schedules
  - Batch calculations

- **Calculation History**
  - Save and organize calculations
  - Quick access to previous results
  - Calculation templates

### User Experience
- **Native macOS Design**
  - Follows Apple Human Interface Guidelines
  - Adaptive layout for different window sizes
  - Keyboard shortcuts and accessibility support

- **Help & Education**
  - Comprehensive tooltips and explanations
  - Formula references
  - Example calculations
  - Built-in financial glossary

## Requirements

- macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Architecture

The app follows MVVM architecture with:
- **Models**: Core calculation engines and data models
- **Views**: SwiftUI-based user interface
- **ViewModels**: ObservableObject classes managing state and business logic
- **Services**: Network, data persistence, and calculation services

## Development

### Building
```bash
# Open in Xcode
open FinancialCalculatorKit.xcodeproj

# Or build from command line
xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit build
```

### Testing
```bash
# Run tests
xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit test
```

## License

Copyright © 2025 Roger Lin. All rights reserved.