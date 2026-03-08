// ============================================================
// CARD BRAND DETECTOR - Matches web card-validator BIN detection
// Detects card brand from BIN (first 6-8 digits), validates
// with Luhn algorithm, provides max lengths per brand.
// ============================================================

import UIKit

/// Card brands supported by the payment gateway (matches web SUPPORTED_CARD_BRANDS).
enum CardBrand: String {
    case visa
    case mastercard
    case verve
    case americanExpress = "american-express"
    case discover
    case unionpay
    case unknown
    
    /// Valid card number lengths for this brand.
    var validLengths: [Int] {
        switch self {
        case .visa: return [16, 19]
        case .mastercard: return [16]
        case .verve: return [16, 18, 19]
        case .americanExpress: return [15]
        case .discover: return [16, 19]
        case .unionpay: return [16, 17, 18, 19]
        case .unknown: return [16, 17, 18, 19]
        }
    }
    
    /// Maximum digit length for this brand.
    var maxLength: Int {
        validLengths.max() ?? 19
    }
    
    /// CVV length for this brand.
    var cvvLength: Int {
        switch self {
        case .americanExpress: return 4
        default: return 3
        }
    }
    
    /// Display name.
    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .verve: return "Verve"
        case .americanExpress: return "Amex"
        case .discover: return "Discover"
        case .unionpay: return "UnionPay"
        case .unknown: return "Card"
        }
    }
}

/// Detects card brand from BIN and validates card numbers.
/// Matches the web's `card-validator` library behavior.
struct CardBrandDetector {
    
    /// Detect card brand from the first digits of a card number.
    static func detect(from cardNumber: String) -> CardBrand {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        guard !digits.isEmpty else { return .unknown }
        
        // Verve: BIN ranges 506099-506198 and 650002-650027
        // Must check before Discover (which starts with 65)
        if digits.count >= 6 {
            if let bin6 = Int(String(digits.prefix(6))) {
                if (bin6 >= 506099 && bin6 <= 506198) || (bin6 >= 650002 && bin6 <= 650027) {
                    return .verve
                }
            }
        } else if digits.count >= 4 {
            // Partial match for Verve while typing
            let prefix4 = String(digits.prefix(4))
            if prefix4 >= "5060" && prefix4 <= "5061" { return .verve }
            if prefix4 == "6500" { return .verve }
        }
        
        let first = digits.first!
        let prefix2 = digits.count >= 2 ? String(digits.prefix(2)) : ""
        let prefix4 = digits.count >= 4 ? String(digits.prefix(4)) : ""
        
        // American Express: starts with 34 or 37
        if prefix2 == "34" || prefix2 == "37" {
            return .americanExpress
        }
        
        // Visa: starts with 4
        if first == "4" {
            return .visa
        }
        
        // Mastercard: starts with 51-55 or 2221-2720
        if let p2 = Int(prefix2), p2 >= 51 && p2 <= 55 {
            return .mastercard
        }
        if digits.count >= 4, let p4 = Int(prefix4), p4 >= 2221 && p4 <= 2720 {
            return .mastercard
        }
        
        // Discover: starts with 6011, 644-649, 65
        if prefix4 == "6011" { return .discover }
        if digits.count >= 3 {
            let prefix3 = String(digits.prefix(3))
            if let p3 = Int(prefix3), p3 >= 644 && p3 <= 649 {
                return .discover
            }
        }
        if prefix2 == "65" { return .discover }
        
        // UnionPay: starts with 62
        if prefix2 == "62" { return .unionpay }
        
        return .unknown
    }
    
    /// Luhn algorithm validation.
    static func luhnCheck(_ cardNumber: String) -> Bool {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        guard digits.count >= 13 else { return false }
        guard digits.allSatisfy({ $0.isNumber }) else { return false }
        
        var sum = 0
        let reversed = digits.reversed().enumerated()
        for (index, char) in reversed {
            guard let digit = char.wholeNumberValue else { return false }
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }
    
    /// Full validation: correct length for brand + Luhn check.
    static func isValid(_ cardNumber: String) -> Bool {
        let digits = cardNumber.replacingOccurrences(of: " ", with: "")
        let brand = detect(from: digits)
        guard brand.validLengths.contains(digits.count) else { return false }
        // UnionPay doesn't always pass Luhn
        if brand == .unionpay { return true }
        return luhnCheck(digits)
    }
}

// MARK: - Card Brand Icon View (CoreGraphics-drawn, matches web CardBrandIcon)

final class CardBrandIconView: UIView {
    
