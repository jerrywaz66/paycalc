import Foundation

// MARK: - Pay schedule

public enum PayFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly, biweekly, semimonthly, monthly

    public var id: String { rawValue }

    /// Pay periods per year (IRS Publication 15-T, Table 3).
    public var periodsPerYear: Int {
        switch self {
        case .weekly: return 52
        case .biweekly: return 26
        case .semimonthly: return 24
        case .monthly: return 12
        }
    }

    public var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every two weeks"
        case .semimonthly: return "Twice a month"
        case .monthly: return "Monthly"
        }
    }
}

public enum FilingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case single, marriedJointly, headOfHousehold

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .single: return "Single or married filing separately"
        case .marriedJointly: return "Married filing jointly"
        case .headOfHousehold: return "Head of household"
        }
    }
}

// MARK: - Hours entered for one paycheck

public struct HoursInput: Codable, Equatable, Sendable {
    public var hourlyRate: Double = 0
    public var regularHours: Double = 0
    public var overtimeHours: Double = 0
    public var doubleTimeHours: Double = 0
    public var tripleTimeHours: Double = 0
    /// Hours that earn the shift differential.
    public var shiftDifferentialHours: Double = 0
    /// Extra dollars per hour for differential hours.
    public var shiftDifferentialRate: Double = 0

    public init() {}

    /// Clears the hours but keeps the hourly rate and differential rate.
    public mutating func clearHours() {
        regularHours = 0
        overtimeHours = 0
        doubleTimeHours = 0
        tripleTimeHours = 0
        shiftDifferentialHours = 0
    }
}

public struct PayMultipliers: Codable, Equatable, Sendable {
    public var overtime: Double = 1.5
    public var doubleTime: Double = 2.0
    public var tripleTime: Double = 3.0
    public init() {}
}

// MARK: - Federal Form W-4 (2020 or later)

public struct W4: Codable, Equatable, Sendable {
    public var filingStatus: FilingStatus = .single
    /// Step 2 "multiple jobs / spouse works" checkbox.
    public var step2Checkbox: Bool = false
    /// Step 3: annual dependent credits.
    public var dependentCredits: Double = 0
    /// Step 4(a): annual other income.
    public var otherIncome: Double = 0
    /// Step 4(b): annual deductions.
    public var deductions: Double = 0
    /// Step 4(c): extra withholding per paycheck.
    public var extraWithholding: Double = 0
    public init() {}
}

// MARK: - Paycheck deductions

public enum DeductionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Section 125 cafeteria plan: medical, dental, vision, HSA/FSA through payroll.
    /// Not subject to federal, Social Security, Medicare, PA or local earned income tax.
    case preTaxHealth
    /// Traditional 401(k)/403(b)/457. Not subject to federal income tax, but still
    /// subject to Social Security, Medicare, PA income tax and local earned income tax.
    case preTaxRetirement
    /// Roth 401(k), union dues, etc. Taken after all taxes.
    case postTax

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .preTaxHealth: return "Pre-tax health (medical, dental, vision, HSA, FSA)"
        case .preTaxRetirement: return "Pre-tax retirement (401k, 403b)"
        case .postTax: return "After-tax (Roth 401k, union dues, other)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .preTaxHealth: return "Pre-tax health"
        case .preTaxRetirement: return "Pre-tax retirement"
        case .postTax: return "After-tax"
        }
    }
}

public struct Deduction: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var name: String
    public var kind: DeductionKind
    /// Dollars per paycheck, or percent of gross pay when `isPercentOfGross` is true.
    public var amount: Double
    public var isPercentOfGross: Bool

    public init(name: String, kind: DeductionKind, amount: Double, isPercentOfGross: Bool = false) {
        self.name = name
        self.kind = kind
        self.amount = amount
        self.isPercentOfGross = isPercentOfGross
    }

    public func amount(forGross gross: Double) -> Double {
        isPercentOfGross ? gross * amount / 100 : amount
    }
}

// MARK: - Saved profile (settings that rarely change)

public struct PayProfile: Codable, Equatable, Sendable {
    public var frequency: PayFrequency = .biweekly
    public var w4 = W4()
    public var multipliers = PayMultipliers()
    public var deductions: [Deduction] = []

    /// Where you live: county and PSD code. Sets the resident earned income tax rate.
    public var homeCounty: String = PALocalTax.defaultCounty
    public var homePSD: String = PALocalTax.defaultPSD
    /// Where you work: county and PSD code. Sets the non-resident earned income tax rate
    /// and the Local Services Tax.
    public var workCounty: String = PALocalTax.defaultCounty
    public var workPSD: String = PALocalTax.defaultPSD
    /// True if you filed an LST exemption (expected earnings from this job under $12,000).
    public var lstExempt: Bool = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case frequency, w4, multipliers, deductions, homeCounty, homePSD, workCounty, workPSD, lstExempt
    }

    /// Reads settings saved by any earlier version: missing fields keep their defaults.
    /// Versions before statewide support saved no county, and could save a work location of
    /// "OUTSIDE" (outside Berks County); that now falls back to where you live.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frequency = try c.decodeIfPresent(PayFrequency.self, forKey: .frequency) ?? frequency
        w4 = try c.decodeIfPresent(W4.self, forKey: .w4) ?? w4
        multipliers = try c.decodeIfPresent(PayMultipliers.self, forKey: .multipliers) ?? multipliers
        deductions = try c.decodeIfPresent([Deduction].self, forKey: .deductions) ?? deductions
        lstExempt = try c.decodeIfPresent(Bool.self, forKey: .lstExempt) ?? lstExempt

        let home = PALocalTax.area(psd: try c.decodeIfPresent(String.self, forKey: .homePSD) ?? "",
                                   county: try c.decodeIfPresent(String.self, forKey: .homeCounty))
            ?? PALocalTax.defaultArea
        let work = PALocalTax.area(psd: try c.decodeIfPresent(String.self, forKey: .workPSD) ?? "",
                                   county: try c.decodeIfPresent(String.self, forKey: .workCounty))
            ?? home
        (homeCounty, homePSD) = (home.county, home.psd)
        (workCounty, workPSD) = (work.county, work.psd)
    }
}
