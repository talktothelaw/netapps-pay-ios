// ============================================================
// REUSABLE UI COMPONENTS - Matching web widget design
// ============================================================

import UIKit

// MARK: - Primary Button (matches web Button $variant="primary")

final class PrimaryButton: UIButton {
    
    enum Variant {
        case primary    // #084B83 bg, white text
        case secondary  // #6C757D bg, white text
        case outline    // white bg, primary border, primary text
        case danger     // white bg, #DC3545 border, red text
    }
    
    private var buttonVariant: Variant = .primary
    private var savedTitle: String?
    
    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1.0 : 0.6
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
                self.alpha = self.isHighlighted ? 0.9 : (self.isEnabled ? 1.0 : 0.6)
            }
        }
    }
    
    init(title: String, variant: Variant = .primary) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buttonVariant = variant
        savedTitle = title
        setTitle(title, for: .normal)
        titleLabel?.font = Theme.Fonts.semibold(14)
        layer.cornerRadius = Theme.CornerRadius.button
        
        heightAnchor.constraint(equalToConstant: Theme.Sizes.buttonHeight).isActive = true
        
        applyVariantStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func applyVariantStyle() {
        switch buttonVariant {
        case .primary:
            backgroundColor = Theme.Colors.primary
            setTitleColor(.white, for: .normal)
            layer.borderWidth = 0
        case .secondary:
            backgroundColor = Theme.Colors.textMuted
            setTitleColor(.white, for: .normal)
            layer.borderWidth = 0
        case .outline:
            backgroundColor = .white
            setTitleColor(Theme.Colors.primary, for: .normal)
            layer.borderWidth = 1.5
            layer.borderColor = Theme.Colors.primary.cgColor
        case .danger:
            backgroundColor = .white
            setTitleColor(Theme.Colors.error, for: .normal)
            layer.borderWidth = 1.5
            layer.borderColor = Theme.Colors.error.cgColor
        }
    }
    
    func setLoading(_ loading: Bool) {
        isEnabled = !loading
        if loading {
            savedTitle = title(for: .normal)
            setTitle("", for: .normal)
            let indicator = UIActivityIndicatorView(style: .white)
            indicator.tag = 999
            indicator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            indicator.startAnimating()
        } else {
            viewWithTag(999)?.removeFromSuperview()
            if let saved = savedTitle {
                setTitle(saved, for: .normal)
            }
        }
    }
}

// MARK: - Styled Text Field (matches web InputWrapper + Input)

final class StyledTextField: UIView {
    