    var brand: CardBrand = .unknown {
        didSet {
            if brand != oldValue { setNeedsDisplay() }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        
        let w = rect.width
        let h = rect.height
        
        switch brand {
        case .visa:
            drawVisa(ctx, in: rect)
        case .mastercard:
            drawMastercard(ctx, in: rect)
        case .verve:
            drawVerve(ctx, in: rect)
        case .americanExpress:
            drawAmex(ctx, in: rect)
        case .discover:
            drawDiscover(ctx, in: rect)
        case .unionpay:
            drawUnionPay(ctx, in: rect)
        case .unknown:
            drawGenericCard(ctx, in: rect)
        }
        
        ctx.restoreGState()
    }
    
    // MARK: - Visa: Blue "V" text
    private func drawVisa(_ ctx: CGContext, in rect: CGRect) {
        let visaBlue = UIColor(red: 26/255, green: 31/255, blue: 113/255, alpha: 1)
        
        // Background rounded rect
        let bg = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3)
        UIColor.white.setFill()
        bg.fill()
        visaBlue.setStroke()
        bg.lineWidth = 0.5
        bg.stroke()
        
        // "VISA" text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.45, weight: .bold),
            .foregroundColor: visaBlue
        ]
        let text = "VISA"
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
    
    // MARK: - Mastercard: Two overlapping circles (red + orange)
    private func drawMastercard(_ ctx: CGContext, in rect: CGRect) {
        let bg = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3)
        UIColor.white.setFill()
        bg.fill()
        UIColor(hex: "#D0D5DD").setStroke()
        bg.lineWidth = 0.5
        bg.stroke()
        
        let circleR = rect.height * 0.3
        let cx = rect.midX
        let cy = rect.midY
        let offset = circleR * 0.6
        
        // Red circle (left)
        ctx.setFillColor(UIColor(red: 235/255, green: 0, blue: 27/255, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - offset - circleR, y: cy - circleR, width: circleR * 2, height: circleR * 2))
        
        // Orange circle (right) with blend
        ctx.setFillColor(UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + offset - circleR, y: cy - circleR, width: circleR * 2, height: circleR * 2))
    }
    
    // MARK: - Verve: Green "V" text
    private func drawVerve(_ ctx: CGContext, in rect: CGRect) {
        let verveGreen = UIColor(red: 0, green: 120/255, blue: 70/255, alpha: 1)
        
        let bg = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3)
        UIColor.white.setFill()
        bg.fill()
        verveGreen.setStroke()
        bg.lineWidth = 0.5
        bg.stroke()
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.38, weight: .bold),
            .foregroundColor: verveGreen
        ]
        let text = "Verve"
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
    
    // MARK: - Amex: Blue "AMEX" text
    private func drawAmex(_ ctx: CGContext, in rect: CGRect) {
        let amexBlue = UIColor(red: 0, green: 111/255, blue: 207/255, alpha: 1)
        
        let bg = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3)
        amexBlue.setFill()
        bg.fill()
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.32, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let text = "AMEX"
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
    
    // MARK: - Discover: "D" with orange accent
    private func drawDiscover(_ ctx: CGContext, in rect: CGRect) {
        let bg = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 3)
        UIColor.white.setFill()
        bg.fill()
        UIColor(hex: "#D0D5DD").setStroke()
        bg.lineWidth = 0.5
        bg.stroke()
        
        // Orange circle
        let circleR = rect.height * 0.25
        ctx.setFillColor(UIColor(red: 255/255, green: 96/255, blue: 0, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.midX - circleR, y: rect.midY - circleR, width: circleR * 2, height: circleR * 2))
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.3, weight: .bold),
            .foregroundColor: UIColor(red: 40/255, green: 40/255, blue: 40/255, alpha: 1)
        ]
        let text = "D"
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
    
    // MARK: - UnionPay: Red/Blue split
    private func drawUnionPay(_ ctx: CGContext, in rect: CGRect) {
        let inset = rect.insetBy(dx: 1, dy: 1)
        let path = UIBezierPath(roundedRect: inset, cornerRadius: 3)
        
        // Red left half
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.setFillColor(UIColor(red: 226/255, green: 28/255, blue: 33/255, alpha: 1).cgColor)
        ctx.fill(CGRect(x: inset.minX, y: inset.minY, width: inset.width / 2, height: inset.height))
        ctx.setFillColor(UIColor(red: 0, green: 51/255, blue: 153/255, alpha: 1).cgColor)
        ctx.fill(CGRect(x: inset.midX, y: inset.minY, width: inset.width / 2, height: inset.height))
        ctx.restoreGState()
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: rect.height * 0.25, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        let text = "UP"
        let size = text.size(withAttributes: attrs)
        let origin = CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2)
        text.draw(at: origin, withAttributes: attrs)
    }
    
    // MARK: - Generic card icon
    private func drawGenericCard(_ ctx: CGContext, in rect: CGRect) {
        let inset = rect.insetBy(dx: 2, dy: 3)
        let cardPath = UIBezierPath(roundedRect: inset, cornerRadius: 2)
        UIColor(hex: "#667085").setStroke()
        cardPath.lineWidth = 1.5
        cardPath.stroke()
        
        // Stripe line
        let stripe = UIBezierPath()
        stripe.move(to: CGPoint(x: inset.minX, y: inset.minY + inset.height * 0.35))
        stripe.addLine(to: CGPoint(x: inset.maxX, y: inset.minY + inset.height * 0.35))
        stripe.lineWidth = 1.5
        stripe.stroke()
    }
}
