import SwiftUI
import PayCalcCore

struct CalculatorView: View {
    @EnvironmentObject private var store: PayStore

    var body: some View {
        let result = store.result
        let m = store.profile.multipliers

        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Text("Take-home pay").font(.subheadline).foregroundStyle(.secondary)
                        Text(result.netPay.currency)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("Gross \(result.grossPay.currency) · \(store.profile.frequency.label)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                Section("Pay rate") {
                    NumberRow(title: "Hourly rate", value: $store.hours.hourlyRate, prefix: "$")
                }

                Section("Hours") {
                    NumberRow(title: "Regular", value: $store.hours.regularHours, suffix: "hrs")
                    NumberRow(title: "Overtime (\(m.overtime.multiplierLabel))", value: $store.hours.overtimeHours, suffix: "hrs")
                    NumberRow(title: "Double time (\(m.doubleTime.multiplierLabel))", value: $store.hours.doubleTimeHours, suffix: "hrs")
                    NumberRow(title: "Triple time (\(m.tripleTime.multiplierLabel))", value: $store.hours.tripleTimeHours, suffix: "hrs")
                    NumberRow(title: "Vacation", value: $store.hours.vacationHours, suffix: "hrs")
                }

                Section {
                    NumberRow(title: "Differential hours", value: $store.hours.shiftDifferentialHours, suffix: "hrs")
                    NumberRow(title: "Extra per hour", value: $store.hours.shiftDifferentialRate, prefix: "$")
                } header: {
                    Text("Shift differential")
                } footer: {
                    Text("Added on top of the pay above, for the hours that earn the differential.")
                }

                Section("Earnings") {
                    ForEach(result.earnings) { AmountRow(title: $0.label, detail: $0.detail, amount: $0.amount) }
                    AmountRow(title: "Gross pay", amount: result.grossPay, bold: true)
                }

                Section("Taxes") {
                    ForEach(result.taxes) { AmountRow(title: $0.label, detail: $0.detail, amount: $0.amount, negative: true) }
                    AmountRow(title: "Total taxes", amount: result.totalTaxes, negative: true, bold: true)
                }

                if !result.deductions.isEmpty {
                    Section("Deductions") {
                        ForEach(result.deductions) { AmountRow(title: $0.label, detail: $0.detail, amount: $0.amount, negative: true) }
                        AmountRow(title: "Total deductions", amount: result.totalDeductions, negative: true, bold: true)
                    }
                }

                Section {
                    AmountRow(title: "Net pay", amount: result.netPay, bold: true)
                }

                if result.qualifiedOvertimePremium > 0 {
                    Section {
                        AmountRow(title: "Overtime premium that qualifies", amount: result.qualifiedOvertimePremium)
                        AmountRow(title: "Estimated federal tax saved",
                                  detail: "At your \(Int((result.federalMarginalRate * 100).rounded()))% bracket",
                                  amount: result.estimatedOvertimeTaxSavings)
                    } header: {
                        Text("No tax on overtime (estimate)")
                    } footer: {
                        Text("Only the extra half of time-and-a-half counts. This deduction is claimed when you file your return, so it isn't taken off this paycheck. Annual cap: \(TaxTables2026.overtimeDeductionCapSingle.currency) single, \(TaxTables2026.overtimeDeductionCapMarried.currency) married filing jointly.")
                    }
                }

                Section {
                    NumberRow(title: "Earned so far this year", value: $store.ytdFicaWages, prefix: "$")
                } header: {
                    Text("Year to date (optional)")
                } footer: {
                    Text("Social Security stops at \(TaxTables2026.socialSecurityWageBase.currency) a year, and an extra 0.9% Medicare starts over \(TaxTables2026.additionalMedicareThreshold.currency). Only matters for high earners.")
                }
            }
            .navigationTitle("PayCalc")
            .toolbar {
                Button("Clear hours") { store.hours.clearHours() }
            }
            .keyboardDoneButton()
            .animation(.default, value: result.netPay)
        }
    }
}
