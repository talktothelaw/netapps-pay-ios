// ============================================================
// CHANNEL TABS VIEW - Matches web PaymentChannelTabs.tsx
// Mobile: horizontal scroll, 38x38 circular icons
// Active: white bg + primary icon + double ring
// Inactive: primary bg + white icon
// ============================================================

import UIKit

protocol ChannelTabsViewDelegate: AnyObject {
    func channelTabsView(_ view: ChannelTabsView, didSelect channel: PaymentChannel)
}

final class ChannelTabsView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: ChannelTabsViewDelegate?
    private var channels: [PaymentChannel] = []
    private var selectedChannel: PaymentChannel?
    private var tabButtons: [PaymentChannel: ChannelTabButton] = [:]
    private weak var store: PaymentStore?
    
    // MARK: - UI
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Payment Channel"
        label.font = Theme.Fonts.medium(12)  // sm: 12px
        label.textColor = Theme.Colors.text   // #333333
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8   // gap: 8px
        stack.alignment = .top
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Spacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.sm),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 66), // icon 38 + label ~14 + spacing
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }
    
    // MARK: - Configure
    
    func configure(channels: [PaymentChannel], selected: PaymentChannel? = nil, store: PaymentStore? = nil) {
        // Merchant order (the order channels were added to their profile), never
        // re-sorted card-first. De-duped so one tab is rendered per channel —
        // `tabButtons` is keyed by channel, so a repeated channel would leave
        // orphan buttons that can never show as selected.
        var seen = Set<PaymentChannel>()
        self.channels = channels.filter { seen.insert($0).inserted }
        self.selectedChannel = selected
        self.store = store
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tabButtons.removeAll()
        
        for channel in self.channels {
            let label = store?.getChannelDisplayName(channel) ?? channel.shortName
            let button = ChannelTabButton(channel: channel, label: label)
            button.isSelected = channel == selected
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            tabButtons[channel] = button
        }
    }
    
    func setSelected(_ channel: PaymentChannel) {
        selectedChannel = channel
        for (ch, button) in tabButtons {
            button.isSelected = ch == channel
        }
        // Auto-scroll to make the selected tab fully visible
        if let button = tabButtons[channel] {
            let buttonFrame = button.convert(button.bounds, to: scrollView)
            scrollView.scrollRectToVisible(buttonFrame.insetBy(dx: -12, dy: 0), animated: true)
        }
    }
    
    // MARK: - Actions
    
    @objc private func tabTapped(_ sender: ChannelTabButton) {
        guard let channel = sender.channel else { return }
        setSelected(channel)
        delegate?.channelTabsView(self, didSelect: channel)
    }
}

// MARK: - Channel Tab Button (matches web RoundButton + IconWrapper)

final class ChannelTabButton: UIControl {
    
    let channel: PaymentChannel?
    
    override var isSelected: Bool {
        didSet { updateAppearance() }
    }
    
    private let iconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 19 // 38/2 = circular
        view.layer.borderWidth = 2
        view.layer.borderColor = Theme.Colors.primary.cgColor
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let iconView: ChannelIconView = {
        let view = ChannelIconView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.tabLabel // 0.7rem = 11px
        label.textColor = Theme.Colors.textLight // #555555
        label.textAlignment = .center
        return label
    }()
    
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4  // margin-bottom: 4px
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
    }()
    
    init(channel: PaymentChannel, label: String? = nil) {
        self.channel = channel
        super.init(frame: .zero)
        setupUI()
        configure(channel: channel, label: label)
        updateAppearance()
    }
    
    required init?(coder: NSCoder) {
        self.channel = nil
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerStack)
        
        iconContainer.addSubview(iconView)
        containerStack.addArrangedSubview(iconContainer)
        containerStack.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // 38x38 icon circle
            iconContainer.widthAnchor.constraint(equalToConstant: 38),
            iconContainer.heightAnchor.constraint(equalToConstant: 38),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])
    }
    
    private func configure(channel: PaymentChannel, label: String? = nil) {
        titleLabel.text = label ?? channel.shortName
        iconView.channel = channel
    }
    
    private func updateAppearance() {
        UIView.animate(withDuration: 0.2) { [self] in
            if isSelected {
                // Active: white bg, primary icon, double ring shadow
                iconContainer.backgroundColor = .white
                iconView.iconColor = Theme.Colors.primary
                titleLabel.textColor = Theme.Colors.textLight  // stays #555 like web
                titleLabel.font = Theme.Fonts.medium(11)
                
                // Double ring: inner white + outer primary
                iconContainer.layer.shadowColor = Theme.Colors.primary.cgColor
                iconContainer.layer.shadowOpacity = 1.0
                iconContainer.layer.shadowOffset = .zero
                iconContainer.layer.shadowRadius = 0
                iconContainer.layer.shadowPath = nil
                
                // Use shadow to create outer ring effect
                let outerRingLayer = iconContainer.layer.sublayers?.first(where: { $0.name == "outerRing" })
                if outerRingLayer == nil {
                    let ring = CAShapeLayer()
                    ring.name = "outerRing"
                    ring.fillColor = UIColor.clear.cgColor
                    ring.strokeColor = Theme.Colors.primary.cgColor
                    ring.lineWidth = 2
                    let inset: CGFloat = -4
                    ring.path = UIBezierPath(ovalIn: CGRect(x: inset, y: inset, width: 38 - 2 * inset, height: 38 - 2 * inset)).cgPath
                    iconContainer.layer.addSublayer(ring)
                }
                iconContainer.layer.sublayers?.first(where: { $0.name == "outerRing" })?.isHidden = false
                
            } else {
                // Inactive: primary bg, white icon
                iconContainer.backgroundColor = Theme.Colors.primary
                iconView.iconColor = .white
                titleLabel.textColor = Theme.Colors.textLight  // #555555
                titleLabel.font = Theme.Fonts.tabLabel
                
                iconContainer.layer.shadowOpacity = 0
                iconContainer.layer.sublayers?.first(where: { $0.name == "outerRing" })?.isHidden = true
            }
        }
    }
}

