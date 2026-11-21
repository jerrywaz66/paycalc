import XCTest
@testable import PayCalcCore

/// Expected values were worked out by hand from IRS Pub 15-T (2026) Worksheet 1A
/// and checked with an independent script.
final class PayCalculatorTests: XCTestCase {

    func testWeeklySingleWithOvertime() {
        var hours = HoursInput()
        hours.hourlyRate = 25
        hours.regularHours = 40
        hours.overtimeHours = 5

        var profile = PayProfile()
        profile.frequency = .weekly

        let r = PayCalculator.calculate(hours: hours, profile: profile)
        XCTAssertEqual(r.grossPay, 1_187.50, accuracy: 0.001)
        // (1,187.50 × 52 − 8,600) = 53,150 → 1,240 + 12% × 33,250 = 5,230 / 52
        XCTAssertEqual(r.federalIncomeTax, 100.58, accuracy: 0.001)
        XCTAssertEqual(r.socialSecurity, 73.63, accuracy: 0.001)
        XCTAssertEqual(r.medicare, 17.22, accuracy: 0.001)
        XCTAssertEqual(r.netPay, r.grossPay - r.totalTaxes, accuracy: 0.001)
        // 5 OT hours × $12.50 premium
        XCTAssertEqual(r.qualifiedOvertimePremium, 62.50, accuracy: 0.001)
        XCTAssertEqual(r.federalMarginalRate, 0.12)
    }

    func testBiweeklyMarriedAllHourTypesDeductionsReading() {
        var hours = HoursInput()
        hours.hourlyRate = 40
        hours.regularHours = 88
        hours.overtimeHours = 4
        hours.doubleTimeHours = 2
        hours.tripleTimeHours = 1
        hours.shiftDifferentialHours = 20
        hours.shiftDifferentialRate = 2

        var profile = PayProfile()
        profile.frequency = .biweekly
        profile.w4.filingStatus = .marriedJointly
        profile.homePSD = "061301" // Reading City: 3.6% resident EIT, $52 LST
        profile.workPSD = "061301"
        profile.deductions = [
            Deduction(name: "Medical", kind: .preTaxHealth, amount: 100),
            Deduction(name: "401(k)", kind: .preTaxRetirement, amount: 5, isPercentOfGross: true),
        ]

        let r = PayCalculator.calculate(hours: hours, profile: profile)
        // 3,520 + 240 + 160 + 120 + 40
        XCTAssertEqual(r.grossPay, 4_080, accuracy: 0.001)
        XCTAssertEqual(r.federalTaxableWages, 3_776, accuracy: 0.001)
        XCTAssertEqual(r.ficaWages, 3_980, accuracy: 0.001)
        XCTAssertEqual(r.federalIncomeTax, 285.43, accuracy: 0.001)
        XCTAssertEqual(r.socialSecurity, 246.76, accuracy: 0.001)
        XCTAssertEqual(r.medicare, 57.71, accuracy: 0.001)
        // PA and local tax 401(k) contributions, so their wage base is 4,080 − 100.
        XCTAssertEqual(r.paTaxableWages, 3_980, accuracy: 0.001)
        XCTAssertEqual(r.paIncomeTax, 122.19, accuracy: 0.001)
        XCTAssertEqual(r.localEarnedIncomeTax, 143.28, accuracy: 0.001)
        XCTAssertEqual(r.localServicesTax, 2.00, accuracy: 0.001)
        XCTAssertEqual(r.paUnemploymentTax, 2.79, accuracy: 0.001)
        XCTAssertEqual(r.netPay, 2_915.84, accuracy: 0.001)
    }

