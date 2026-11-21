import Foundation

/// Pennsylvania state payroll taxes, 2026.
///
/// Sources:
/// - PA Department of Revenue: personal income tax is a flat 3.07% with no withholding
///   allowances. Employee 401(k)/403(b) deferrals ARE taxable for PA; Section 125
///   cafeteria-plan health premiums are not.
/// - PA Department of Labor & Industry, UC tax "Yearly Tax Highlights": employee
///   unemployment compensation withholding is 0.07% of gross wages (2026).
public enum Pennsylvania {
    public static let incomeTaxRate = 0.0307
    public static let unemploymentEmployeeRate = 0.0007
    /// Local Services Tax exemption threshold (Act 7 of 2007).
    public static let lstExemptionThreshold: Double = 12_000
}

/// One municipality / school district pair (a PSD code) and its local tax rates.
public struct LocalTaxArea: Identifiable, Hashable, Sendable {
    public let psd: String
    public let county: String
    public let municipality: String
    public let schoolDistrict: String
    /// Earned income tax rate for people who live here (municipal + school district).
    public let residentRate: Double
    /// Earned income tax rate for people who work here but live elsewhere.
    public let nonresidentRate: Double
    /// Local Services Tax per year, owed where you work.
    public let lstAnnual: Double

    /// A few towns straddle two counties and appear under both with the same PSD code.
    public var id: String { "\(county)-\(psd)" }

    /// "Wyomissing Borough (Wilson SD)" when a town is split between school districts.
    public var displayName: String {
        let split = PALocalTax.areas(in: county).filter { $0.municipality == municipality }.count > 1
        return split ? "\(municipality) (\(schoolDistrict))" : municipality
    }
}

/// Pennsylvania local earned income tax (EIT) and Local Services Tax (LST) for every
/// municipality except Philadelphia, which has its own wage tax and isn't supported yet.
///
/// Source: PA DCED EIT/PIT/LST Tax Register, loaded from `Resources/pa_local_taxes.json`.
/// Rebuild that file each year with `scripts/update_pa_local_taxes.py`.
///
/// Withholding rule (Act 32): the employer withholds the HIGHER of your home's resident
/// rate and your work location's non-resident rate. LST is owed where you work.
public enum PALocalTax {
    public static let defaultCounty = "Berks"
    public static let defaultPSD = "061301" // Reading City

    public static var taxYear: Int { table.taxYear }
    /// Every area, sorted by county, then municipality, then school district.
    public static var areas: [LocalTaxArea] { table.areas }
    /// County names, alphabetical.
    public static var counties: [String] { table.counties }

    public static func areas(in county: String) -> [LocalTaxArea] {
        table.byCounty[county] ?? []
    }

    /// The area for a PSD code. Pass the county to pick the right entry for a town that
    /// straddles two counties (the tax rates are the same either way).
    public static func area(psd: String, county: String? = nil) -> LocalTaxArea? {
        let matches = table.byPSD[psd] ?? []
        return matches.first { $0.county == county } ?? matches.first
    }

    public static var defaultArea: LocalTaxArea { area(psd: defaultPSD, county: defaultCounty)! }

    // MARK: Loading

    private struct Table {
        let taxYear: Int
        let areas: [LocalTaxArea]
        let counties: [String]
        let byCounty: [String: [LocalTaxArea]]
        let byPSD: [String: [LocalTaxArea]]
    }

    private struct RawFile: Decodable {
        struct Area: Decodable {
            let psd, county, municipality, schoolDistrict: String
            let resident, nonresident, lst: Double
        }
        let taxYear: Int
        let areas: [Area]
    }

    private static let table: Table = {
        guard let url = Bundle.module.url(forResource: "pa_local_taxes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(RawFile.self, from: data) else {
            fatalError("pa_local_taxes.json is missing or unreadable")
        }
        let areas = raw.areas.map {
            LocalTaxArea(psd: $0.psd, county: $0.county, municipality: $0.municipality,
                         schoolDistrict: $0.schoolDistrict,
                         residentRate: ($0.resident / 100 * 10_000).rounded() / 10_000,
                         nonresidentRate: ($0.nonresident / 100 * 10_000).rounded() / 10_000,
                         lstAnnual: $0.lst)
        }
        let byCounty = Dictionary(grouping: areas, by: \.county)
        return Table(taxYear: raw.taxYear, areas: areas, counties: byCounty.keys.sorted(),
                     byCounty: byCounty, byPSD: Dictionary(grouping: areas, by: \.psd))
    }()
}
