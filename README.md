# PayCalc

A personal iOS paycheck calculator for hourly pay. Enter your hours, see your take-home pay.

## What it calculates

**Earnings**
- Regular hours × hourly rate
- Overtime, double time and triple time (multipliers default to 1.5×, 2×, 3× and can be changed in Settings)
- Shift differential: differential hours × extra $ per hour

**Taxes (2026)**
- Federal income tax withholding: IRS Publication 15-T (2026), Worksheet 1A percentage method, Form W-4 2020 or later (filing status, Step 2 checkbox, Steps 3, 4(a), 4(b), 4(c))
- Social Security 6.2% up to the $184,500 wage base (uses the optional year-to-date field)
- Medicare 1.45%, plus 0.9% Additional Medicare over $200,000
- Pennsylvania income tax 3.07% (401(k) contributions are taxable in PA; Section 125 health premiums are not)
- Pennsylvania unemployment (UC) employee withholding 0.07%
- Pennsylvania local earned income tax for every municipality/school district pair in 66 counties (all of PA except Philadelphia, whose wage tax works differently). You pick the county and town where you live and where you work; the app withholds the higher of your home's resident rate and your work location's non-resident rate (Act 32).
- Local Services Tax for where you work ($52 a year in most places, up to $156 in distressed cities such as Harrisburg), spread evenly over your paychecks, with an exemption toggle

**Deductions**: pre-tax health (Section 125), pre-tax retirement (401k), or after-tax, each as a dollar amount or % of gross.

**No tax on overtime (estimate)**: the qualifying overtime premium and the estimated federal tax it saves. This is claimed when you file, not taken out of each paycheck.

## Project layout

```
PayCalcCore/   Swift package: tax tables and the calculator (no UI), with unit tests
App/           SwiftUI iPhone app
scripts/       Yearly refresh of the Pennsylvania local tax data
project.yml    XcodeGen spec that generates PayCalc.xcodeproj
```

## Build and run (on a Mac)

1. Install Xcode 15 or later, and XcodeGen: `brew install xcodegen`
2. From the repo folder run `xcodegen`, then open `PayCalc.xcodeproj`
3. Select the **PayCalc** target → **Signing & Capabilities** → choose your Team (your Apple ID works for personal use). Change the bundle identifier if Xcode asks.
4. Pick your iPhone or a simulator and press Run.

Run the calculator tests: `cd PayCalcCore && swift test`

## Updating for a new tax year

All federal figures are in `PayCalcCore/Sources/PayCalcCore/TaxTables2026.swift`; PA state rates are in `Pennsylvania.swift`. When the IRS publishes the next Publication 15-T, update the tables and the expected values in the tests.

Local tax rates for every PA town live in `PayCalcCore/Sources/PayCalcCore/Resources/pa_local_taxes.json`. When DCED posts the new tax year (usually December or January), rebuild that file from the official register:

```bash
python3 scripts/update_pa_local_taxes.py
```

Then run the tests and update the tax year and spot-check values in `testStatewideTableFromDCEDRegister`.

## Sources

- IRS Publication 15-T (2026), Federal Income Tax Withholding Methods
- SSA 2026 Social Security changes fact sheet (wage base $184,500)
- PA Department of Labor & Industry, UC Yearly Tax Highlights (employee rate 0.07%, 2026)
- PA DCED EIT/PIT/LST Tax Register, all counties, 2026 (downloaded November 2026); Berks County figures were also checked against the City of Reading 2026 tax rate sheet
