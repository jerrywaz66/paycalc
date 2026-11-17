import Foundation

/// One row of an IRS annual percentage-method table:
/// if the adjusted annual wage is at least `atLeast`, withhold `base` plus `rate` × (wage − `atLeast`).
public struct WithholdingRow: Sendable {
    public let atLeast: Double
    public let base: Double
    public let rate: Double
}

/// 2026 federal figures.
///
/// Sources:
/// - IRS Publication 15-T (2026), Worksheet 1A and the Annual Percentage Method Tables
///   for Automated Payroll Systems (Forms W-4 from 2020 or later).
/// - SSA 2026 fact sheet: Social Security wage base $184,500.
public enum TaxTables2026 {
    public static let year = 2026

    // Worksheet 1A, line 1g (used when the W-4 Step 2 box is NOT checked).
    public static let worksheetAdjustmentMarried: Double = 12_900
    public static let worksheetAdjustmentOther: Double = 8_600

    // FICA
    public static let socialSecurityRate = 0.062
    public static let socialSecurityWageBase: Double = 184_500
    public static let medicareRate = 0.0145
    public static let additionalMedicareRate = 0.009
    /// Employers withhold Additional Medicare Tax on wages over $200,000 regardless of filing status.
    public static let additionalMedicareThreshold: Double = 200_000

    // Overtime deduction (One Big Beautiful Bill Act, tax years 2025–2028).
    public static let overtimeDeductionCapSingle: Double = 12_500
    public static let overtimeDeductionCapMarried: Double = 25_000

    public static func table(for status: FilingStatus, step2Checkbox: Bool) -> [WithholdingRow] {
        switch (status, step2Checkbox) {
        case (.marriedJointly, false): return marriedStandard
        case (.marriedJointly, true): return marriedCheckbox
        case (.single, false): return singleStandard
        case (.single, true): return singleCheckbox
        case (.headOfHousehold, false): return headOfHouseholdStandard
        case (.headOfHousehold, true): return headOfHouseholdCheckbox
        }
    }

    private static func rows(_ values: [(Double, Double, Double)]) -> [WithholdingRow] {
        values.map { WithholdingRow(atLeast: $0.0, base: $0.1, rate: $0.2) }
    }

    static let marriedStandard = rows([
        (0, 0, 0),
        (19_300, 0, 0.10),
        (44_100, 2_480, 0.12),
        (120_100, 11_600, 0.22),
        (230_700, 35_932, 0.24),
        (422_850, 82_048, 0.32),
        (531_750, 116_896, 0.35),
        (788_000, 206_583.50, 0.37),
    ])

    static let marriedCheckbox = rows([
        (0, 0, 0),
        (16_100, 0, 0.10),
        (28_500, 1_240, 0.12),
        (66_500, 5_800, 0.22),
        (121_800, 17_966, 0.24),
        (217_875, 41_024, 0.32),
        (272_325, 58_448, 0.35),
        (400_450, 103_291.75, 0.37),
    ])

    static let singleStandard = rows([
        (0, 0, 0),
        (7_500, 0, 0.10),
        (19_900, 1_240, 0.12),
        (57_900, 5_800, 0.22),
        (113_200, 17_966, 0.24),
        (209_275, 41_024, 0.32),
        (263_725, 58_448, 0.35),
        (648_100, 192_979.25, 0.37),
    ])

    static let singleCheckbox = rows([
        (0, 0, 0),
        (8_050, 0, 0.10),
        (14_250, 620, 0.12),
        (33_250, 2_900, 0.22),
        (60_900, 8_983, 0.24),
        (108_938, 20_512, 0.32),
        (136_163, 29_224, 0.35),
        (328_350, 96_489.63, 0.37),
    ])

    static let headOfHouseholdStandard = rows([
        (0, 0, 0),
        (15_550, 0, 0.10),
        (33_250, 1_770, 0.12),
        (83_000, 7_740, 0.22),
        (121_250, 16_155, 0.24),
        (217_300, 39_207, 0.32),
        (271_750, 56_631, 0.35),
        (656_150, 191_171, 0.37),
    ])

    static let headOfHouseholdCheckbox = rows([
        (0, 0, 0),
        (12_075, 0, 0.10),
        (20_925, 885, 0.12),
        (45_800, 3_870, 0.22),
        (64_925, 8_077.50, 0.24),
        (112_950, 19_603.50, 0.32),
        (140_175, 28_315.50, 0.35),
        (332_375, 95_585.50, 0.37),
    ])
}
