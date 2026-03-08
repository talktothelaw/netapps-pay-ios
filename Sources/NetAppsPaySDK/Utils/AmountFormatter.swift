// ============================================================
// AMOUNT FORMATTER - Display amounts in currency format
// ============================================================

import Foundation

struct AmountFormatter {
    
    /// Formats an amount to a display string.
    /// e.g. 1500 NGN → "₦1,500.00"
    static func format(amount: Double, currency: Currency) -> String {
        let majorAmount = amount
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        
        let symbol = currencySymbol(for: currency)
        let formatted = formatter.string(from: NSNumber(value: majorAmount)) ?? String(format: "%.2f", majorAmount)
        
        return "\(symbol)\(formatted)"
    }
    
    /// Returns the currency symbol.
    static func currencySymbol(for currency: Currency) -> String {
        switch currency {
        case .NGN: return "₦"
        case .USD: return "$"
        }
    }
    
    /// Formats for compact display (e.g. transaction summary).
    static func formatCompact(amount: Double, currency: Currency) -> String {
        let majorAmount = amount
        let symbol = currencySymbol(for: currency)
        
        if majorAmount >= 1_000_000 {
            return "\(symbol)\(String(format: "%.1fM", majorAmount / 1_000_000))"
        } else if majorAmount >= 1_000 {
            return "\(symbol)\(String(format: "%.1fK", majorAmount / 1_000))"
        } else {
            return format(amount: amount, currency: currency)
        }
    }
}
