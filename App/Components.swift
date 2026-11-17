import SwiftUI
import UIKit
import PayCalcCore

/// A labeled number field. `prefix` is shown before the field ("$"), `suffix` after ("hrs", "%").
struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var prefix: String? = nil
    var suffix: String? = nil

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let prefix { Text(prefix).foregroundStyle(.secondary) }
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            if let suffix { Text(suffix).foregroundStyle(.secondary) }
        }
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
