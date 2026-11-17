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
        hours.regularHours = 80
        hours.overtimeHours = 4
        hours.doubleTimeHours = 2
        hours.tripleTimeHours = 1
        hours.vacationHours = 8
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
        // 3,200 + 240 + 160 + 120 + 320 + 40
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

        // Work outside Berks at a 1.5% non-resident rate with a $52 LST, exempt from LST.
        profile.homePSD = "060601"
        profile.workPSD = BerksCounty.outsideCountyPSD
        profile.outsideWorkNonresidentRatePercent = 1.5
        profile.outsideWorkLSTAnnual = 52
        profile.lstExempt = true
        t = PayCalculator.localTaxes(wages: 2_000, periodsPerYear: 24, profile: profile)
        XCTAssertEqual(t.eitRate, 0.015)
        XCTAssertEqual(t.eit, 30.00, accuracy: 0.001)
        XCTAssertEqual(t.lst, 0)
    }

    func testBerksTableIsComplete() {
        XCTAssertEqual(BerksCounty.areas.count, 73)
        XCTAssertEqual(Set(BerksCounty.areas.map(\.psd)).count, 73)
    }
}
