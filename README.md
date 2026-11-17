# PayCalc

A personal iOS paycheck calculator for hourly pay. Enter your hours, see your take-home pay.

## What it calculates

**Earnings**
- Regular hours × hourly rate
- Overtime, double time and triple time (multipliers default to 1.5×, 2×, 3× and can be changed in Settings)
- Vacation hours at the base rate
- Shift differential: differential hours × extra $ per hour

**Taxes (2026)**
- Federal income tax withholding: IRS Publication 15-T (2026), Worksheet 1A percentage method, Form W-4 2020 or later (filing status, Step 2 checkbox, Steps 3, 4(a), 4(b), 4(c))
- Social Security 6.2% up to the $184,500 wage base (uses the optional year-to-date field)
- Medicare 1.45%, plus 0.9% Additional Medicare over $200,000
- Pennsylvania income tax 3.07% (401(k) contributions are taxable in PA; Section 125 health premiums are not)
- Pennsylvania unemployment (UC) employee withholding 0.07%
- Berks County local earned income tax for all 73 municipality/school district pairs: the higher of your home's resident rate and your work location's non-resident rate (Act 32). A job outside Berks takes a rate you enter.
- Local Services Tax for where you work, spread evenly over your paychecks, with an exemption toggle

**Deductions**: pre-tax health (Section 125), pre-tax retirement (401k), or after-tax, each as a dollar amount or % of gross.

**No tax on overtime (estimate)**: the qualifying overtime premium and the estimated federal tax it saves. This is claimed when you file, not taken out of each paycheck.

## Project layout

```
PayCalcCore/   Swift package: tax tables and the calculator (no UI), with unit tests
App/           SwiftUI iPhone app
project.yml    XcodeGen spec that generates PayCalc.xcodeproj
```

## Build and run (on a Mac)

1. Install Xcode 15 or later, and XcodeGen: `brew install xcodegen`
2. From the repo folder run `xcodegen`, then open `PayCalc.xcodeproj`
3. Select the **PayCalc** target → **Signing & Capabilities** → choose your Team (your Apple ID works for personal use). Change the bundle identifier if Xcode asks.
4. Pick your iPhone or a simulator and press Run.

Run the calculator tests: `cd PayCalcCore && swift test`

## Updating for a new tax year

All federal figures are in `PayCalcCore/Sources/PayCalcCore/TaxTables2026.swift`; Pennsylvania and Berks County rates are in `Pennsylvania.swift`. When the IRS publishes the next Publication 15-T, update the tables and the expected values in the tests.

## Sources

- IRS Publication 15-T (2026), Federal Income Tax Withholding Methods
- SSA 2026 Social Security changes fact sheet (wage base $184,500)
- PA Department of Labor & Industry, UC Yearly Tax Highlights (employee rate 0.07%, 2026)
- PA DCED EIT/PIT/LST Tax Register (Berks County, updated September 17, 2026), and the City of Reading 2026 tax rate sheet