    func testSocialSecurityStopsAtWageBase() {
        var hours = HoursInput()
        hours.hourlyRate = 100
        hours.regularHours = 80 // 8,000 gross

        let profile = PayProfile()

        // Only 4,500 of room left under the 184,500 cap.
        let r = PayCalculator.calculate(hours: hours, profile: profile, ytdFicaWages: 180_000)
        XCTAssertEqual(r.socialSecurity, 279.00, accuracy: 0.001)
        // 8,000 × 1.45% + (188,000 − 200,000 → 0) × 0.9%
        XCTAssertEqual(r.medicare, 116.00, accuracy: 0.001)

        // Past 200,000: Additional Medicare on everything over it.
        let r2 = PayCalculator.calculate(hours: hours, profile: profile, ytdFicaWages: 196_000)
        XCTAssertEqual(r2.socialSecurity, 0)
        XCTAssertEqual(r2.medicare, 116.00 + 36.00, accuracy: 0.001)
    }

    func testW4CreditsAndExtraWithholding() {
        var w4 = W4()
        w4.dependentCredits = 2_600   // $100 per biweekly check
        w4.extraWithholding = 25
        // 2,000 × 26 = 52,000 − 8,600 = 43,400 → 1,240 + 12% × 23,500 = 4,060 / 26 = 156.15
        let r = PayCalculator.federalWithholding(wages: 2_000, periodsPerYear: 26, w4: w4)
        XCTAssertEqual(r.amount, 156.15 - 100 + 25, accuracy: 0.001)
    }

    func testLocalTaxUsesHigherOfResidentAndWorkRate() {
        var profile = PayProfile()
        profile.frequency = .semimonthly

        // Live in Exeter (1% resident), work in Reading (1% non-resident, $52 LST).
        profile.homePSD = "060601"
        profile.workPSD = "061301"
        var t = PayCalculator.localTaxes(wages: 2_000, periodsPerYear: 24, profile: profile)
        XCTAssertEqual(t.eitRate, 0.01)
        XCTAssertEqual(t.eit, 20.00, accuracy: 0.001)
        XCTAssertEqual(t.lst, 2.17, accuracy: 0.001)   // 52 / 24

        // Live in Reading (3.6%), work in Ruscombmanor (0.5% non-resident, no LST).
        profile.homePSD = "061301"
        profile.workPSD = "061204"
        t = PayCalculator.localTaxes(wages: 2_000, periodsPerYear: 24, profile: profile)
        XCTAssertEqual(t.eitRate, 0.036)
        XCTAssertEqual(t.eit, 72.00, accuracy: 0.001)
        XCTAssertEqual(t.lst, 0)

        // Live in Pittsburgh (3% resident), work in Harrisburg (1% non-resident, $156 LST),
        // first not exempt from the LST, then exempt.
        profile.homeCounty = "Allegheny"
        profile.homePSD = "700102"
        profile.workCounty = "Dauphin"
        profile.workPSD = "220401"
        t = PayCalculator.localTaxes(wages: 2_000, periodsPerYear: 24, profile: profile)
        XCTAssertEqual(t.eitRate, 0.03)
        XCTAssertEqual(t.eit, 60.00, accuracy: 0.001)
        XCTAssertEqual(t.lstAnnual, 156)
        XCTAssertEqual(t.lst, 6.50, accuracy: 0.001)   // 156 / 24
        profile.lstExempt = true
        t = PayCalculator.localTaxes(wages: 2_000, periodsPerYear: 24, profile: profile)
        XCTAssertEqual(t.lst, 0)
    }