// MARK: - Channel Icon View (draws SVG-equivalent paths)
// Matches the exact SVG icons from PaymentChannelTabs.tsx

final class ChannelIconView: UIView {
    
    var channel: PaymentChannel = .card {
        didSet { setNeedsDisplay() }
    }
    
    var iconColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        
        let scale = rect.width / 24.0  // viewBox is 0 0 24 24
        ctx.scaleBy(x: scale, y: scale)
        
        iconColor.setStroke()
        iconColor.setFill()
        
        switch channel {
        case .card:
            drawCardIcon(ctx)
        case .transfer:
            drawBankIcon(ctx)
        case .ussd:
            drawUSSDIcon(ctx)
        case .payattitude:
            drawPayAttitudeIcon(ctx)
        case .moniflow:
            drawMarketplaceIcon(ctx)
        }
    }
    
    // Card: rect x=2 y=5 w=20 h=14 rx=2, line x1=2 y1=10 x2=22 y2=10
    private func drawCardIcon(_ ctx: CGContext) {
        let path = UIBezierPath(roundedRect: CGRect(x: 2, y: 5, width: 20, height: 14), cornerRadius: 2)
        path.lineWidth = 2
        path.stroke()
        
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 2, y: 10))
        line.addLine(to: CGPoint(x: 22, y: 10))
        line.lineWidth = 2
        line.stroke()
    }
    
    // Bank: building with columns
    private func drawBankIcon(_ ctx: CGContext) {
        let lineWidth: CGFloat = 2
        
        // Floor: M3 21h18
        let floor = UIBezierPath()
        floor.move(to: CGPoint(x: 3, y: 21))
        floor.addLine(to: CGPoint(x: 21, y: 21))
        floor.lineWidth = lineWidth; floor.lineCapStyle = .round; floor.stroke()
        
        // Top: M3 10h18
        let top = UIBezierPath()
        top.move(to: CGPoint(x: 3, y: 10))
        top.addLine(to: CGPoint(x: 21, y: 10))
        top.lineWidth = lineWidth; top.lineCapStyle = .round; top.stroke()
        
        // Roof: M5 6l7-3 7 3
        let roof = UIBezierPath()
        roof.move(to: CGPoint(x: 5, y: 6))
        roof.addLine(to: CGPoint(x: 12, y: 3))
        roof.addLine(to: CGPoint(x: 19, y: 6))
        roof.lineWidth = lineWidth; roof.lineCapStyle = .round; roof.stroke()
        
        // Left pillar: M4 10v11
        let lp = UIBezierPath()
        lp.move(to: CGPoint(x: 4, y: 10)); lp.addLine(to: CGPoint(x: 4, y: 21))
        lp.lineWidth = lineWidth; lp.lineCapStyle = .round; lp.stroke()
        
        // Right pillar: M20 10v11
        let rp = UIBezierPath()
        rp.move(to: CGPoint(x: 20, y: 10)); rp.addLine(to: CGPoint(x: 20, y: 21))
        rp.lineWidth = lineWidth; rp.lineCapStyle = .round; rp.stroke()
        
        // Middle pillars: M8 14v3, M12 14v3, M16 14v3
        for x: CGFloat in [8, 12, 16] {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: x, y: 14)); p.addLine(to: CGPoint(x: x, y: 17))
            p.lineWidth = lineWidth; p.lineCapStyle = .round; p.stroke()
        }
    }
    
    // USSD: phone rect
    private func drawUSSDIcon(_ ctx: CGContext) {
        let path = UIBezierPath(roundedRect: CGRect(x: 5, y: 2, width: 14, height: 20), cornerRadius: 2)
        path.lineWidth = 2
        path.stroke()
        
        // Dot at bottom: line x1=12 y1=18 x2=12 y2=18 (a dot)
        let dot = UIBezierPath(ovalIn: CGRect(x: 11, y: 17, width: 2, height: 2))
        dot.fill()
    }
    
    // PayAttitude: card with circle and line
    private func drawPayAttitudeIcon(_ ctx: CGContext) {
        let path = UIBezierPath(roundedRect: CGRect(x: 2, y: 4, width: 20, height: 16), cornerRadius: 2)
        path.lineWidth = 2
        path.stroke()
        
        let circle = UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 6, height: 6))
        circle.lineWidth = 2
        circle.stroke()
        
        let line = UIBezierPath()
        line.move(to: CGPoint(x: 2, y: 10))
        line.addLine(to: CGPoint(x: 22, y: 10))
        line.lineWidth = 2
        line.stroke()
    }
    
    // Marketplace: hexagonal 3D shape (viewBox 0 0 4 5)
    private func drawMarketplaceIcon(_ ctx: CGContext) {
        // Scale is already applied for 24x24 viewBox,
        // but marketplace uses viewBox="0 0 4 5" with width="60%"
        // Let's rescale for the 0-4 x 0-5 coordinate system
        ctx.saveGState()
        // Reset the 24x24 scale and apply 4x5 scale
        let currentScale = bounds.width / 24.0
        ctx.scaleBy(x: 1.0/currentScale, y: 1.0/currentScale)
        let s = bounds.width / 4.0
        ctx.scaleBy(x: s, y: s)
        
        // Outer hexagon outline
        let outer = UIBezierPath()
        outer.move(to: CGPoint(x: 1.952, y: 0))
        outer.addLine(to: CGPoint(x: 3.904, y: 1.086))
        outer.addLine(to: CGPoint(x: 3.904, y: 3.261))
        outer.addLine(to: CGPoint(x: 1.952, y: 4.347))
        outer.addLine(to: CGPoint(x: 0, y: 3.261))
        outer.addLine(to: CGPoint(x: 0, y: 1.086))
        outer.close()
        
        let inner = UIBezierPath()
        inner.move(to: CGPoint(x: 1.952, y: 0.389))
        inner.addLine(to: CGPoint(x: 3.554, y: 1.281))
        inner.addLine(to: CGPoint(x: 3.554, y: 3.066))
        inner.addLine(to: CGPoint(x: 1.952, y: 3.958))
        inner.addLine(to: CGPoint(x: 0.350, y: 3.066))
        inner.addLine(to: CGPoint(x: 0.350, y: 1.281))
        inner.close()
        
        outer.append(inner.reversing())
        outer.usesEvenOddFillRule = true
        outer.fill()
        
        // Left face
        let left = UIBezierPath()
        left.move(to: CGPoint(x: 0.555, y: 1.581))
        left.addLine(to: CGPoint(x: 1.924, y: 2.302))
        left.addLine(to: CGPoint(x: 1.924, y: 3.702))
        left.addLine(to: CGPoint(x: 0.555, y: 2.981))
        left.close()
        left.fill()
        
        // Top face
        let topFace = UIBezierPath()
        topFace.move(to: CGPoint(x: 0.648, y: 1.335))
        topFace.addLine(to: CGPoint(x: 1.929, y: 0.660))
        topFace.addLine(to: CGPoint(x: 3.149, y: 1.339))
        topFace.addLine(to: CGPoint(x: 1.984, y: 2.034))
        topFace.close()
        topFace.fill()
        
        // Right bottom face
        let rb = UIBezierPath()
        rb.move(to: CGPoint(x: 2.121, y: 2.433))
        rb.addLine(to: CGPoint(x: 3.038, y: 3.125))
        rb.addLine(to: CGPoint(x: 2.148, y: 3.620))
        rb.close()
        rb.fill()
        
        // Right top face
        let rt = UIBezierPath()
        rt.move(to: CGPoint(x: 2.162, y: 2.190))
        rt.addLine(to: CGPoint(x: 3.256, y: 2.959))
        rt.addLine(to: CGPoint(x: 3.294, y: 1.486))
        rt.close()
        rt.fill()
        
        ctx.restoreGState()
    }
    
}