    let textField: UITextField = {
        let tf = UITextField()
        tf.font = Theme.Fonts.body // 14px
        tf.textColor = Theme.Colors.text
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.autocorrectionType = .no
        return tf
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.inputLabel // 10px weight 500
        label.textColor = Theme.Colors.inputLabel // #344054
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear // transparent bg like web
        view.layer.borderWidth = 1
        view.layer.borderColor = Theme.Colors.border.cgColor // #D0D5DD
        view.layer.cornerRadius = Theme.CornerRadius.input  // 5px
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Optional right accessory view (e.g., card brand icon)
    private(set) var rightAccessoryView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let accessory = rightAccessoryView {
                accessory.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(accessory)
                textFieldTrailingConstraint?.isActive = false
                textFieldTrailingConstraint = textField.trailingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: -4)
                textFieldTrailingConstraint?.isActive = true
                NSLayoutConstraint.activate([
                    accessory.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
                    accessory.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                    accessory.widthAnchor.constraint(equalToConstant: 30),
                    accessory.heightAnchor.constraint(equalToConstant: 20),
                ])
            } else {
                textFieldTrailingConstraint?.isActive = false
                textFieldTrailingConstraint = textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
                textFieldTrailingConstraint?.isActive = true
            }
        }
    }
    
    private var textFieldTrailingConstraint: NSLayoutConstraint?
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.regular(12) // 0.75rem
        label.textColor = Theme.Colors.error
        label.isHidden = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var errorBottomConstraint: NSLayoutConstraint?
    private var containerBottomConstraint: NSLayoutConstraint?
    
    var text: String? {
        get { textField.text }
        set { textField.text = newValue }
    }
    
    init(title: String, placeholder: String, keyboardType: UIKeyboardType = .default) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = title
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        
        // Add toolbar with Paste + Done buttons for numeric keyboards
        if keyboardType == .numberPad || keyboardType == .phonePad || keyboardType == .decimalPad {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            toolbar.barStyle = .default
            toolbar.isTranslucent = true
            let pasteItem = UIBarButtonItem(title: "Paste", style: .plain, target: self, action: #selector(pasteFromClipboard))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
            toolbar.items = [pasteItem, flexSpace, doneItem]
            toolbar.sizeToFit()
            textField.inputAccessoryView = toolbar
        }
        
        addSubview(titleLabel)
        addSubview(containerView)
        containerView.addSubview(textField)
        addSubview(errorLabel)
        
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        errorBottomConstraint = errorLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        containerBottomConstraint?.isActive = true
        
        textFieldTrailingConstraint = textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            containerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 36), // 32px + 4px padding
            
            // 12px horizontal, 14px vertical padding (web: padding 14px 12px)
            textField.topAnchor.constraint(equalTo: containerView.topAnchor),
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            textFieldTrailingConstraint!,
            textField.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            errorLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 2),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        textField.text = text
        textField.sendActions(for: .editingChanged)
    }
    
    @objc private func dismissKeyboard() {
        textField.resignFirstResponder()
    }
    
    /// Set a right accessory view inside the text field container
    func setRightAccessory(_ view: UIView?) {
        rightAccessoryView = view
    }
    
    func setError(_ message: String?) {
        if let message = message {
            errorLabel.text = message
            errorLabel.isHidden = false
            containerView.layer.borderColor = Theme.Colors.error.cgColor
            containerBottomConstraint?.isActive = false
            errorBottomConstraint?.isActive = true
        } else {
            errorLabel.isHidden = true
            containerView.layer.borderColor = Theme.Colors.border.cgColor
            errorBottomConstraint?.isActive = false
            containerBottomConstraint?.isActive = true
        }
    }
    
    func setActive(_ active: Bool) {
        if active {
            containerView.layer.borderColor = Theme.Colors.primary.cgColor
            containerView.layer.borderWidth = 1
        } else {
            containerView.layer.borderColor = Theme.Colors.border.cgColor
            containerView.layer.borderWidth = 1
        }
    }
}

// MARK: - Info Row (Label: Value) matching web DetailRow style

final class InfoRow: UIView {
    
    private let labelText: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.captionSmall // 10px (matches web xs)
        label.textColor = Theme.Colors.textMuted // #6C757D
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueText: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.medium(14)
        label.textColor = Theme.Colors.text
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(label: String, value: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        labelText.text = label
        valueText.text = value
        
        addSubview(labelText)
        addSubview(valueText)
        
        // Vertical layout: label on top, value below (matches web DetailRow)
        NSLayoutConstraint.activate([
            labelText.topAnchor.constraint(equalTo: topAnchor),
            labelText.leadingAnchor.constraint(equalTo: leadingAnchor),
            labelText.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            valueText.topAnchor.constraint(equalTo: labelText.bottomAnchor, constant: 2),
            valueText.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueText.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueText.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setValue(_ value: String) {
        valueText.text = value
    }
    
    func setHighlighted(_ highlighted: Bool) {
        valueText.font = highlighted ? Theme.Fonts.bold(16) : Theme.Fonts.medium(14)
        valueText.textColor = highlighted ? Theme.Colors.primary : Theme.Colors.text
    }
}

// MARK: - Copy Button (matches web CopyButton style)

final class CopyableLabel: UIView {
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        label.textColor = Theme.Colors.text
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy", for: .normal)
        button.titleLabel?.font = Theme.Fonts.medium(10)
        button.tintColor = Theme.Colors.primary
        button.layer.borderWidth = 1
        button.layer.borderColor = Theme.Colors.primary.cgColor
        button.layer.cornerRadius = Theme.CornerRadius.sm
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.captionSmall // matches web xs / InfoRow label
        label.textColor = Theme.Colors.textMuted
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var textToCopy: String = ""
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(copyButton)
        
        // Left-align value (matches web AccountNumberRow: flex, align-items center, gap sm)
        valueLabel.textAlignment = .left
        
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            copyButton.centerYAnchor.constraint(equalTo: valueLabel.centerYAnchor),
            copyButton.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: Theme.Spacing.sm),
            copyButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String) {
        textToCopy = text
        valueLabel.text = text
    }
    
    func configure(title: String, text: String) {
        titleLabel.text = title
        textToCopy = text
        valueLabel.text = text
    }
    
    @objc private func copyTapped() {
        UIPasteboard.general.string = textToCopy
        copyButton.setTitle("Copied!", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setTitle("Copy", for: .normal)
        }
    }
}

// MARK: - Spinner (matching web Spinner)

final class SpinnerView: UIView {
    
