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

/// One municipality / school district pair (a PSD code) in Berks County.
public struct LocalTaxArea: Identifiable, Hashable, Sendable {
    public let psd: String
    public let municipality: String
    public let schoolDistrict: String
    /// Earned income tax rate for people who live here (municipal + school).
    public let residentRate: Double
    /// Earned income tax rate for people who work here but live elsewhere.
    public let nonresidentRate: Double
    /// Local Services Tax per year, owed where you work.
    public let lstAnnual: Double

    public var id: String { psd }

    /// "Wyomissing Borough (Wilson SD)" for the one municipality split between districts.
    public var displayName: String {
        let duplicated = BerksCounty.areas.filter { $0.municipality == municipality }.count > 1
        return duplicated ? "\(municipality) (\(schoolDistrict))" : municipality
    }
}

/// Berks County earned income tax (EIT) and Local Services Tax (LST), 2026.
///
/// Source: PA DCED EIT/PIT/LST Tax Register (register updated September 17, 2026);
/// Reading figures confirmed against the City of Reading 2026 tax rate sheet.
/// Collector: Berks Earned Income Tax Bureau.
///
/// Withholding rule (Act 32): the employer withholds the HIGHER of your home's resident
/// rate and your work location's non-resident rate. LST is owed where you work.
public enum BerksCounty {
    /// Use for a job located outside Berks County; rates are entered in Settings.
    public static let outsideCountyPSD = "OUTSIDE"
    public static let defaultPSD = "061301" // Reading City

    public static func area(psd: String) -> LocalTaxArea? {
        areas.first { $0.psd == psd }
    }

    private static func a(_ psd: String, _ municipality: String, _ school: String,
                          resident: Double = 0.01, nonresident: Double = 0.01, lst: Double) -> LocalTaxArea {
        LocalTaxArea(psd: psd, municipality: municipality, schoolDistrict: school,
                     residentRate: resident, nonresidentRate: nonresident, lstAnnual: lst)
    }

