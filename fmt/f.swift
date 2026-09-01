import Foundation

extension Int {
    /// Cents → localized currency text.
    var currencyFormat: String {
        (Decimal(self) / 100).formatted(
            .currency(code: Locale.current.currency?.identifier ?? "EUR")
        )
    }
}
extension Date {
    var transactionFormat: String { formatted(date: .abbreviated, time: .omitted) }
}
print(129999.currencyFormat, "|", Date(timeIntervalSince1970: 0).transactionFormat)
