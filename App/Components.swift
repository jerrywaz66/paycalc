import SwiftUI
import UIKit
import PayCalcCore

/// A labeled number field. `prefix` is shown before the field ("$"), `suffix` after ("hrs", "%").
///
/// A value of 0 shows as an empty field with a grey "0" placeholder, so tapping it
/// lets you type straight away instead of typing next to a real zero.
struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var prefix: String? = nil
    var suffix: String? = nil

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let prefix { Text(prefix).foregroundStyle(.secondary) }
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .focused($isFocused)
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
        // Tapping anywhere on the row opens the field, not just the small number itself.
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear { text = Self.display(value) }
        // Typing updates the number live, so take-home pay recalculates as you type.
        .onChange(of: text) { _, newText in
            let parsed = Self.parse(newText)
            if parsed != value { value = parsed }
        }
        // The number changed from outside (e.g. "Clear hours"): show the new value.
        .onChange(of: value) { _, newValue in
            if Self.parse(text) != newValue { text = Self.display(newValue) }
        }
        // Tidy up when you leave the field, e.g. "8." becomes "8".
        .onChange(of: isFocused) { _, focused in
            if !focused { text = Self.display(value) }
        }
    }

    private static func display(_ value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }

    private static func parse(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
}

struct AmountRow: View {
    let title: String
    var detail: String? = nil
    let amount: Double
    var negative = false
    var bold = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(negative ? "−\(amount.currency)" : amount.currency)
                .monospacedDigit()
        }
        .fontWeight(bold ? .semibold : .regular)
    }
}

/// Adds a "Done" button above the decimal keyboard, which has no return key.
struct KeyboardDoneButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
                }
            }
    }
}

extension View {
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneButton()) }
}

extension Double {
    var multiplierLabel: String { "\(trimmed)×" }
}
