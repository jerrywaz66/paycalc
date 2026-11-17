import Foundation

public struct StateTaxRule: Identifiable, Sendable {
    public enum Kind: Sendable {
        /// No tax on wages.
        case noIncomeTax
        /// One rate on annual state wages above `exemptAmount`.
        case flat(rate: Double, exemptAmount: Double)
        /// Rate entered by the user in Settings.
        case custom
    }

    public let code: String
    public let name: String
    public let kind: Kind
    public let note: String?

    public var id: String { code }

    public var taxesWages: Bool {
        if case .noIncomeTax = kind { return false }
        return true
    }

    public var isCustom: Bool {
        if case .custom = kind { return true }
        return false
    }
}

/// 2026 state rules (Tax Foundation, "State Individual Income Tax Rates and Brackets, 2026").
///
/// These are income-tax rates, not each state's own withholding formula. Flat-rate states
/// are close; enter your state allowance in Settings to match your stub more exactly.
/// States with graduated brackets use "Other state" with a rate you enter, until their
/// full tables are added.
public enum StateTaxRules {
    public static let customCode = "OTHER"

    public static let all: [StateTaxRule] = (noTaxStates + flatStates).sorted { $0.name < $1.name } + [
        StateTaxRule(code: customCode, name: "Other state (enter rate)", kind: .custom,
                     note: "Enter the percent your state withholds in Settings."),
    ]

    public static func rule(for code: String) -> StateTaxRule {
        all.first { $0.code == code } ?? all.last!
    }

    private static func noTax(_ code: String, _ name: String, _ note: String? = nil) -> StateTaxRule {
        StateTaxRule(code: code, name: name, kind: .noIncomeTax, note: note)
    }

    private static func flatRate(_ code: String, _ name: String, _ rate: Double, exempt: Double = 0,
                             _ note: String? = nil) -> StateTaxRule {
        StateTaxRule(code: code, name: name, kind: .flat(rate: rate, exemptAmount: exempt), note: note)
    }

    static let noTaxStates: [StateTaxRule] = [
        noTax("AK", "Alaska"),
        noTax("FL", "Florida"),
        noTax("NV", "Nevada"),
        noTax("NH", "New Hampshire"),
        noTax("SD", "South Dakota"),
        noTax("TN", "Tennessee"),
        noTax("TX", "Texas"),
        noTax("WA", "Washington", "Washington has no wage income tax. WA Cares (0.58%) and paid leave go in State payroll tax."),
        noTax("WY", "Wyoming"),
    ]

    static let flatStates: [StateTaxRule] = [
        flatRate("AZ", "Arizona", 0.025),
        flatRate("CO", "Colorado", 0.044),
        flatRate("GA", "Georgia", 0.0519),
        flatRate("ID", "Idaho", 0.053),
        flatRate("IL", "Illinois", 0.0495),
        flatRate("IN", "Indiana", 0.0295, "County income tax goes in Local tax."),
        flatRate("IA", "Iowa", 0.038),
        flatRate("KY", "Kentucky", 0.035, "Local occupational tax goes in Local tax."),
        flatRate("LA", "Louisiana", 0.03),
        flatRate("MI", "Michigan", 0.0425, "City income tax goes in Local tax."),
        flatRate("MS", "Mississippi", 0.04, exempt: 10_000, "First $10,000 is taxed at 0%."),
        flatRate("NC", "North Carolina", 0.0399),
        flatRate("OH", "Ohio", 0.0275, exempt: 26_050, "Income up to $26,050 is taxed at 0%. City tax goes in Local tax."),
        flatRate("PA", "Pennsylvania", 0.0307, "PA taxes 401(k) contributions, so state tax may run slightly higher on your stub. Local earned income tax goes in Local tax."),
        flatRate("UT", "Utah", 0.045),
    ]
}
