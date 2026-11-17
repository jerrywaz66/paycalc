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
    public var vacationHours: Double = 0
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
        vacationHours = 0
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
    /// Not subject to federal income tax, Social Security, Medicare or (in most states) state tax.
    case preTaxHealth
    /// Traditional 401(k)/403(b)/457. Not subject to federal/state income tax,
    /// but still subject to Social Security and Medicare.
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

    /// Two-letter state code, or `StateTaxRules.customCode`.
    public var stateCode: String = "TX"
    /// Used only when the state is set to custom: flat percent of state wages.
    public var stateCustomRatePercent: Double = 0
    /// Annual amount subtracted before state tax (state allowances/exemptions from your state form).
    public var stateAnnualAllowance: Double = 0
    /// Extra state withholding per paycheck.
    public var stateExtraWithholding: Double = 0
    /// City/county income tax, percent of gross pay.
    public var localTaxPercent: Double = 0
    /// State payroll taxes such as CA SDI or paid family leave, percent of gross pay.
    public var statePayrollTaxPercent: Double = 0

    public init() {}
}
