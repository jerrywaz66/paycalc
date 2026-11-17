import Foundation

public struct PayLine: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let detail: String?
    public let amount: Double
}

public struct PayResult: Sendable {
    public var earnings: [PayLine] = []
    public var grossPay: Double = 0

    public var deductions: [PayLine] = []
    public var taxes: [PayLine] = []

    public var federalIncomeTax: Double = 0
    public var socialSecurity: Double = 0
    public var medicare: Double = 0
    public var paIncomeTax: Double = 0
    public var localEarnedIncomeTax: Double = 0
    /// The rate used: the higher of the home resident and work non-resident rates.
    public var localEarnedIncomeTaxRate: Double = 0
    public var localServicesTax: Double = 0
    public var paUnemploymentTax: Double = 0

    public var totalTaxes: Double = 0
    public var totalDeductions: Double = 0
    public var netPay: Double = 0

    /// Wages each tax was figured on, for display.
    public var federalTaxableWages: Double = 0
    public var ficaWages: Double = 0
    /// PA and local earned income tax wages: gross minus Section 125 only (401k is taxable in PA).
    public var paTaxableWages: Double = 0

    /// The half-time premium on overtime hours that counts toward the federal
    /// "no tax on overtime" deduction. It is claimed when you file, not taken off
    /// each paycheck, so it is shown as an estimate only.
    public var qualifiedOvertimePremium: Double = 0
    public var estimatedOvertimeTaxSavings: Double = 0
    /// Marginal federal rate from the withholding table.
    public var federalMarginalRate: Double = 0
}

public enum PayCalculator {

    /// - Parameter ytdFicaWages: Social Security/Medicare wages already paid this year,
    ///   before this paycheck. Used for the Social Security cap and Additional Medicare Tax.
    public static func calculate(hours: HoursInput, profile: PayProfile, ytdFicaWages: Double = 0) -> PayResult {
        var result = PayResult()
        let rate = hours.hourlyRate
        let m = profile.multipliers
        // 1. Gross pay
        func earning(_ label: String, _ h: Double, _ multiplier: Double) {
            guard h > 0 else { return }
            let lineRate = rate * multiplier
            result.earnings.append(PayLine(label: label,
                                           detail: "\(h.trimmed) hrs × \(lineRate.currency)",
                                           amount: (h * lineRate).cents))
        }
        earning("Regular", hours.regularHours, 1)
        earning("Overtime", hours.overtimeHours, m.overtime)
        earning("Double time", hours.doubleTimeHours, m.doubleTime)
        earning("Triple time", hours.tripleTimeHours, m.tripleTime)
        earning("Vacation", hours.vacationHours, 1)
        if hours.shiftDifferentialHours > 0 && hours.shiftDifferentialRate != 0 {
            result.earnings.append(PayLine(
                label: "Shift differential",
                detail: "\(hours.shiftDifferentialHours.trimmed) hrs × \(hours.shiftDifferentialRate.currency)",
                amount: (hours.shiftDifferentialHours * hours.shiftDifferentialRate).cents))
        }
        let gross = result.earnings.reduce(0) { $0 + $1.amount }
        result.grossPay = gross

        // 2. Deductions
        var preTaxHealth = 0.0, preTaxRetirement = 0.0, postTax = 0.0
        for d in profile.deductions {
            let amount = d.amount(forGross: gross).cents
            guard amount != 0 else { continue }
            switch d.kind {
            case .preTaxHealth: preTaxHealth += amount
            case .preTaxRetirement: preTaxRetirement += amount
            case .postTax: postTax += amount
            }
            result.deductions.append(PayLine(label: d.name.isEmpty ? "Deduction" : d.name,
                                             detail: d.kind.shortLabel, amount: amount))
        }
        result.totalDeductions = preTaxHealth + preTaxRetirement + postTax

        let incomeTaxWages = max(0, gross - preTaxHealth - preTaxRetirement)
        let ficaWages = max(0, gross - preTaxHealth)
        result.federalTaxableWages = incomeTaxWages
        result.ficaWages = ficaWages

        // 3. Federal income tax withholding (Pub 15-T Worksheet 1A)
        let federal = federalWithholding(wages: incomeTaxWages, periodsPerYear: profile.frequency.periodsPerYear,
                                         w4: profile.w4)
        result.federalIncomeTax = federal.amount
        result.federalMarginalRate = federal.marginalRate

        // 4. Social Security and Medicare
        let ssRoom = max(0, TaxTables2026.socialSecurityWageBase - ytdFicaWages)
        result.socialSecurity = (min(ficaWages, ssRoom) * TaxTables2026.socialSecurityRate).cents
        let overThreshold = max(0, ytdFicaWages + ficaWages - max(TaxTables2026.additionalMedicareThreshold, ytdFicaWages))
        result.medicare = (ficaWages * TaxTables2026.medicareRate
                           + overThreshold * TaxTables2026.additionalMedicareRate).cents

        // 5. Pennsylvania and Berks County local taxes
        let paWages = max(0, gross - preTaxHealth)
        result.paTaxableWages = paWages
        result.paIncomeTax = (paWages * Pennsylvania.incomeTaxRate).cents
        result.paUnemploymentTax = (ficaWages * Pennsylvania.unemploymentEmployeeRate).cents
        let local = localTaxes(wages: paWages, periodsPerYear: profile.frequency.periodsPerYear, profile: profile)
        result.localEarnedIncomeTaxRate = local.eitRate
        result.localEarnedIncomeTax = local.eit
        result.localServicesTax = local.lst

        result.taxes = [
            PayLine(label: "Federal income tax", detail: nil, amount: result.federalIncomeTax),
            PayLine(label: "Social Security", detail: "6.2%", amount: result.socialSecurity),
            PayLine(label: "Medicare", detail: "1.45%", amount: result.medicare),
            PayLine(label: "PA income tax", detail: "3.07%", amount: result.paIncomeTax),
            PayLine(label: "Local earned income tax", detail: "\((local.eitRate * 100).trimmed)%",
                    amount: result.localEarnedIncomeTax),
        ]
        if result.localServicesTax > 0 {
            result.taxes.append(PayLine(label: "Local services tax", detail: "\(local.lstAnnual.currency) a year",
                                        amount: result.localServicesTax))
        }
        result.taxes.append(PayLine(label: "PA unemployment (UC)", detail: "0.07%", amount: result.paUnemploymentTax))
        result.totalTaxes = result.taxes.reduce(0) { $0 + $1.amount }

        result.netPay = (gross - result.totalTaxes - result.totalDeductions).cents

        // 6. Overtime deduction estimate: only the extra half of time-and-a-half counts.
        let premiumRate = rate * max(0, min(m.overtime, 1.5) - 1)
        result.qualifiedOvertimePremium = (hours.overtimeHours * premiumRate).cents
        result.estimatedOvertimeTaxSavings = (result.qualifiedOvertimePremium * federal.marginalRate).cents

        return result
    }

