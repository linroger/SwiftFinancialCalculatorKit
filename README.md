# FinancialCalculatorKit

**English** | [中文](#中文)

A comprehensive, feature-rich financial calculator app for macOS built with SwiftUI and SwiftData. Perform advanced financial calculations including time value of money, loans, bonds, investments, depreciation, and currency conversion with intuitive visualizations and professional-grade accuracy.

![FinancialCalculatorKit Main Interface](FinancialCalculatorKit%202026-04-14%20at%2015.43.15@2x.png)

---

## Features

### Core Financial Calculators

| Calculator | Capabilities |
|------------|-------------|
| **Time Value of Money (TVM)** | Present Value (PV), Future Value (FV), Payment (PMT), Interest Rate (I/Y), Number of Periods (N), Annuity calculations |
| **Loan Calculator** | Monthly payment, amortization schedules, total interest, extra payment scenarios, refinancing analysis |
| **Mortgage Calculator** | Home loan analysis, down payment scenarios, PMI calculation, payment schedules |
| **Bond Calculator** | Bond pricing, Yield to Maturity (YTM), duration, convexity, sensitivity analysis, cash flow schedules |
| **Investment Analysis** | Net Present Value (NPV), Internal Rate of Return (IRR), Modified IRR (MIRR), payback period, profitability index |
| **Options Calculator** | Black-Scholes pricing, Greeks analysis (Delta, Gamma, Theta, Vega), risk assessment |
| **Depreciation Calculator** | Straight-line, Declining Balance, Sum-of-Years Digits, MACRS methods |
| **Currency Converter** | Real-time exchange rates, multi-currency support, historical rate tracking |
| **Unit Converter** | International unit conversions for financial calculations |
| **Math Expression Evaluator** | Custom formula parsing with financial functions and variables |

### Data Visualization

- **Interactive Charts** powered by SwiftCharts
  - Cash flow timelines
  - Amortization schedules
  - Investment growth projections
  - Bond price sensitivity curves
  - NPV/IRR sensitivity analysis

- **Data Tables**
  - Sortable calculation results
  - Paginated amortization schedules
  - Searchable payment breakdowns

![Amortization Schedule](CleanShot%202025-06-10%20at%2001.59.41@2x.png)

### Professional Tools

- **Formula References** — LaTeX-rendered mathematical formulas with variable definitions
- **Sensitivity Analysis** — Interactive charts showing how results change with varying inputs
- **Scenario Analysis** — Best/worst/base case comparisons for investment decisions
- **Loan Insights** — Contextual tips and recommendations based on your inputs
- **Calculation History** — Save, organize, and retrieve previous calculations with SwiftData

### User Experience

- **Native macOS Design** — Follows Apple Human Interface Guidelines
- **Adaptive Layout** — Responsive design for different window sizes
- **Multi-Currency Support** — 8+ major currencies with real-time formatting
- **Accessibility** — Full keyboard navigation and VoiceOver support

---

## Screenshots

### Time Value of Money Calculator
![TVM Calculator](CleanShot%202025-06-10%20at%2001.58.48@2x.png)

### Bond Calculator with Sensitivity Analysis
![Bond Calculator](CleanShot%202025-06-10%20at%2002.00.11@2x.png)

---

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 15.0+ |
| Xcode | 16.0+ |
| Swift | 6.0+ |

---

## Architecture

The app follows **MVVM (Model-View-ViewModel)** architecture with:

- **Models**: SwiftData-based persistence with specialized calculation engines
- **Views**: Native SwiftUI components with custom styling
- **ViewModels**: ObservableObject classes managing state and business logic
- **Services**: Network, data persistence, and calculation services

### Project Structure

```
FinancialCalculatorKit/
├── Models/
│   ├── Calculation/           # Financial calculation models
│   │   ├── TimeValueCalculation.swift
│   │   ├── LoanCalculation.swift
│   │   ├── BondCalculation.swift
│   │   ├── InvestmentCalculation.swift
│   │   ├── DepreciationCalculation.swift
│   │   ├── OptionsCalculation.swift
│   │   └── CurrencyConversionCalculation.swift
│   └── Enums/                # Type definitions
├── Views/
│   ├── Calculator/           # Calculator interfaces
│   ├── Charts/               # Data visualization
│   └── Components/           # Reusable UI components
├── Utilities/
│   └── Extensions/           # Swift extensions
└── FinancialCalculatorKitApp.swift
```

---

## Building & Running

### Using Xcode

```bash
# Open in Xcode
open FinancialCalculatorKit.xcodeproj

# Build
xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit build
```

### Using Swift Package Manager

```bash
# Build from command line
swift build
```

---

## Dependencies

| Package | Purpose |
|---------|---------|
| [LaTeXSwiftUI](https://github.com/chrismaltais/LaTeXSwiftUI) | Mathematical formula rendering |
| [swift-numerics](https://github.com/apple/swift-numerics) | High-precision numerical computing |
| [swift-math-parser](https://github.com/mgriebling/swift-math-parser) | Expression parsing and evaluation |

---

## License

Copyright © 2025 Roger Lin. All rights reserved.

---

<a name="中文"></a>

# FinancialCalculatorKit

一款功能强大的 macOS 财务计算器应用，采用 SwiftUI 和 SwiftData 构建。可执行高级财务计算，包括货币时间价值、贷款计算、债券分析、投资评估、折旧计算和货币换算，并提供直观的可视化和专业级的精确度。

![FinancialCalculatorKit 主界面](FinancialCalculatorKit%202026-04-14%20at%2015.43.15@2x.png)

---

## 功能特点

### 核心财务计算器

| 计算器 | 功能 |
|--------|------|
| **货币时间价值 (TVM)** | 现值 (PV)、终值 (FV)、每期付款 (PMT)、利率 (I/Y)、期数 (N)、年金计算 |
| **贷款计算器** | 月供计算、摊销计划表、利息总额、额外还款方案、再融资分析 |
| **抵押贷款计算器** | 房贷分析、首付方案、PMI 计算、还款计划表 |
| **债券计算器** | 债券定价、到期收益率 (YTM)、久期、凸性、敏感性分析、现金流表 |
| **投资分析** | 净现值 (NPV)、内部收益率 (IRR)、改进内部收益率 (MIRR)、回收期、获利指数 |
| **期权计算器** | 布莱克-舒尔斯定价、希腊值分析（Delta、Gamma、Theta、Vega）、风险评估 |
| **折旧计算器** | 直线法、余额递减法、年数总和法、MACRS 法 |
| **货币换算** | 实时汇率、多币种支持、历史汇率查询 |
| **单位换算** | 国际单位换算，用于财务计算 |
| **数学表达式计算器** | 自定义公式解析，支持财务函数和变量 |

### 数据可视化

- **交互式图表**（基于 SwiftCharts）
  - 现金流时间线
  - 摊销计划表
  - 投资增长预测
  - 债券价格敏感性曲线
  - NPV/IRR 敏感性分析

- **数据表格**
  - 可排序的计算结果
  - 分页摊销计划表
  - 可搜索的付款明细

![摊销计划表](CleanShot%202025-06-10%20at%2001.59.41@2x.png)

### 专业工具

- **公式参考** — LaTeX 渲染的数学公式，配有变量定义说明
- **敏感性分析** — 交互式图表，展示结果如何随输入变化
- **场景分析** — 乐观/基准/悲观方案对比，用于投资决策
- **贷款洞察** — 基于输入内容的上下文提示和建议
- **计算历史** — 使用 SwiftData 保存、整理和检索历史计算

### 用户体验

- **原生 macOS 设计** — 遵循 Apple 人机界面指南
- **自适应布局** — 响应式设计，适应不同窗口大小
- **多币种支持** — 支持 8 种以上主要货币，实时格式化
- **无障碍访问** — 完整键盘导航和 VoiceOver 支持

---

## 截图

### 货币时间价值计算器
![TVM 计算器](CleanShot%202025-06-10%20at%2001.58.48@2x.png)

### 债券计算器与敏感性分析
![债券计算器](CleanShot%202025-06-10%20at%2002.00.11@2x.png)

---

## 系统要求

| 要求 | 版本 |
|------|------|
| macOS | 15.0+ |
| Xcode | 16.0+ |
| Swift | 6.0+ |

---

## 架构设计

应用采用 **MVVM（模型-视图-视图模型）** 架构：

- **模型 (Models)**：基于 SwiftData 的持久化层，包含专业计算引擎
- **视图 (Views)**：原生 SwiftUI 组件，配有自定义样式
- **视图模型 (ViewModels)**：ObservableObject 类，管理状态和业务逻辑
- **服务 (Services)**：网络、数据持久化和计算服务

### 项目结构

```
FinancialCalculatorKit/
├── Models/
│   ├── Calculation/           # 财务计算模型
│   │   ├── TimeValueCalculation.swift
│   │   ├── LoanCalculation.swift
│   │   ├── BondCalculation.swift
│   │   ├── InvestmentCalculation.swift
│   │   ├── DepreciationCalculation.swift
│   │   ├── OptionsCalculation.swift
│   │   └── CurrencyConversionCalculation.swift
│   └── Enums/                # 类型定义
├── Views/
│   ├── Calculator/           # 计算器界面
│   ├── Charts/               # 数据可视化
│   └── Components/           # 可复用 UI 组件
├── Utilities/
│   └── Extensions/           # Swift 扩展
└── FinancialCalculatorKitApp.swift
```

---

## 构建与运行

### 使用 Xcode

```bash
# 在 Xcode 中打开
open FinancialCalculatorKit.xcodeproj

# 构建
xcodebuild -project FinancialCalculatorKit.xcodeproj -scheme FinancialCalculatorKit build
```

### 使用 Swift Package Manager

```bash
# 从命令行构建
swift build
```

---

## 依赖项

| 包 | 用途 |
|----|------|
| [LaTeXSwiftUI](https://github.com/chrismaltais/LaTeXSwiftUI) | 数学公式渲染 |
| [swift-numerics](https://github.com/apple/swift-numerics) | 高精度数值计算 |
| [swift-math-parser](https://github.com/mgriebling/swift-math-parser) | 表达式解析与计算 |

---

## 许可证

版权所有 © 2025 Roger Lin。保留所有权利。