    private let activityIndicator: UIActivityIndicatorView
    
    init(size: CGFloat = 24) {
        if #available(iOS 13.0, *) {
            activityIndicator = UIActivityIndicatorView(style: size > 30 ? .large : .medium)
        } else {
            activityIndicator = UIActivityIndicatorView(style: size > 30 ? .whiteLarge : .white)
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = Theme.Colors.primary
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        activityIndicator.startAnimating()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func stopAnimating() {
        activityIndicator.stopAnimating()
    }
    
    func startAnimating() {
        activityIndicator.startAnimating()
    }
}

// MARK: - Select Field (matching web StyledSelect)

final class StyledSelect: UIView {
    
    private(set) var selectedIndex: Int = -1
    private var options: [(label: String, value: String)] = []
    var onSelect: ((Int, String) -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = Theme.Fonts.inputLabel
        label.textColor = Theme.Colors.inputLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let button: UIButton = {
        let btn = UIButton(type: .system)
        btn.contentHorizontalAlignment = .left
        btn.titleLabel?.font = Theme.Fonts.body
        btn.setTitleColor(Theme.Colors.text, for: .normal)
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Theme.Colors.border.cgColor
        btn.layer.cornerRadius = Theme.CornerRadius.input
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    init(title: String, placeholder: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        button.setTitle(placeholder, for: .normal)
        button.setTitleColor(Theme.Colors.textMuted, for: .normal)
        
        addSubview(titleLabel)
        addSubview(button)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            button.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Theme.Spacing.xs),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.heightAnchor.constraint(equalToConstant: 36),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        button.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setOptions(_ opts: [(label: String, value: String)]) {
        options = opts
    }
    
    @objc private func showPicker() {
        guard let vc = findViewController() else { return }
        let sheetOptions = options.map { ActionSheetOption(label: $0.label, value: $0.value) }
        let currentValue = selectedIndex >= 0 && selectedIndex < options.count ? options[selectedIndex].value : nil
        
        vc.presentActionSheet(
            title: titleLabel.text ?? "Select",
            options: sheetOptions,
            selectedValue: currentValue
        ) { [weak self] selected in
            guard let self = self,
                  let idx = self.options.firstIndex(where: { $0.value == selected.value }) else { return }
            self.selectedIndex = idx
            self.button.setTitle(selected.label, for: .normal)
            self.button.setTitleColor(Theme.Colors.text, for: .normal)
            self.onSelect?(idx, selected.value)
        }
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}

// MARK: - Test Mode Banner (matches web TestBanner)

final class TestModeBanner: UIView {
    
    private let bannerLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠ Test Mode"
        label.font = Theme.Fonts.semibold(11)
        label.textColor = Theme.Colors.testBannerText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        backgroundColor = Theme.Colors.testBannerBg
        layer.borderWidth = 1
        layer.borderColor = Theme.Colors.testBannerBorder.cgColor
        layer.cornerRadius = 6
        
        addSubview(bannerLabel)
        NSLayoutConstraint.activate([
            bannerLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            bannerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            bannerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bannerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }
    
    func configure(text: String) {
        bannerLabel.text = text
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Instructions List (matches web Instructions)

final class InstructionsList: UIView {
    
    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = Theme.Spacing.xs
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    init(items: [String] = [], warningIndex: Int? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        if !items.isEmpty {
            updateItems(items, warningIndex: warningIndex)
        }
    }
    
    func updateItems(_ items: [String], warningIndex: Int? = nil) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, item) in items.enumerated() {
            let label = UILabel()
            label.text = "• \(item)"
            label.font = Theme.Fonts.caption
            label.textColor = (warningIndex == i) ? Theme.Colors.error : Theme.Colors.textLight
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}
