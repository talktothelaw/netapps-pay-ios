// ============================================================
// TRANSACTION SUMMARY VIEW - Matches web TransactionSummary.tsx
// Horizontal row: logo+businessName left, narration+amount right
// #EDF5FB background, 0.5rem border-radius
// ============================================================

import UIKit

final class TransactionSummaryView: UIView {
    
    // MARK: - UI Components
    
    private let testBanner = TestModeBanner()
    
    private let outerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Theme.Colors.backgroundAlt // #EDF5FB
        view.layer.cornerRadius = Theme.CornerRadius.md   // 0.5rem = 8px
        view.layer.borderWidth = 1
        view.layer.borderColor = Theme.Colors.backgroundAlt.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Left side: Logo + Business Name
    private let userDetailsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let logoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 32.5 // 65/2 for circular
        iv.backgroundColor = Theme.Colors.primary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // Default logo: "N" on primary background
    private let defaultLogoLabel: UILabel = {
        let label = UILabel()
        label.text = "N"
        label.font = Theme.Fonts.bold(24)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let businessNameLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.businessName // 0.8rem = 13px semibold
        label.textColor = Theme.Colors.textLight // #555555
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Right side: narration/product + amount
    private let productDetailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let narrationLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.productLabel // 0.75rem = 12px
        label.textColor = Theme.Colors.textLight // #555555
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let productNameLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.businessName // 0.8rem = 13px semibold
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let totalPayLabel: UILabel = {
        let label = UILabel()
        label.text = "Total Pay"
        label.font = Theme.Fonts.productLabel // 0.75rem
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.productAmount // 0.9rem = 14px bold 700
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var isTestMode: Bool = false
    
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
        
        testBanner.isHidden = true
        addSubview(testBanner)
        addSubview(outerContainer)
        
        // Left side: logo + business name
        outerContainer.addSubview(userDetailsView)
        userDetailsView.addSubview(logoView)
        logoView.addSubview(defaultLogoLabel)
        userDetailsView.addSubview(businessNameLabel)
        
        // Right side: product details
        outerContainer.addSubview(productDetailsStack)
        
        NSLayoutConstraint.activate([
            // Test banner
            testBanner.topAnchor.constraint(equalTo: topAnchor),
            testBanner.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            // Outer container
            outerContainer.topAnchor.constraint(equalTo: testBanner.isHidden ? topAnchor : testBanner.bottomAnchor, constant: testBanner.isHidden ? 0 : Theme.Spacing.sm),
            outerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // User details (left, 57% width)
            userDetailsView.topAnchor.constraint(equalTo: outerContainer.topAnchor, constant: Theme.Spacing.sm),
            userDetailsView.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor, constant: Theme.Spacing.sm),
            userDetailsView.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor, constant: -Theme.Spacing.sm),
            userDetailsView.widthAnchor.constraint(equalTo: outerContainer.widthAnchor, multiplier: 0.57),
            
            // Logo: 65x65 circular
            logoView.topAnchor.constraint(equalTo: userDetailsView.topAnchor),
            logoView.centerXAnchor.constraint(equalTo: userDetailsView.centerXAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 65),
            logoView.heightAnchor.constraint(equalToConstant: 65),
            
            defaultLogoLabel.centerXAnchor.constraint(equalTo: logoView.centerXAnchor),
            defaultLogoLabel.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
            
            // Business name below logo
            businessNameLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 5), // 0.3rem
            businessNameLabel.leadingAnchor.constraint(equalTo: userDetailsView.leadingAnchor),
            businessNameLabel.trailingAnchor.constraint(equalTo: userDetailsView.trailingAnchor),
            businessNameLabel.bottomAnchor.constraint(lessThanOrEqualTo: userDetailsView.bottomAnchor),
            
            // Product details (right side)
            productDetailsStack.centerYAnchor.constraint(equalTo: outerContainer.centerYAnchor),
            productDetailsStack.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor, constant: -Theme.Spacing.sm),
            productDetailsStack.leadingAnchor.constraint(greaterThanOrEqualTo: userDetailsView.trailingAnchor, constant: Theme.Spacing.xs),
        ])
    }
    
    // MARK: - Configure (matches web TransactionSummary props)
    
    func configure(
        businessName: String = "Netapps Marketplace",
        narration: String? = nil,
        productName: String? = nil,
        amount: String,
        logoURL: String? = nil,
        isTest: Bool = false
    ) {
        businessNameLabel.text = businessName
        
        // Clear product stack
        productDetailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add narration + product name if available
        if let narration = narration, !narration.isEmpty {
            narrationLabel.text = narration
            productDetailsStack.addArrangedSubview(narrationLabel)
            
            if let productName = productName, !productName.isEmpty {
                productNameLabel.text = productName
                productDetailsStack.addArrangedSubview(productNameLabel)
            }
        } else if let productName = productName, !productName.isEmpty {
            let label = UILabel()
            label.text = productName
            label.font = Theme.Fonts.productLabel
            label.textColor = Theme.Colors.textLight
            label.textAlignment = .right
            productDetailsStack.addArrangedSubview(label)
        }
        
        // Total Pay + Amount
        productDetailsStack.addArrangedSubview(totalPayLabel)
        amountLabel.text = amount
        productDetailsStack.addArrangedSubview(amountLabel)
        
        // Logo
        if let urlStr = logoURL, let url = URL(string: urlStr) {
            defaultLogoLabel.isHidden = true
            loadImage(from: url)
        } else {
            defaultLogoLabel.isHidden = false
            logoView.image = nil
        }
        
        // Test banner
        isTestMode = isTest
        testBanner.isHidden = !isTest
        
        // Update top constraint for outer container based on test banner
        updateConstraints()
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.logoView.image = image
            }
        }.resume()
    }
    
    // Legacy configure for backward compatibility
    func configure(email: String, amount: String, businessName: String? = nil) {
        configure(
            businessName: businessName ?? "Netapps Marketplace",
            narration: nil,
            productName: email,
            amount: amount
        )
    }
}
