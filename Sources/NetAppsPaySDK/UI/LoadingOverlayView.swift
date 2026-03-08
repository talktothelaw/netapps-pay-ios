// ============================================================
// LOADING OVERLAY VIEW - Full-screen loading indicator
// with cancel button so user can always close
// ============================================================

import UIKit

final class LoadingOverlayView: UIView {
    
    // MARK: - Callback
    
    /// Called when the user taps "Cancel" on the loading overlay
    var onCancel: (() -> Void)?
    
    // MARK: - UI
    
    private let blurView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.background
        view.layer.cornerRadius = Theme.CornerRadius.lg
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .large)
        } else {
            indicator = UIActivityIndicatorView(style: .whiteLarge)
        }
        indicator.color = Theme.Colors.primary
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.body
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(Theme.Colors.error, for: .normal)
        button.titleLabel?.font = Theme.Fonts.button
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return button
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
        addSubview(blurView)
        addSubview(containerView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(messageLabel)
        containerView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Theme.Spacing.lg),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: Theme.Spacing.md),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Theme.Spacing.md),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Theme.Spacing.md),
            
            cancelButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: Theme.Spacing.md),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Theme.Spacing.md),
        ])
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        onCancel?()
    }
    
    // MARK: - Show / Hide
    
    func show(message: String = "Processing...") {
        messageLabel.text = message
        activityIndicator.startAnimating()
        isHidden = false
        
        alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
    
    func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.isHidden = true
            self.activityIndicator.stopAnimating()
        }
    }
}
