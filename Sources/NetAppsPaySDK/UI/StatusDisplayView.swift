// ============================================================
// STATUS DISPLAY VIEW - Matches web StatusDisplay.tsx
// Success: green checkmark, "Success!" title, amount, "Done" button
// Failed: red X, "Failed" title, message, "Close" button
// Error: red X, "Error" title, "Try Again" + "Close" buttons
// Fade-in + pulse animation like web
// ============================================================

import UIKit

protocol StatusDisplayViewDelegate: AnyObject {
    func statusDisplayViewDidTapAction(_ view: StatusDisplayView)
}

final class StatusDisplayView: UIView {
    
    weak var delegate: StatusDisplayViewDelegate?
    private var actionHandler: (() -> Void)?
    private var retryHandler: (() -> Void)?
    
    // MARK: - UI
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.background
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Animated icon (80x80 matching web's 80px GIF size)
    private let iconContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statusIconView: StatusIconDrawingView = {
        let view = StatusIconDrawingView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.title // 20px bold
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.body // 14px
        label.textColor = Theme.Colors.textLight // #555555
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.amount // 24px bold
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.sm
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var primaryButton: PrimaryButton?
    private var secondaryButton: PrimaryButton?
    
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
        addSubview(containerView)
        containerView.addSubview(contentStack)
        
        iconContainerView.addSubview(statusIconView)
        contentStack.addArrangedSubview(iconContainerView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.addArrangedSubview(amountLabel)
        contentStack.addArrangedSubview(buttonStack)
        
        contentStack.setCustomSpacing(Theme.Spacing.lg, after: iconContainerView)
        contentStack.setCustomSpacing(Theme.Spacing.md, after: amountLabel)
        contentStack.setCustomSpacing(Theme.Spacing.md, after: messageLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: Theme.Spacing.xl),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -Theme.Spacing.xl),
            
            // 80x80 icon area
            iconContainerView.widthAnchor.constraint(equalToConstant: 80),
            iconContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            statusIconView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            statusIconView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 80),
            statusIconView.heightAnchor.constraint(equalToConstant: 80),
            
            buttonStack.widthAnchor.constraint(equalToConstant: 280),
        ])
    }
    
    // MARK: - Show States (matching web StatusDisplay + ErrorDisplay)
    
    func showSuccess(amount: String, action: @escaping () -> Void) {
        isHidden = false
        actionHandler = action
        
        statusIconView.status = .success
        titleLabel.text = "Success!"
        titleLabel.textColor = Theme.Colors.success // #28A745
        amountLabel.text = amount
        amountLabel.isHidden = false
        messageLabel.text = "Payment Successful!"
        
        setupButtons(primary: ("Done", .primary, action), secondary: nil)
        animateIn()
    }
    
    func showFailure(message: String, amount: String? = nil, action: @escaping () -> Void) {
        isHidden = false
        actionHandler = action
        
        statusIconView.status = .failure
        titleLabel.text = "Payment Failed"
        titleLabel.textColor = Theme.Colors.error // #DC3545
        messageLabel.text = message
        
        if let amount = amount {
            amountLabel.text = amount
            amountLabel.isHidden = false
        } else {
            amountLabel.isHidden = true
        }
        
        setupButtons(primary: ("Close", .primary, action), secondary: nil)
        animateIn()
    }
    
    func showError(message: String, action: @escaping () -> Void) {
        showError(message: message, retryAction: nil, closeAction: action)
    }
    
    func showError(message: String, retryAction: (() -> Void)?, closeAction: @escaping () -> Void) {
        isHidden = false
        actionHandler = closeAction
        retryHandler = retryAction
        
        statusIconView.status = .failure
        titleLabel.text = "Error"
        titleLabel.textColor = Theme.Colors.error
        amountLabel.isHidden = true
        messageLabel.text = message
        
        if let retry = retryAction {
            setupButtons(
                primary: ("Try Again", .primary, retry),
                secondary: ("Close", .outline, closeAction)
            )
        } else {
            setupButtons(primary: ("Dismiss", .primary, closeAction), secondary: nil)
        }
        animateIn()
    }
    
    private func setupButtons(
        primary: (title: String, variant: PrimaryButton.Variant, action: () -> Void)?,
        secondary: (title: String, variant: PrimaryButton.Variant, action: () -> Void)?
    ) {
        buttonStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if let p = primary {
            let btn = PrimaryButton(title: p.title, variant: p.variant)
            btn.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
            buttonStack.addArrangedSubview(btn)
            primaryButton = btn
            actionHandler = p.action
        }
        
        if let s = secondary {
            let btn = PrimaryButton(title: s.title, variant: s.variant)
            btn.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)
            buttonStack.addArrangedSubview(btn)
            secondaryButton = btn
            retryHandler = actionHandler  // swap: primary becomes retry
            actionHandler = s.action      // secondary becomes close
        }
    }
    
    private func animateIn() {
        contentStack.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        contentStack.alpha = 0
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.contentStack.transform = .identity
            self.contentStack.alpha = 1
        }
        
        // Pulse animation on icon
        UIView.animate(withDuration: 0.5, delay: 0.1, options: [.curveEaseOut]) {
            self.iconContainerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.iconContainerView.transform = .identity
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func primaryTapped() {
        if retryHandler != nil {
            // Primary is "Try Again" when we have both buttons
            retryHandler?()
        } else {
            actionHandler?()
        }
        delegate?.statusDisplayViewDidTapAction(self)
    }
    
    @objc private func secondaryTapped() {
        actionHandler?()  // Close action
        delegate?.statusDisplayViewDidTapAction(self)
    }
}

// MARK: - Status Icon Drawing View (replaces GIF animations)

final class StatusIconDrawingView: UIView {
    
    enum Status {
        case success
        case failure
    }
    
    var status: Status = .success {
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
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4
        
        switch status {
        case .success:
            // Green circle
            ctx.setFillColor(Theme.Colors.success.withAlphaComponent(0.1).cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            
            ctx.setStrokeColor(Theme.Colors.success.cgColor)
            ctx.setLineWidth(3)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
            
            // Checkmark
            let checkPath = UIBezierPath()
            checkPath.move(to: CGPoint(x: center.x - radius * 0.35, y: center.y + radius * 0.05))
            checkPath.addLine(to: CGPoint(x: center.x - radius * 0.05, y: center.y + radius * 0.35))
            checkPath.addLine(to: CGPoint(x: center.x + radius * 0.4, y: center.y - radius * 0.3))
            checkPath.lineWidth = 4
            checkPath.lineCapStyle = .round
            checkPath.lineJoinStyle = .round
            Theme.Colors.success.setStroke()
            checkPath.stroke()
            
        case .failure:
            // Red circle
            ctx.setFillColor(Theme.Colors.error.withAlphaComponent(0.1).cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
            
            ctx.setStrokeColor(Theme.Colors.error.cgColor)
            ctx.setLineWidth(3)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
            
            // X mark
            let xSize = radius * 0.3
            let xPath = UIBezierPath()
            xPath.move(to: CGPoint(x: center.x - xSize, y: center.y - xSize))
            xPath.addLine(to: CGPoint(x: center.x + xSize, y: center.y + xSize))
            xPath.move(to: CGPoint(x: center.x + xSize, y: center.y - xSize))
            xPath.addLine(to: CGPoint(x: center.x - xSize, y: center.y + xSize))
            xPath.lineWidth = 4
            xPath.lineCapStyle = .round
            Theme.Colors.error.setStroke()
            xPath.stroke()
        }
    }
}