    public static let areas: [LocalTaxArea] = [
        a("061001", "Albany Township", "Kutztown Area SD", lst: 52),
        a("061201", "Alsace Township", "Oley Valley SD", lst: 0),
        a("060501", "Amity Township", "Daniel Boone Area SD", lst: 52),
        a("060201", "Bally Borough", "Boyertown Area SD", lst: 52),
        a("060202", "Bechtelsville Borough", "Boyertown Area SD", lst: 52),
        a("061401", "Bern Township", "Schuylkill Valley SD", lst: 52),
        a("061501", "Bernville Borough", "Tulpehocken Area SD", lst: 52),
        a("061502", "Bethel Township", "Tulpehocken Area SD", lst: 52),
        a("060502", "Birdsboro Borough", "Daniel Boone Area SD", lst: 52),
        a("060203", "Boyertown Borough", "Boyertown Area SD", lst: 52),
        a("060801", "Brecknock Township", "Governor Mifflin SD", lst: 10),
        a("151001", "Caernarvon Township", "Twin Valley SD", lst: 52),
        a("061402", "Centerport Borough", "Schuylkill Valley SD", lst: 0),
        a("061403", "Centre Township", "Schuylkill Valley SD", lst: 0),
        a("060204", "Colebrookdale Township", "Boyertown Area SD", lst: 52),
        a("060802", "Cumru Township", "Governor Mifflin SD", lst: 52),
        a("060301", "District Township", "Brandywine Heights Area SD", lst: 10),
        a("060205", "Douglass Township", "Boyertown Area SD", lst: 52),
        a("060206", "Earl Township", "Boyertown Area SD", lst: 10),
        a("060601", "Exeter Township", "Exeter Township SD", lst: 52),
        a("060701", "Fleetwood Borough", "Fleetwood Area SD", lst: 52),
        a("061002", "Greenwich Township", "Kutztown Area SD", lst: 10),
        a("060901", "Hamburg Borough", "Hamburg Area SD", lst: 52),
        a("060401", "Heidelberg Township", "Conrad Weiser Area SD", lst: 52),
        a("462101", "Hereford Township", "Upper Perkiomen SD", lst: 52),
        a("061503", "Jefferson Township", "Tulpehocken Area SD", lst: 0),
        a("060803", "Kenhorst Borough", "Governor Mifflin SD", lst: 52),
        a("061003", "Kutztown Borough", "Kutztown Area SD", lst: 52),
        a("061101", "Laureldale Borough", "Muhlenberg SD", lst: 52),
        a("061404", "Leesport Borough", "Schuylkill Valley SD", lst: 52),
        a("061004", "Lenhartsville Borough", "Kutztown Area SD", lst: 10),
        a("060302", "Longswamp Township", "Brandywine Heights Area SD", lst: 52),
        a("060101", "Lower Alsace Township", "Antietam SD", lst: 52),
        a("061601", "Lower Heidelberg Township", "Wilson SD", lst: 52),
        a("061005", "Lyons Borough", "Kutztown Area SD", lst: 52),
        a("060702", "Maidencreek Township", "Fleetwood Area SD", lst: 52),
        a("060402", "Marion Township", "Conrad Weiser Area SD", lst: 0),
        a("061006", "Maxatawny Township", "Kutztown Area SD", lst: 52),
        a("060804", "Mohnton Borough", "Governor Mifflin SD", lst: 52),
        a("060102", "Mount Penn Borough", "Antietam SD", lst: 52),
        a("061102", "Muhlenberg Township", "Muhlenberg SD", lst: 52),
        a("151002", "New Morgan Borough", "Twin Valley SD", lst: 52),
        a("060403", "North Heidelberg Township", "Conrad Weiser Area SD", lst: 0),
        a("061202", "Oley Township", "Oley Valley SD", lst: 52),
        a("061405", "Ontelaunee Township", "Schuylkill Valley SD", lst: 52),
        a("061504", "Penn Township", "Tulpehocken Area SD", lst: 0),
        a("060902", "Perry Township", "Hamburg Area SD", lst: 26),
        a("061203", "Pike Township", "Oley Valley SD", lst: 0),
        a("061301", "Reading City", "Reading SD", resident: 0.036, nonresident: 0.01, lst: 52),
        a("060703", "Richmond Township", "Fleetwood Area SD", lst: 52),
        a("151003", "Robeson Township", "Twin Valley SD", lst: 52),
        a("060404", "Robesonia Borough", "Conrad Weiser Area SD", lst: 52),
        a("060303", "Rockland Township", "Brandywine Heights Area SD", lst: 10),
        a("061204", "Ruscombmanor Township", "Oley Valley SD", nonresident: 0.005, lst: 0),
        a("060805", "Shillington Borough", "Governor Mifflin SD", lst: 52),
        a("060903", "Shoemakersville Borough", "Hamburg Area SD", lst: 52),
        a("061602", "Sinking Spring Borough", "Wilson SD", lst: 52),
        a("060405", "South Heidelberg Township", "Conrad Weiser Area SD", lst: 52),
        a("061603", "Spring Township", "Wilson SD", lst: 52),
        a("060602", "St. Lawrence Borough", "Exeter Township SD", lst: 52),
        a("060905", "Tilden Township", "Hamburg Area SD", lst: 52),
        a("060304", "Topton Borough", "Brandywine Heights Area SD", lst: 52),
        a("061505", "Tulpehocken Township", "Tulpehocken Area SD", lst: 52),
        a("060503", "Union Township", "Daniel Boone Area SD", lst: 52),
        a("060906", "Upper Bern Township", "Hamburg Area SD", lst: 52),
        a("060907", "Upper Tulpehocken Township", "Hamburg Area SD", lst: 52),
        a("060207", "Washington Township", "Boyertown Area SD", lst: 52),
        a("060406", "Wernersville Borough", "Conrad Weiser Area SD", lst: 0),
        a("061701", "West Reading Borough", "Wyomissing Area SD", lst: 52),
        a("060908", "Windsor Township", "Hamburg Area SD", lst: 0),
        a("060407", "Womelsdorf Borough", "Conrad Weiser Area SD", lst: 52),
        a("061604", "Wyomissing Borough", "Wilson SD", lst: 52),
        a("061702", "Wyomissing Borough", "Wyomissing Area SD", lst: 52),
    ]
}