    /// IRS Publication 15-T (2026), Worksheet 1A, for a Form W-4 from 2020 or later.
    public static func federalWithholding(wages: Double, periodsPerYear: Int, w4: W4)
        -> (amount: Double, marginalRate: Double) {
        let periods = Double(periodsPerYear)
        // Step 1
        let annualWages = wages * periods + w4.otherIncome                                // 1c + 1d
        let adjustment = w4.step2Checkbox ? 0
            : (w4.filingStatus == .marriedJointly ? TaxTables2026.worksheetAdjustmentMarried
                                                  : TaxTables2026.worksheetAdjustmentOther) // 1g
        let adjustedAnnual = max(0, annualWages - (w4.deductions + adjustment))           // 1i
        // Step 2
        let table = TaxTables2026.table(for: w4.filingStatus, step2Checkbox: w4.step2Checkbox)
        let row = table.last { adjustedAnnual >= $0.atLeast } ?? table[0]
        let tentativeAnnual = row.base + (adjustedAnnual - row.atLeast) * row.rate
        let tentative = tentativeAnnual / periods                                          // 2h
        // Step 3
        let afterCredits = max(0, tentative - w4.dependentCredits / periods)               // 3c
        // Step 4
        return ((afterCredits + w4.extraWithholding).cents, row.rate)
    }

    /// Berks County earned income tax and Local Services Tax for one paycheck.
    public static func localTaxes(wages: Double, periodsPerYear: Int, profile: PayProfile)
        -> (eitRate: Double, eit: Double, lstAnnual: Double, lst: Double) {
        let home = BerksCounty.area(psd: profile.homePSD) ?? BerksCounty.area(psd: BerksCounty.defaultPSD)!
        let workNonresidentRate: Double
        let lstAnnual: Double
        if profile.workPSD == BerksCounty.outsideCountyPSD {
            workNonresidentRate = profile.outsideWorkNonresidentRatePercent / 100
            lstAnnual = profile.outsideWorkLSTAnnual
        } else {
            let work = BerksCounty.area(psd: profile.workPSD) ?? home
            workNonresidentRate = work.nonresidentRate
            lstAnnual = work.lstAnnual
        }
        // Act 32: withhold the higher of the resident and non-resident rates.
        let rate = max(home.residentRate, workNonresidentRate)
        let lst = profile.lstExempt ? 0 : (lstAnnual / Double(periodsPerYear)).cents
        return (rate, (wages * rate).cents, lstAnnual, lst)
    }
}

// MARK: - Formatting helpers

extension Double {
    /// Rounded to the nearest cent.
    public var cents: Double { (self * 100).rounded() / 100 }

    public var currency: String { formatted(.currency(code: "USD")) }

    /// "40", "7.5", "2.25"
    public var trimmed: String { formatted(.number.precision(.fractionLength(0...2))) }
}
