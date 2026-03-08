// ============================================================
// THEME - Colors, fonts, spacing matching the web widget
// ============================================================

import UIKit

struct Theme {
    
    // MARK: - Colors (matching pg-wiget-v2 theme.ts)
    
    struct Colors {
        static let primary = UIColor(hex: "#084B83")
        static let primaryDark = UIColor(hex: "#063A66")
        static let primaryLight = UIColor(hex: "#0A5D9E")
        
        static let success = UIColor(hex: "#28A745")
        static let error = UIColor(hex: "#DC3545")
        static let warning = UIColor(hex: "#FFC107")
        static let info = UIColor(hex: "#17A2B8")
        
        static let background = UIColor.white
        static let backgroundAlt = UIColor(hex: "#EDF5FB")
        static let surface = UIColor.white
        
        static let text = UIColor(hex: "#333333")
        static let textLight = UIColor(hex: "#555555")
        static let textMuted = UIColor(hex: "#6C757D")
        static let inputLabel = UIColor(hex: "#344054")
        
        static let border = UIColor(hex: "#D0D5DD")
        static let borderLight = UIColor(hex: "#E9ECEF")
        
        static let overlay = UIColor.black.withAlphaComponent(0.5)
        static let sidebarBackground = UIColor(hex: "#F0F2F5")
        static let white = UIColor.white
        
        // Test banner
        static let testBannerBg = UIColor(hex: "#FEF3C7")
        static let testBannerBorder = UIColor(hex: "#F59E0B")
        static let testBannerText = UIColor(hex: "#B45309")
        
        // Drag handle
        static let dragHandle = UIColor(hex: "#E0E0E0")
    }
    
    // MARK: - Fonts (Lato on web, system font on iOS as close match)
    
    struct Fonts {
        static func regular(_ size: CGFloat) -> UIFont {
            .systemFont(ofSize: size, weight: .regular)
        }
        
        static func medium(_ size: CGFloat) -> UIFont {
            .systemFont(ofSize: size, weight: .medium)
        }
        
        static func semibold(_ size: CGFloat) -> UIFont {
            .systemFont(ofSize: size, weight: .semibold)
        }
        
        static func bold(_ size: CGFloat) -> UIFont {
            .systemFont(ofSize: size, weight: .bold)
        }
        
        // Named presets matching web font sizes
        static let title = bold(20)           // xl: 20px
        static let subtitle = semibold(16)    // lg: 16px
        static let body = regular(14)         // md/base: 14px
        static let caption = regular(12)      // sm: 12px
        static let captionSmall = regular(10) // xs: 10px
        static let button = medium(14)      // button text - web is font-weight: 500
        static let amount = bold(24)          // xxl: 24px
        static let tabLabel = regular(11)      // 0.7rem ≈ 11px, web is no explicit weight (default 400)
        static let inputLabel = medium(10)    // 10px weight 500
        static let businessName = semibold(13) // 0.8rem ≈ 13px weight 600
        static let productLabel = regular(12) // 0.75rem ≈ 12px
        static let productAmount = bold(14)   // 0.9rem ≈ 14px weight 700
    }
    
    // MARK: - Spacing (matching web theme)
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
    
    // MARK: - Corner Radius (matching web borderRadius)
    
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let full: CGFloat = 9999
        static let button: CGFloat = 8
        static let card: CGFloat = 16
        static let modal: CGFloat = 16       // 1rem
        static let modalMobile: CGFloat = 24  // 1.5rem
        static let tab: CGFloat = 14
        static let input: CGFloat = 5        // web InputWrapper 5px
    }
    
    // MARK: - Shadows (matching web shadows)
    
    struct Shadows {
        static func apply(to layer: CALayer, style: ShadowStyle) {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = style.opacity
            layer.shadowOffset = style.offset
            layer.shadowRadius = style.radius
            layer.masksToBounds = false
        }
        
        struct ShadowStyle {
            let opacity: Float
            let offset: CGSize
            let radius: CGFloat
        }
        
        static let sm = ShadowStyle(opacity: 0.05, offset: CGSize(width: 0, height: 1), radius: 1)
        static let md = ShadowStyle(opacity: 0.1, offset: CGSize(width: 0, height: 4), radius: 3)
        static let lg = ShadowStyle(opacity: 0.1, offset: CGSize(width: 0, height: 10), radius: 7.5)
        static let modal = ShadowStyle(opacity: 0.2, offset: CGSize(width: 0, height: 12), radius: 24)
        
        // Active tab shadow
        static let activeTab = ShadowStyle(opacity: 0.3, offset: CGSize(width: 0, height: 4), radius: 6)
    }
    
    // MARK: - Sizes
    
    struct Sizes {
        static let modalWidth: CGFloat = 420
        static let channelIconMobile: CGFloat = 38
        static let channelIconDesktop: CGFloat = 24
        static let logoSize: CGFloat = 65
        static let statusIconSize: CGFloat = 80
        static let dragHandleWidth: CGFloat = 36
        static let dragHandleHeight: CGFloat = 4
        static let closeButtonSize: CGFloat = 17
        static let inputHeight: CGFloat = 32
        static let buttonHeight: CGFloat = 32     // 2rem = 32px matching web PayButton
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat((rgb & 0x0000FF)) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
