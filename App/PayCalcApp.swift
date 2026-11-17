import SwiftUI
import PayCalcCore

@main
struct PayCalcApp: App {
    @StateObject private var store = PayStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                CalculatorView()
                    .tabItem { Label("Calculate", systemImage: "dollarsign.circle") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environmentObject(store)
        }
    }
}

/// Holds the saved profile and the last hours entered, and saves them on every change.
@MainActor
final class PayStore: ObservableObject {
    @Published var profile: PayProfile { didSet { save(profile, key: Keys.profile) } }
    @Published var hours: HoursInput { didSet { save(hours, key: Keys.hours) } }
    @Published var ytdFicaWages: Double { didSet { UserDefaults.standard.set(ytdFicaWages, forKey: Keys.ytd) } }

    private enum Keys {
        static let profile = "profile.v1"
        static let hours = "hours.v1"
        static let ytd = "ytd.v1"
    }

    init() {
        profile = Self.load(PayProfile.self, key: Keys.profile) ?? PayProfile()
        hours = Self.load(HoursInput.self, key: Keys.hours) ?? HoursInput()
        ytdFicaWages = UserDefaults.standard.double(forKey: Keys.ytd)
    }

    var result: PayResult {
        PayCalculator.calculate(hours: hours, profile: profile, ytdFicaWages: ytdFicaWages)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