    func testStatewideTableFromDCEDRegister() {
        XCTAssertEqual(PALocalTax.taxYear, 2026)
        // 67 PA counties minus Philadelphia.
        XCTAssertEqual(PALocalTax.counties.count, 66)
        XCTAssertFalse(PALocalTax.counties.contains("Philadelphia"))
        XCTAssertEqual(PALocalTax.areas.count, 2_626)
        for county in PALocalTax.counties {
            XCTAssertFalse(PALocalTax.areas(in: county).isEmpty, county)
        }
        for area in PALocalTax.areas {
            XCTAssertTrue((0...0.05).contains(area.residentRate), area.municipality)
            XCTAssertTrue((0...0.05).contains(area.nonresidentRate), area.municipality)
            XCTAssertTrue((0...156).contains(area.lstAnnual), area.municipality)
        }

        // Berks County still has all 73 municipality/school district pairs.
        XCTAssertEqual(PALocalTax.areas(in: "Berks").count, 73)
        let reading = PALocalTax.area(psd: "061301")!
        XCTAssertEqual(reading.municipality, "Reading City")
        XCTAssertEqual(reading.residentRate, 0.036)
        XCTAssertEqual(reading.nonresidentRate, 0.01)
        XCTAssertEqual(reading.lstAnnual, 52)

        // Spot checks from the register outside Berks.
        let pittsburgh = PALocalTax.area(psd: "700102")!
        XCTAssertEqual(pittsburgh.county, "Allegheny")
        XCTAssertEqual(pittsburgh.residentRate, 0.03)
        let harrisburg = PALocalTax.area(psd: "220401")!
        XCTAssertEqual(harrisburg.county, "Dauphin")
        XCTAssertEqual(harrisburg.residentRate, 0.02)
        XCTAssertEqual(harrisburg.lstAnnual, 156)

        // A town split between school districts shows the district in its name.
        let wyomissing = PALocalTax.areas(in: "Berks").filter { $0.municipality == "Wyomissing Borough" }
        XCTAssertEqual(wyomissing.count, 2)
        XCTAssertTrue(wyomissing.allSatisfy { $0.displayName.contains("SD)") })

        // Bethlehem straddles Lehigh and Northampton counties and is listed under both.
        XCTAssertEqual(PALocalTax.area(psd: "480202", county: "Lehigh")?.county, "Lehigh")
        XCTAssertEqual(PALocalTax.area(psd: "480202", county: "Northampton")?.county, "Northampton")
    }

    func testSettingsSavedByOlderVersionsStillLoad() throws {
        // Berks-only version: no counties, and a job "OUTSIDE" Berks County.
        let old = """
        {"frequency":"weekly","w4":{"filingStatus":"marriedJointly","step2Checkbox":false,
         "dependentCredits":2000,"otherIncome":0,"deductions":0,"extraWithholding":10},
         "multipliers":{"overtime":1.5,"doubleTime":2,"tripleTime":3},
         "deductions":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"401(k)",
           "kind":"preTaxRetirement","amount":5,"isPercentOfGross":true}],
         "homePSD":"060601","workPSD":"OUTSIDE",
         "outsideWorkNonresidentRatePercent":1.5,"outsideWorkLSTAnnual":52,"lstExempt":true}
        """
        let p = try JSONDecoder().decode(PayProfile.self, from: Data(old.utf8))
        XCTAssertEqual(p.frequency, .weekly)
        XCTAssertEqual(p.w4.filingStatus, .marriedJointly)
        XCTAssertEqual(p.w4.extraWithholding, 10)
        XCTAssertEqual(p.deductions.count, 1)
        XCTAssertTrue(p.lstExempt)
        XCTAssertEqual(p.homeCounty, "Berks")
        XCTAssertEqual(p.homePSD, "060601")
        // The old "outside Berks" job falls back to where you live.
        XCTAssertEqual(p.workCounty, "Berks")
        XCTAssertEqual(p.workPSD, "060601")

        // And the new format round-trips.
        var q = PayProfile()
        q.workCounty = "Northampton"
        q.workPSD = "480202"
        let back = try JSONDecoder().decode(PayProfile.self, from: JSONEncoder().encode(q))
        XCTAssertEqual(back, q)
    }

    func testNoHoursMeansNoTaxesAndZeroTakeHome() {
        var hours = HoursInput()
        hours.hourlyRate = 25

        var profile = PayProfile()
        profile.homePSD = "061301" // Reading City: $52 LST
        profile.workPSD = "061301"

        let r = PayCalculator.calculate(hours: hours, profile: profile)
        XCTAssertEqual(r.grossPay, 0, accuracy: 0.001)
        XCTAssertEqual(r.localServicesTax, 0, accuracy: 0.001)
        XCTAssertEqual(r.totalTaxes, 0, accuracy: 0.001)
        XCTAssertEqual(r.netPay, 0, accuracy: 0.001)
    }
}
