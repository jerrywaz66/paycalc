import SwiftUI
import PayCalcCore

/// A Settings row ("I live in", "I work in") that shows the chosen town and county, and
/// opens a picker: choose a county, then a town. Search finds any town statewide.
struct LocationRow: View {
    let title: String
    @Binding var county: String
    @Binding var psd: String

    @State private var isPicking = false

    private var area: LocalTaxArea? { PALocalTax.area(psd: psd, county: county) }

    var body: some View {
        Button {
            isPicking = true
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(area?.displayName ?? "Choose").foregroundStyle(.secondary)
                    if let area {
                        Text("\(area.county) County").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        // Plain style keeps the row black-on-white like other settings, not blue link text.
        .buttonStyle(.plain)
        .sheet(isPresented: $isPicking) {
            LocationPicker(title: title, selectedCounty: county, selectedPSD: psd) { picked in
                county = picked.county
                psd = picked.psd
                isPicking = false
            }
        }
    }
}

/// Step 1: pick a county (or search every town in Pennsylvania).
struct LocationPicker: View {
    let title: String
    let selectedCounty: String
    let selectedPSD: String
    let onPick: (LocalTaxArea) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var townMatches: [LocalTaxArea] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return [] }
        return PALocalTax.areas.filter {
            $0.municipality.localizedCaseInsensitiveContains(query)
        }
    }

    private var countyMatches: [String] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? PALocalTax.counties
            : PALocalTax.counties.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !countyMatches.isEmpty {
                    Section(search.isEmpty ? "Counties" : "Counties matching") {
                        ForEach(countyMatches, id: \.self) { county in
                            NavigationLink(value: county) {
                                HStack {
                                    Text(county)
                                    Spacer()
                                    if county == selectedCounty {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
                if !townMatches.isEmpty {
                    Section("Towns matching") {
                        ForEach(townMatches) { area in
                            TownRow(area: area, showCounty: true,
                                    isSelected: area.psd == selectedPSD && area.county == selectedCounty) {
                                onPick(area)
                            }
                        }
                    }
                }
                if search.isEmpty {
                    Section {
                    } footer: {
                        Text("Philadelphia isn't supported yet. Its wage tax works differently from other Pennsylvania local taxes.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "County or town")
            .navigationDestination(for: String.self) { county in
                TownList(county: county, selectedCounty: selectedCounty, selectedPSD: selectedPSD, onPick: onPick)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Step 2: pick a town in the chosen county.
private struct TownList: View {
    let county: String
    let selectedCounty: String
    let selectedPSD: String
    let onPick: (LocalTaxArea) -> Void

    @State private var search = ""

    private var towns: [LocalTaxArea] {
        let all = PALocalTax.areas(in: county)
        let query = search.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? all : all.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(towns) { area in
            TownRow(area: area, showCounty: false,
                    isSelected: area.psd == selectedPSD && area.county == selectedCounty) {
                onPick(area)
            }
        }
        .navigationTitle("\(county) County")
        .searchable(text: $search, prompt: "Town")
    }
}

private struct TownRow: View {
    let area: LocalTaxArea
    let showCounty: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    // In a county's list the school district is already on the second line.
                    Text(showCounty ? area.displayName : area.municipality).foregroundStyle(.primary)
                    Text(showCounty ? "\(area.county) County" : area.schoolDistrict)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
