// ============================================================
// CARD PAYMENT VIEW CONTROLLER
// Matches web CardPayment.tsx flow:
//   loading → test_cards / saved_cards / new_card
// Handles card input, 3DS via WKWebView, saved cards, test cards
// ============================================================

import UIKit
import WebKit

final class CardPaymentViewController: UIViewController {
    
    // MARK: - View Mode (matches web viewMode state)
    
    private enum ViewMode {
        case loading
        case testCards
        case savedCards
        case newCard
    }
    
    // MARK: - Properties
    
    private let store: PaymentStore
    private let api: PaymentAPIClient
    private weak var parentVC: PaymentViewController?
    private var referenceId: String?
    private var deviceCollectionCompleted = false
    
    private var viewMode: ViewMode = .loading
    private var savedCards: [SavedCard] = []
    private var testCards: [TestCard] = []
    private var selectedSavedCard: SavedCard?
    private var selectedTestCard: TestCard?
    
    // MARK: - Container (switches between views)
    
    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - New Card Form Views
    
    // 3D Card Visual (matches web DebitCard component)
    private let debitCardView: DebitCardVisualView = {
        let view = DebitCardVisualView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Card brand detection + icon (matches web CardBrandIcon)
    private var detectedBrand: CardBrand = .unknown
    private let cardBrandIcon = CardBrandIconView(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
    
    // "← Back to saved/test cards" button
    private let backToCardsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("← Back to saved cards", for: .normal)
        button.titleLabel?.font = Theme.Fonts.caption
        button.setTitleColor(Theme.Colors.primary, for: .normal)
        button.contentHorizontalAlignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private lazy var cardNumberField = StyledTextField(
        title: "Card Number",
        placeholder: "0000 0000 0000 0000",
        keyboardType: .numberPad
    )
    
    private let expiryAndCVVStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var expiryField = StyledTextField(
        title: "Expiry Date",
        placeholder: "MM/YY",
        keyboardType: .numberPad
    )
    
    private lazy var cvvField = StyledTextField(
        title: "CVV",
        placeholder: "****",
        keyboardType: .numberPad
    )
    
    private lazy var cardHolderField = StyledTextField(
        title: "Cardholder Name",
        placeholder: "Name on card"
    )
    
    // API error banner
    private let errorBanner: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(red: 254/255, green: 242/255, blue: 242/255, alpha: 1)
        view.layer.borderColor = UIColor(red: 254/255, green: 202/255, blue: 202/255, alpha: 1).cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = Theme.CornerRadius.md
        view.isHidden = true
        return view
    }()
    
    private let errorBannerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.error
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    // Save card checkbox
    private let saveCardContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let saveCardCheckbox: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.borderWidth = 1.5
        button.layer.borderColor = Theme.Colors.border.cgColor
        button.layer.cornerRadius = 3
        button.backgroundColor = .white
        button.tintColor = Theme.Colors.primary
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 16),
            button.heightAnchor.constraint(equalToConstant: 16)
        ])
        return button
    }()
    
    private let saveCardLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Save this card for future payments"
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.text
        return label
    }()
    
    private var isSaveCardChecked = false
    
    private lazy var payButton = PrimaryButton(title: "Pay \(AmountFormatter.format(amount: store.responseAmount, currency: store.config?.currency ?? .NGN))")
    
    // WebView for hidden device collection only
    private var deviceCollectionWebView: WKWebView?
    private let deviceCollectionContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    /// Popup for 3DS challenge (presented modally)
    private var threeDSPopup: ThreeDSPopupViewController?
    
    // MARK: - Init
    
    init(store: PaymentStore, api: PaymentAPIClient, parentVC: PaymentViewController) {
        self.store = store
        self.api = api
        self.parentVC = parentVC
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFormatting()
        
        if let name = store.config?.cardHolderName ?? store.config?.fullName {
            cardHolderField.text = name
        }
        
        // Start by loading cards (matches web useEffect flow)
        loadCards()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        view.addSubview(containerStack)
        view.addSubview(deviceCollectionContainer)
        
        // Error banner internal layout
        errorBanner.addSubview(errorBannerLabel)
        NSLayoutConstraint.activate([
            errorBannerLabel.topAnchor.constraint(equalTo: errorBanner.topAnchor, constant: 10),
            errorBannerLabel.leadingAnchor.constraint(equalTo: errorBanner.leadingAnchor, constant: 12),
            errorBannerLabel.trailingAnchor.constraint(equalTo: errorBanner.trailingAnchor, constant: -12),
            errorBannerLabel.bottomAnchor.constraint(equalTo: errorBanner.bottomAnchor, constant: -10)
        ])
        
        // Save card checkbox internal layout
        saveCardContainer.addSubview(saveCardCheckbox)
        saveCardContainer.addSubview(saveCardLabel)
        NSLayoutConstraint.activate([
            saveCardCheckbox.leadingAnchor.constraint(equalTo: saveCardContainer.leadingAnchor),
            saveCardCheckbox.centerYAnchor.constraint(equalTo: saveCardContainer.centerYAnchor),
            saveCardLabel.leadingAnchor.constraint(equalTo: saveCardCheckbox.trailingAnchor, constant: 8),
            saveCardLabel.centerYAnchor.constraint(equalTo: saveCardContainer.centerYAnchor),
            saveCardLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveCardContainer.trailingAnchor),
            saveCardContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
        saveCardCheckbox.addTarget(self, action: #selector(saveCardToggled), for: .touchUpInside)
        backToCardsButton.addTarget(self, action: #selector(backToCardsTapped), for: .touchUpInside)
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: view.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Device collection container is 0-height – it only runs JS silently
            deviceCollectionContainer.topAnchor.constraint(equalTo: view.topAnchor),
            deviceCollectionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deviceCollectionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            deviceCollectionContainer.heightAnchor.constraint(equalToConstant: 0),
        ])
        
        // Show loading initially
        showLoadingView()
    }
    
    // MARK: - View Mode Management
    
    private func switchToMode(_ mode: ViewMode) {
        viewMode = mode
        
        // Clear container
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        switch mode {
        case .loading:
            showLoadingView()
        case .testCards:
            buildTestCardsList()
        case .savedCards:
            buildSavedCardsList()
        case .newCard:
            buildNewCardForm()
        }
    }
    
    // MARK: - Loading View
    
    private func showLoadingView() {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let spinner = SpinnerView(size: 24)
        let label = UILabel()
        label.text = "Loading payment options..."
        label.font = Theme.Fonts.caption
        label.textColor = Theme.Colors.textLight
        label.textAlignment = .center
        
        let wrapper = UIStackView(arrangedSubviews: [spinner, label])
        wrapper.axis = .vertical
        wrapper.spacing = Theme.Spacing.sm
        wrapper.alignment = .center
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        
        containerStack.addArrangedSubview(spacer)
        containerStack.addArrangedSubview(wrapper)
        
        let bottomSpacer = UIView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        containerStack.addArrangedSubview(bottomSpacer)
    }
    
    // MARK: - Load Cards
    
    private func loadCards() {
        guard let transactionId = store.transactionId else {
            switchToMode(.newCard)
            return
        }
        
        let isLive = store.isLive
        
        if !isLive {
            // Test mode: fetch test cards
            api.getTestCards(transactionId: transactionId) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let cards):
                        self.testCards = cards
                        if cards.isEmpty {
                            self.switchToMode(.newCard)
                        } else {
                            self.switchToMode(.testCards)
                        }
                    case .failure:
                        self.switchToMode(.newCard)
                    }
                }
            }
        } else {
            // Live mode: fetch saved cards
            api.getSavedCards(transactionId: transactionId) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let cards):
                        let activeCards = cards.filter { $0.isActive }
                        self.savedCards = activeCards
                        if activeCards.isEmpty {
                            self.switchToMode(.newCard)
                        } else {
                            self.switchToMode(.savedCards)
                        }
                    case .failure:
                        self.switchToMode(.newCard)
                    }
                }
            }
        }
    }
    
    // MARK: - Build Test Cards List
    
    private func buildTestCardsList() {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Header
        let titleLabel = UILabel()
        titleLabel.text = "Select a Test Card"
        titleLabel.font = Theme.Fonts.subtitle
        titleLabel.textColor = Theme.Colors.text
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "These cards are for testing purposes only. No real charges will be made."
        subtitleLabel.font = Theme.Fonts.regular(11)
        subtitleLabel.textColor = Theme.Colors.textLight
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(subtitleLabel)
        
        // Cards list
        for card in testCards {
            let cardView = createTestCardRow(card)
            containerStack.addArrangedSubview(cardView)
        }
        
        // Note
        let noteView = createNoteView(text: "Click on a card to pay \(AmountFormatter.format(amount: store.responseAmount, currency: store.config?.currency ?? .NGN)). For OTP, use: 123456")
        containerStack.addArrangedSubview(errorBanner)
        containerStack.addArrangedSubview(noteView)
    }
    
    private func createTestCardRow(_ card: TestCard) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = Theme.Colors.backgroundAlt
        container.layer.cornerRadius = Theme.CornerRadius.md
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.Colors.border.cgColor
        
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = Theme.Spacing.sm
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        
        // Card icon
        let iconView = ChannelIconView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        iconView.channel = .card
        iconView.iconColor = Theme.Colors.primary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.backgroundColor = .clear
        
        // Card info
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 2
        
        let numberLabel = UILabel()
        numberLabel.text = formatCardNumberDisplay(card.cardNumber)
        numberLabel.font = Theme.Fonts.medium(13)
        numberLabel.textColor = Theme.Colors.text
        
        let expiryLabel = UILabel()
        let monthStr = String(format: "%02d", card.expirationMonth)
        let yearStr = String(card.expirationYear).suffix(2)
        expiryLabel.text = "Expires \(monthStr)/\(yearStr)"
        expiryLabel.font = Theme.Fonts.regular(11)
        expiryLabel.textColor = Theme.Colors.textMuted
        
        infoStack.addArrangedSubview(numberLabel)
        infoStack.addArrangedSubview(expiryLabel)
        
        // Flow badge
        let badge = UILabel()
        badge.text = card.flowType == "FRICTIONLESS" ? "✓ No OTP" : "🔒 OTP"
        badge.font = Theme.Fonts.regular(10)
        badge.textColor = card.flowType == "FRICTIONLESS" ? Theme.Colors.success : UIColor(hex: "#FF9800")
        badge.backgroundColor = card.flowType == "FRICTIONLESS"
            ? Theme.Colors.success.withAlphaComponent(0.1)
            : UIColor(hex: "#FF9800").withAlphaComponent(0.1)
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        topRow.addArrangedSubview(iconView)
        topRow.addArrangedSubview(infoStack)
        topRow.addArrangedSubview(UIView()) // spacer
        topRow.addArrangedSubview(badge)
        
        // Description
        let descLabel = UILabel()
        descLabel.text = card.description
        descLabel.font = Theme.Fonts.regular(11)
        descLabel.textColor = Theme.Colors.textLight
        descLabel.numberOfLines = 0
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(topRow)
        container.addSubview(descLabel)
        
        NSLayoutConstraint.activate([
            topRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            topRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            topRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            
            descLabel.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            descLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        
        // Tap gesture
        let tap = CardTapGesture(target: self, action: #selector(testCardTapped(_:)))
        tap.testCard = card
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    @objc private func testCardTapped(_ gesture: CardTapGesture) {
        guard let card = gesture.testCard else { return }
        selectedTestCard = card
        processTestCard(card)
    }
    
    private func processTestCard(_ card: TestCard) {
        guard let transactionId = store.transactionId,
              let config = store.config else { return }
        
        guard let monthEnum = ExpirationMonth.from(month: card.expirationMonth) else { return }
        
        parentVC?.showLoading(message: "Processing card...")
        store.setStatus(.processing)
        
        let request = ProcessCardRequest(
            cardData: CardDataPayload(
                cardHolderName: "Test User",
                cardNumber: card.cardNumber.replacingOccurrences(of: " ", with: ""),
                expirationMonth: monthEnum.rawValue,
                expirationYear: card.expirationYear,
                cvv: "123"
            ),
            amountData: AmountDataPayload(
                authorizedAmount: store.requestAmount,
                totalAmount: store.requestAmount,
                currency: config.currency.rawValue
            ),
            deviceInformation: DeviceInformationPayload.default(),
            saveCard: false
        )
        
        api.processCard(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let response):
                    self.handleCardResponse(response)
                case .failure(let error):
                    self.showApiError(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Build Saved Cards List
    
    private func buildSavedCardsList() {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Header row: "Your Saved Cards" + "+ Use New Card"
        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        
        let headerTitle = UILabel()
        headerTitle.text = "Your Saved Cards"
        headerTitle.font = Theme.Fonts.subtitle
        headerTitle.textColor = Theme.Colors.text
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        
        let newCardBtn = UIButton(type: .system)
        newCardBtn.setTitle("+ Use New Card", for: .normal)
        newCardBtn.titleLabel?.font = Theme.Fonts.medium(12)
        newCardBtn.setTitleColor(Theme.Colors.primary, for: .normal)
        newCardBtn.translatesAutoresizingMaskIntoConstraints = false
        newCardBtn.addTarget(self, action: #selector(useNewCardTapped), for: .touchUpInside)
        
        headerRow.addSubview(headerTitle)
        headerRow.addSubview(newCardBtn)
        NSLayoutConstraint.activate([
            headerTitle.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            headerTitle.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            newCardBtn.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            newCardBtn.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: 32),
        ])
        containerStack.addArrangedSubview(headerRow)
        
        // Default selection
        if selectedSavedCard == nil {
            selectedSavedCard = savedCards.first(where: { $0.isDefault }) ?? savedCards.first
        }
        
        // Card items
        for card in savedCards {
            let cardView = createSavedCardRow(card)
            containerStack.addArrangedSubview(cardView)
        }
        
        // Continue button
        let continueBtn = PrimaryButton(title: "Continue with Selected Card")
        continueBtn.addTarget(self, action: #selector(continueWithSavedCard), for: .touchUpInside)
        containerStack.addArrangedSubview(errorBanner)
        containerStack.addArrangedSubview(continueBtn)
    }
    
    private func createSavedCardRow(_ card: SavedCard) -> UIView {
        let isSelected = selectedSavedCard?.id == card.id
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = isSelected ? Theme.Colors.primary.withAlphaComponent(0.05) : .white
        container.layer.cornerRadius = Theme.CornerRadius.md
        container.layer.borderWidth = isSelected ? 1.5 : 1
        container.layer.borderColor = isSelected ? Theme.Colors.primary.cgColor : Theme.Colors.border.cgColor
        
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        
        // Radio circle
        let radioOuter = UIView()
        radioOuter.translatesAutoresizingMaskIntoConstraints = false
        radioOuter.layer.cornerRadius = 9
        radioOuter.layer.borderWidth = 2
        radioOuter.layer.borderColor = isSelected ? Theme.Colors.primary.cgColor : Theme.Colors.border.cgColor
        radioOuter.widthAnchor.constraint(equalToConstant: 18).isActive = true
        radioOuter.heightAnchor.constraint(equalToConstant: 18).isActive = true
        
        if isSelected {
            let radioDot = UIView()
            radioDot.backgroundColor = Theme.Colors.primary
            radioDot.layer.cornerRadius = 5
            radioDot.translatesAutoresizingMaskIntoConstraints = false
            radioOuter.addSubview(radioDot)
            NSLayoutConstraint.activate([
                radioDot.centerXAnchor.constraint(equalTo: radioOuter.centerXAnchor),
                radioDot.centerYAnchor.constraint(equalTo: radioOuter.centerYAnchor),
                radioDot.widthAnchor.constraint(equalToConstant: 10),
                radioDot.heightAnchor.constraint(equalToConstant: 10),
            ])
        }
        
        // Card icon
        let iconView = ChannelIconView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        iconView.channel = .card
        iconView.iconColor = Theme.Colors.primary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.backgroundColor = .clear
        
        // Card info
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 2
        
        let last4 = String(card.maskedPan.suffix(4))
        let numberLabel = UILabel()
        numberLabel.text = "•••• \(last4)"
        numberLabel.font = Theme.Fonts.medium(13)
        numberLabel.textColor = Theme.Colors.text
        
        let monthStr = String(format: "%02d", card.expiryMonth)
        let yearStr = String(card.expiryYear).suffix(2)
        let expiryLabel = UILabel()
        expiryLabel.text = "Expires \(monthStr)/\(yearStr)"
        expiryLabel.font = Theme.Fonts.regular(11)
        expiryLabel.textColor = Theme.Colors.textMuted
        
        infoStack.addArrangedSubview(numberLabel)
        infoStack.addArrangedSubview(expiryLabel)
        
        row.addArrangedSubview(radioOuter)
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(infoStack)
        row.addArrangedSubview(UIView()) // spacer
        
        // Default badge
        if card.isDefault {
            let badge = UILabel()
            badge.text = "Default"
            badge.font = Theme.Fonts.regular(10)
            badge.textColor = Theme.Colors.primary
            badge.backgroundColor = Theme.Colors.primary.withAlphaComponent(0.1)
            badge.layer.cornerRadius = 4
            badge.clipsToBounds = true
            badge.textAlignment = .center
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.widthAnchor.constraint(equalToConstant: 52).isActive = true
            badge.heightAnchor.constraint(equalToConstant: 20).isActive = true
            row.addArrangedSubview(badge)
        }
        
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        
        // Tap gesture
        let tap = CardTapGesture(target: self, action: #selector(savedCardTapped(_:)))
        tap.savedCard = card
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        
        return container
    }
    
    @objc private func savedCardTapped(_ gesture: CardTapGesture) {
        guard let card = gesture.savedCard else { return }
        selectedSavedCard = card
        buildSavedCardsList()
    }
    
    @objc private func continueWithSavedCard() {
        guard let card = selectedSavedCard else { return }
        showCVVInputAlert(for: card)
    }
    
    private func showCVVInputAlert(for card: SavedCard) {
        let last4 = String(card.maskedPan.suffix(4))
        let alert = UIAlertController(
            title: "Enter CVV",
            message: "Enter the 3 or 4-digit CVV for card ending in \(last4)",
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] tf in
            tf.placeholder = "CVV"
            tf.keyboardType = .numberPad
            tf.isSecureTextEntry = true
            // Add toolbar with Paste button for numberPad keyboard
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            toolbar.barStyle = .default
            let pasteItem = UIBarButtonItem(title: "Paste", style: .plain, target: self, action: #selector(self?.pasteIntoCVVAlert))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: tf, action: #selector(UIResponder.resignFirstResponder))
            toolbar.items = [pasteItem, flexSpace, doneItem]
            toolbar.sizeToFit()
            tf.inputAccessoryView = toolbar
            // Tag the text field so we can find it from the paste action
            tf.tag = 9998
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Pay", style: .default) { [weak self] _ in
            guard let self = self,
                  let cvv = alert.textFields?.first?.text,
                  cvv.count >= 3 else { return }
            self.processSavedCard(card, cvv: cvv)
        })
        present(alert, animated: true)
    }
    
    @objc private func pasteIntoCVVAlert() {
        guard let text = UIPasteboard.general.string else { return }
        let digits = text.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return }
        // Find the alert's text field by walking the responder chain
        if let presented = presentedViewController as? UIAlertController,
           let tf = presented.textFields?.first {
            tf.text = String(digits.prefix(4))
        }
    }
    
    private func processSavedCard(_ card: SavedCard, cvv: String) {
        guard let transactionId = store.transactionId,
              let config = store.config else { return }
        
        parentVC?.showLoading(message: "Processing card...")
        store.setStatus(.processing)
        
        let request = ProcessSavedCardRequest(
            cardToken: card.cardToken,
            cvv: cvv,
            amountData: AmountDataPayload(
                authorizedAmount: store.requestAmount,
                totalAmount: store.requestAmount,
                currency: config.currency.rawValue
            ),
            deviceInformation: DeviceInformationPayload.default()
        )
        
        api.processSavedCard(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let response):
                    self.handleCardResponse(response)
                case .failure(let error):
                    self.showApiError(error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func useNewCardTapped() {
        switchToMode(.newCard)
    }
    
    @objc private func backToCardsTapped() {
        if !store.isLive && !testCards.isEmpty {
            switchToMode(.testCards)
        } else if store.isLive && !savedCards.isEmpty {
            switchToMode(.savedCards)
        }
    }
    
    // MARK: - Build New Card Form
    
    private func buildNewCardForm() {
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Back button (only if we have saved/test cards to go back to)
        let hasCardsToGoBack = (!store.isLive && !testCards.isEmpty) || (store.isLive && !savedCards.isEmpty)
        if hasCardsToGoBack {
            backToCardsButton.isHidden = false
            backToCardsButton.setTitle(
                store.isLive ? "← Back to saved cards" : "← Back to test cards",
                for: .normal
            )
            containerStack.addArrangedSubview(backToCardsButton)
        }
        
        // 3D Card Visual
        containerStack.addArrangedSubview(debitCardView)
        debitCardView.heightAnchor.constraint(equalToConstant: 160).isActive = true
        
        // Form fields
        expiryAndCVVStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        expiryAndCVVStack.addArrangedSubview(expiryField)
        expiryAndCVVStack.addArrangedSubview(cvvField)
        
        containerStack.addArrangedSubview(cardHolderField)
        containerStack.addArrangedSubview(cardNumberField)
        containerStack.addArrangedSubview(expiryAndCVVStack)
        containerStack.addArrangedSubview(errorBanner)
        containerStack.addArrangedSubview(saveCardContainer)
        containerStack.addArrangedSubview(payButton)
        
        updateDebitCardVisual()
    }
    
    private func updateDebitCardVisual() {
        debitCardView.update(
            cardNumber: cardNumberField.text ?? "",
            cardName: cardHolderField.text ?? "",
            cardDate: expiryField.text ?? "",
            brand: detectedBrand
        )
    }
    
    // MARK: - Helpers
    
    private func createNoteView(text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(hex: "#FFF8E1")
        container.layer.cornerRadius = Theme.CornerRadius.md
        
        let label = UILabel()
        label.text = "💡 \(text)"
        label.font = Theme.Fonts.regular(11)
        label.textColor = UIColor(hex: "#795548")
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        
        return container
    }
    
    private func formatCardNumberDisplay(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        var result = ""
        for (i, char) in cleaned.enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }
    
    // MARK: - Formatting
    
    private func setupFormatting() {
        cardNumberField.textField.addTarget(self, action: #selector(cardNumberChanged), for: .editingChanged)
        expiryField.textField.addTarget(self, action: #selector(expiryChanged), for: .editingChanged)
        cvvField.textField.addTarget(self, action: #selector(cvvChanged), for: .editingChanged)
        cardHolderField.textField.addTarget(self, action: #selector(cardHolderChanged), for: .editingChanged)
        
        cardNumberField.textField.keyboardType = .numberPad
        expiryField.textField.keyboardType = .numberPad
        cvvField.textField.keyboardType = .numberPad
        cvvField.textField.isSecureTextEntry = true
        
        // Set text field delegates for auto-advance
        cardNumberField.textField.delegate = self
        expiryField.textField.delegate = self
        cvvField.textField.delegate = self
        
        // Card brand icon in the card number field (matches web CardBrandIcon)
        cardBrandIcon.brand = .unknown
        cardNumberField.setRightAccessory(cardBrandIcon)
    }
    
    @objc private func saveCardToggled() {
        isSaveCardChecked.toggle()
        if isSaveCardChecked {
            saveCardCheckbox.backgroundColor = Theme.Colors.primary
            saveCardCheckbox.layer.borderColor = Theme.Colors.primary.cgColor
            if #available(iOS 13.0, *) {
                let checkmark = UIImage(systemName: "checkmark")?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
                saveCardCheckbox.setImage(checkmark, for: .normal)
            }
        } else {
            saveCardCheckbox.backgroundColor = .white
            saveCardCheckbox.layer.borderColor = Theme.Colors.border.cgColor
            saveCardCheckbox.setImage(nil, for: .normal)
        }
    }
    
    private func showApiError(_ message: String) {
        let hint = "\nYou can also try a different payment channel."
        errorBannerLabel.text = message + hint
        errorBanner.isHidden = false
    }
    
    private func hideApiError() {
        errorBanner.isHidden = true
    }
    
    @objc private func cardNumberChanged() {
        guard var text = cardNumberField.text else { return }
        // Strip non-digits
        text = text.filter { $0.isNumber }
        
        // Detect card brand from BIN
        detectedBrand = CardBrandDetector.detect(from: text)
        cardBrandIcon.brand = detectedBrand
        
        // Enforce max length for detected brand
        let maxLen = detectedBrand.maxLength
        text = String(text.prefix(maxLen))
        
        // Format with spaces every 4 digits (Amex: 4-6-5 pattern)
        var formatted = ""
        if detectedBrand == .americanExpress {
            // Amex: 4-6-5 grouping
            for (i, char) in text.enumerated() {
                if i == 4 || i == 10 { formatted += " " }
                formatted.append(char)
            }
        } else {
            for (i, char) in text.enumerated() {
                if i > 0 && i % 4 == 0 { formatted += " " }
                formatted.append(char)
            }
        }
        cardNumberField.text = formatted
        
        // Clear error if user is typing
        cardNumberField.setError(nil)
        
        // Update the 3D card visual + brand logo on card
        updateDebitCardVisual()
        
        // Auto-advance to expiry when card number is complete
        if text.count == maxLen {
            expiryField.textField.becomeFirstResponder()
        }
    }
    
    @objc private func expiryChanged() {
        guard var text = expiryField.text else { return }
        // Strip non-digits
        text = text.filter { $0.isNumber }
        text = String(text.prefix(4))
        
        if text.isEmpty {
            expiryField.text = ""
        } else if text.count == 1 {
            // If single digit > 1, auto-prefix with 0 (matches web)
            if let digit = Int(text), digit > 1 {
                text = "0\(text)"
                expiryField.text = "\(text)/"
                // Already 2 digits + slash, ready for year
            } else {
                expiryField.text = text
            }
        } else if text.count == 2 {
            let month = Int(text) ?? 0
            if month > 12 {
                // Invalid month like "19" → treat as "01/9"
                expiryField.text = "0\(text.prefix(1))/\(text.suffix(1))"
            } else {
                expiryField.text = "\(text)/"
            }
        } else {
            let month = String(text.prefix(2))
            let year = String(text.dropFirst(2))
            expiryField.text = "\(month)/\(year)"
        }
        
        // Clear error if user is typing
        expiryField.setError(nil)
        
        updateDebitCardVisual()
        
        // Auto-advance to CVV when expiry is complete (MM/YY = 4 digits)
        let rawDigits = (expiryField.text ?? "").filter { $0.isNumber }
        if rawDigits.count == 4 {
            cvvField.textField.becomeFirstResponder()
        }
    }
    
    @objc private func cvvChanged() {
        guard let text = cvvField.text else { return }
        let digits = text.filter { $0.isNumber }
        let maxCvv = detectedBrand.cvvLength
        let trimmed = String(digits.prefix(maxCvv))
        cvvField.text = trimmed
        
        // Clear error if user is typing
        cvvField.setError(nil)
        
        // Auto-resign keyboard when CVV is fully filled
        if trimmed.count == maxCvv {
            cvvField.textField.resignFirstResponder()
        }
    }
    
    @objc private func cardHolderChanged() {
        updateDebitCardVisual()
    }
    
    // MARK: - Validation
    
    private func validateCard() -> Bool {
        var valid = true
        
        let cardNumber = (cardNumberField.text ?? "").replacingOccurrences(of: " ", with: "")
        let brand = CardBrandDetector.detect(from: cardNumber)
        
        if cardNumber.count < 13 || cardNumber.count > 19 {
            cardNumberField.setError("Invalid card number")
            valid = false
        } else if !brand.validLengths.contains(cardNumber.count) {
            cardNumberField.setError("Invalid card number length")
            valid = false
        } else if !CardBrandDetector.luhnCheck(cardNumber) && brand != .unionpay {
            cardNumberField.setError("Invalid card number")
            valid = false
        } else {
            cardNumberField.setError(nil)
        }
        
        let expiryRaw = (expiryField.text ?? "").replacingOccurrences(of: "/", with: "")
        if expiryRaw.count != 4 {
            expiryField.setError("Invalid expiry")
            valid = false
        } else {
            let month = Int(expiryRaw.prefix(2)) ?? 0
            let year = Int("20\(expiryRaw.suffix(2))") ?? 0
            if month < 1 || month > 12 {
                expiryField.setError("Invalid month")
                valid = false
            } else {
                // Check if card is expired
                let cal = Calendar.current
                let now = Date()
                let currentMonth = cal.component(.month, from: now)
                let currentYear = cal.component(.year, from: now)
                if year < currentYear || (year == currentYear && month < currentMonth) {
                    expiryField.setError("Card has expired")
                    valid = false
                } else {
                    expiryField.setError(nil)
                }
            }
        }
        
        let cvv = cvvField.text ?? ""
        let requiredCvvLen = brand.cvvLength
        if cvv.count < requiredCvvLen {
            cvvField.setError("Invalid CVV")
            valid = false
        } else {
            cvvField.setError(nil)
        }
        
        return valid
    }
    
    // MARK: - Pay (New Card)
    
    @objc private func payTapped() {
        guard validateCard() else { return }
        
        let cardNumber = (cardNumberField.text ?? "").replacingOccurrences(of: " ", with: "")
        let expiry = (expiryField.text ?? "").replacingOccurrences(of: "/", with: "")
        let expiryMonth = Int(expiry.prefix(2)) ?? 1
        let expiryYear = Int("20\(expiry.suffix(2))") ?? 2025
        let cvv = cvvField.text ?? ""
        let holderName = cardHolderField.text ?? store.config?.fullName ?? ""
        
        guard let monthEnum = ExpirationMonth.from(month: expiryMonth),
              let transactionId = store.transactionId,
              let config = store.config else {
            return
        }
        
        payButton.setLoading(true)
        parentVC?.showLoading(message: "Processing card...")
        store.setStatus(.processing)
        
        let request = ProcessCardRequest(
            cardData: CardDataPayload(
                cardHolderName: holderName,
                cardNumber: cardNumber,
                expirationMonth: monthEnum.rawValue,
                expirationYear: expiryYear,
                cvv: cvv
            ),
            amountData: AmountDataPayload(
                authorizedAmount: store.requestAmount,
                totalAmount: store.requestAmount,
                currency: config.currency.rawValue
            ),
            deviceInformation: DeviceInformationPayload.default(),
            saveCard: isSaveCardChecked
        )
        
        hideApiError()
        
        api.processCard(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.payButton.setLoading(false)
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let response):
                    self.handleCardResponse(response)
                case .failure(let error):
                    self.showApiError(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Card Response Handling
    
    private func handleCardResponse(_ response: ProcessCardResponse) {
        guard let stage = response.stage else {
            parentVC?.startPolling()
            return
        }
        switch stage {
        case .deviceCollection:
            if let embedable = response.embedable {
                referenceId = nil
                if let token = embedable.accessToken {
                    extractReferenceId(from: token)
                }
                loadDeviceCollectionHTML(embedable.html)
            }
            
        case .cardAuthentication3D:
            if let embedable = response.embedable {
                present3DSPopup(html: embedable.html)
            }
            
        case .completed:
            // Web always polls to confirm – never shows success directly
            parentVC?.startPolling()
            
        case .pending:
            parentVC?.startPolling()
            
        case .failed:
            showApiError(response.message ?? ErrorMessages.transactionFailed)
        }
    }
    
    // MARK: - 3DS / Device Collection
    
    /// JavaScript bridge for the hidden device-collection webView
    private static let postMessageBridgeScript = """
    (function() {
        var origPostMessage = window.postMessage.bind(window);
        window.postMessage = function(message, targetOrigin, transfer) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.paymentSDK) {
                    window.webkit.messageHandlers.paymentSDK.postMessage(message);
                }
            } catch(e) {}
            return origPostMessage(message, targetOrigin, transfer);
        };
        window.addEventListener('message', function(event) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.paymentSDK) {
                    window.webkit.messageHandlers.paymentSDK.postMessage(event.data);
                }
            } catch(e) {}
        });
    })();
    """
    
    // MARK: Load hidden device-collection HTML
    
    private func loadDeviceCollectionHTML(_ html: String) {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        let handler = WebViewMessageHandler { [weak self] message in
            self?.completeDeviceCollection()
        }
        config.userContentController.add(handler, name: "paymentSDK")
        
        let bridgeScript = WKUserScript(
            source: Self.postMessageBridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(bridgeScript)
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        
        deviceCollectionContainer.subviews.forEach { $0.removeFromSuperview() }
        deviceCollectionContainer.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: deviceCollectionContainer.topAnchor),
            wv.leadingAnchor.constraint(equalTo: deviceCollectionContainer.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: deviceCollectionContainer.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: deviceCollectionContainer.bottomAnchor),
        ])
        
        deviceCollectionWebView = wv
        deviceCollectionCompleted = false
        wv.loadHTMLString(html, baseURL: nil)
        
        // 3-second auto-complete (matches web EmbeddableFrame's 3s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.completeDeviceCollection()
        }
        // 60-second fallback timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.completeDeviceCollection()
        }
    }
    
    // MARK: Present 3DS challenge in a popup
    
    private func present3DSPopup(html: String) {
        let popup = ThreeDSPopupViewController(html: html, type: "3DS_CHALLENGE")
        popup.delegate = self
        threeDSPopup = popup
        
        // Present from the topmost VC (parent payment controller or self)
        let presenter = parentVC ?? self
        presenter.present(popup, animated: true)
    }
    
    private func extractReferenceId(from jwt: String) {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return }
        
        var base64 = String(parts[1])
        while base64.count % 4 != 0 { base64 += "=" }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let refId = json["ReferenceId"] as? String else {
            return
        }
        referenceId = refId
    }
    

    
    /// Proceed with 3DS authentication after device collection.
    /// Uses a flag to ensure it only runs once (multiple triggers: JS message, 3s timer, 60s fallback).
    private func completeDeviceCollection() {
        guard !deviceCollectionCompleted else { return }
        deviceCollectionCompleted = true
        proceedWith3DSAuthentication()
    }
    
    private func proceedWith3DSAuthentication() {
        guard let transactionId = store.transactionId,
              let systemTxRef = store.systemTxRef,
              let refId = referenceId else {
            parentVC?.startPolling()
            return
        }
        
        parentVC?.showLoading(message: "Authenticating...")
        
        let request = AuthenticateCardRequest(
            clientReferenceInformationCode: systemTxRef,
            consumerAuthenticationInformation: ConsumerAuthenticationInfo(
                deviceChannel: "BROWSER",
                referenceId: refId,
                transactionMode: "eCommerce",
                returnUrl: "https://payment-gateway.netapps.ng/payment-complete"
            )
        )
        
        api.authenticateCard(transactionId: transactionId, request: request) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.parentVC?.hideLoading()
                
                switch result {
                case .success(let response):
                    if response.authenticationRequired == true, let embedable = response.embedable {
                        self.present3DSPopup(html: embedable.html)
                    } else if let stage = response.stage {
                        switch stage {
                        case .completed:
                            // Web always polls to confirm – never shows success directly
                            self.parentVC?.startPolling()
                        case .pending:
                            self.parentVC?.startPolling()
                        case .failed:
                            self.showApiError(response.message ?? ErrorMessages.transactionFailed)
                        default:
                            self.parentVC?.startPolling()
                        }
                    } else {
                        self.parentVC?.startPolling()
                    }
                    
                case .failure(let error):
                    self.showApiError(error.message.isEmpty
                        ? "Authentication failed. Please try again."
                        : error.message)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate (auto-advance + focus styling)

extension CardPaymentViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == cardNumberField.textField {
            cardNumberField.setActive(true)
        } else if textField == expiryField.textField {
            expiryField.setActive(true)
        } else if textField == cvvField.textField {
            cvvField.setActive(true)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == cardNumberField.textField {
            cardNumberField.setActive(false)
        } else if textField == expiryField.textField {
            expiryField.setActive(false)
        } else if textField == cvvField.textField {
            cvvField.setActive(false)
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Allow backspace (empty string)
        guard !string.isEmpty else { return true }
        
        // For card number, expiry, and CVV fields – only allow digits
        if textField == cardNumberField.textField || textField == expiryField.textField || textField == cvvField.textField {
            let allowed = CharacterSet.decimalDigits
            let filtered = string.unicodeScalars.filter { allowed.contains($0) }
            
            if filtered.count != string.unicodeScalars.count {
                // Pasted text contains non-digits – strip them and insert digits only
                let digitsOnly = String(string.unicodeScalars.filter { allowed.contains($0) })
                if digitsOnly.isEmpty { return false }
                
                // Manually insert the stripped digits
                if let currentText = textField.text,
                   let swiftRange = Range(range, in: currentText) {
                    textField.text = currentText.replacingCharacters(in: swiftRange, with: digitsOnly)
                    // Fire the editingChanged action so formatting is applied
                    textField.sendActions(for: .editingChanged)
                }
                return false  // We handled it manually
            }
        }
        return true
    }
}

// MARK: - WKNavigationDelegate (device collection only)

extension CardPaymentViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Device collection navigations are silent – nothing to do here
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }
}

// MARK: - ThreeDSPopupDelegate

extension CardPaymentViewController: ThreeDSPopupDelegate {
    func threeDSPopupDidComplete() {
        threeDSPopup = nil
        parentVC?.startPolling()
    }
    
    func threeDSPopupDidCancel() {
        threeDSPopup = nil
        // Show a user-friendly message and let them retry
        showApiError("Verification cancelled. You can try again.")
    }
    
    func threeDSPopupDidReceiveMessage(_ message: Any, type: String) {
        // 3DS challenge messages – nothing to handle for now
    }
}

// MARK: - WebView Message Handler

private final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    private let handler: (Any) -> Void
    
    init(handler: @escaping (Any) -> Void) {
        self.handler = handler
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        handler(message.body)
    }
}

// MARK: - Tap Gesture with Card Data

private final class CardTapGesture: UITapGestureRecognizer {
    var savedCard: SavedCard?
    var testCard: TestCard?
}

// MARK: - 3D Debit Card Visual (matches web DebitCard.tsx)

final class DebitCardVisualView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    private let cardContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.29).cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let netappsLabel: UILabel = {
        let label = UILabel()
        label.text = "NETAPPS"
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Card brand icon on the top-right of the debit card visual
    private let brandIconView: CardBrandIconView = {
        let view = CardBrandIconView(frame: CGRect(x: 0, y: 0, width: 40, height: 26))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.brand = .unknown
        return view
    }()
    
    private let cardNumberLabel: UILabel = {
        let label = UILabel()
        label.text = "0000 0000 0000 0000"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Name on card"
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardDateLabel: UILabel = {
        let label = UILabel()
        label.text = "MM/YY"
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Gradient: matches web linear-gradient(108.76deg, #BBE6E4, #084B83, #42BFDD)
        gradientLayer.colors = [
            UIColor(hex: "#BBE6E4").cgColor,
            UIColor(hex: "#084B83").cgColor,
            UIColor(hex: "#42BFDD").cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
        layer.cornerRadius = 12
        clipsToBounds = true
        
        addSubview(cardContainer)
        cardContainer.addSubview(netappsLabel)
        cardContainer.addSubview(brandIconView)
        cardContainer.addSubview(cardNumberLabel)
        cardContainer.addSubview(cardNameLabel)
        cardContainer.addSubview(cardDateLabel)
        
        NSLayoutConstraint.activate([
            cardContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardContainer.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.88),
            cardContainer.heightAnchor.constraint(equalToConstant: 128),
            
            netappsLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            netappsLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            
            // Brand icon top-right corner
            brandIconView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 12),
            brandIconView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            brandIconView.widthAnchor.constraint(equalToConstant: 40),
            brandIconView.heightAnchor.constraint(equalToConstant: 26),
            
            cardNumberLabel.bottomAnchor.constraint(equalTo: cardNameLabel.topAnchor, constant: -8),
            cardNumberLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            
            cardNameLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -14),
            cardNameLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            
            cardDateLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -14),
            cardDateLabel.leadingAnchor.constraint(equalTo: cardNameLabel.trailingAnchor, constant: 12),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    func update(cardNumber: String, cardName: String, cardDate: String, brand: CardBrand = .unknown) {
        let cleaned = cardNumber.replacingOccurrences(of: " ", with: "")
        let padded = cleaned.padding(toLength: 16, withPad: "0", startingAt: 0)
        var formatted = ""
        for (i, char) in padded.enumerated() {
            if i > 0 && i % 4 == 0 { formatted += " " }
            formatted.append(char)
        }
        cardNumberLabel.text = String(formatted.prefix(19))
        cardNameLabel.text = cardName.isEmpty ? "Name on card" : cardName
        cardDateLabel.text = cardDate.isEmpty ? "MM/YY" : cardDate
        brandIconView.brand = brand
    }
}
