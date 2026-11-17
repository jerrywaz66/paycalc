import SwiftUI
import PayCalcCore

struct SettingsView: View {
    @EnvironmentObject private var store: PayStore

    private var localFooter: String {
        let p = store.profile
        let t = PayCalculator.localTaxes(wages: 0, periodsPerYear: p.frequency.periodsPerYear, profile: p)
        let lst = p.lstExempt ? "no Local Services Tax" : "\(t.lstAnnual.currency)/yr Local Services Tax"
        return "Withholding \((t.eitRate * 100).trimmed)% earned income tax (the higher of where you live and where you work) and \(lst). The LST exemption applies if you expect to earn under $12,000 at this job and filed an exemption form. PA income tax (3.07%) and PA unemployment (0.07%) are always applied."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pay schedule") {
                    Picker("Paid", selection: $store.profile.frequency) {
                        ForEach(PayFrequency.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    Picker("Filing status", selection: $store.profile.w4.filingStatus) {
                        ForEach(FilingStatus.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Step 2: multiple jobs box checked", isOn: $store.profile.w4.step2Checkbox)
                    NumberRow(title: "Step 3: dependents", value: $store.profile.w4.dependentCredits, prefix: "$")
                    NumberRow(title: "Step 4(a): other income", value: $store.profile.w4.otherIncome, prefix: "$")
                    NumberRow(title: "Step 4(b): deductions", value: $store.profile.w4.deductions, prefix: "$")
                    NumberRow(title: "Step 4(c): extra per check", value: $store.profile.w4.extraWithholding, prefix: "$")
                } header: {
                    Text("Federal W-4")
                } footer: {
                    Text("Copy these from the W-4 you gave your employer. Steps 3, 4(a) and 4(b) are yearly amounts; 4(c) is per paycheck.")
                }

                Section {
                    Picker("I live in", selection: $store.profile.homePSD) {
                        ForEach(BerksCounty.areas) { Text($0.displayName).tag($0.psd) }
                    }
                    Picker("I work in", selection: $store.profile.workPSD) {
                        ForEach(BerksCounty.areas) { Text($0.displayName).tag($0.psd) }
                        Text("Outside Berks County").tag(BerksCounty.outsideCountyPSD)
                    }
                    if store.profile.workPSD == BerksCounty.outsideCountyPSD {
                        NumberRow(title: "Work non-resident EIT", value: $store.profile.outsideWorkNonresidentRatePercent, suffix: "%")
                        NumberRow(title: "Work LST per year", value: $store.profile.outsideWorkLSTAnnual, prefix: "$")
                    }
                    Toggle("Exempt from Local Services Tax", isOn: $store.profile.lstExempt)
                } header: {
                    Text("Berks County local tax")
                } footer: {
                    Text(localFooter)
                }

                Section {
                    NumberRow(title: "Overtime", value: $store.profile.multipliers.overtime, suffix: "×")
                    NumberRow(title: "Double time", value: $store.profile.multipliers.doubleTime, suffix: "×")
                    NumberRow(title: "Triple time", value: $store.profile.multipliers.tripleTime, suffix: "×")
                } header: {
                    Text("Pay multipliers")
                } footer: {
                    Text("Change these if your contract pays a different rate.")
                }

                Section {
                    ForEach($store.profile.deductions) { $deduction in
                        NavigationLink {
                            DeductionEditor(deduction: $deduction)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(deduction.name.isEmpty ? "Untitled" : deduction.name)
                                    Text(deduction.kind.shortLabel).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(deduction.isPercentOfGross ? "\(deduction.amount.trimmed)%" : deduction.amount.currency)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.profile.deductions.remove(atOffsets: $0) }

                    Button {
                        store.profile.deductions.append(Deduction(name: "", kind: .preTaxHealth, amount: 0))
                    } label: {
                        Label("Add deduction", systemImage: "plus")
                    }
                } header: {
                    Text("Paycheck deductions")
                } footer: {
                    Text("Swipe left to delete.")
                }

                Section {
                    Text("Federal withholding uses the IRS Publication 15-T (\(String(TaxTables2026.year))) percentage method. Results are estimates. Your employer's payroll may round differently.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .keyboardDoneButton()
        }
    }
}

struct DeductionEditor: View {
    @Binding var deduction: Deduction

    var body: some View {
        Form {
            Section {
                TextField("Name (e.g. Medical, 401k)", text: $deduction.name)
            }
            Section {
                Picker("Type", selection: $deduction.kind) {
                    ForEach(DeductionKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Type")
            } footer: {
                Text(footer)
            }
            Section {
                Picker("Amount is", selection: $deduction.isPercentOfGross) {
                    Text("Dollars").tag(false)
                    Text("% of gross").tag(true)
                }
                .pickerStyle(.segmented)
                NumberRow(title: "Per paycheck", value: $deduction.amount,
                          prefix: deduction.isPercentOfGross ? nil : "$",
                          suffix: deduction.isPercentOfGross ? "%" : nil)
            }
        }
        .navigationTitle(deduction.name.isEmpty ? "Deduction" : deduction.name)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
    }

    private var footer: String {
        switch deduction.kind {
        case .preTaxHealth: return "Lowers federal, Social Security, Medicare, PA and local tax."
        case .preTaxRetirement: return "Lowers federal income tax only. Social Security, Medicare, PA and local tax still apply."
        case .postTax: return "Taken out after all taxes."
        }
    }
}
