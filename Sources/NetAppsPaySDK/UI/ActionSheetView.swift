// ============================================================
// ACTION SHEET - Custom bottom sheet picker
// Replaces UIAlertController(.actionSheet) with a searchable,
// scrollable bottom sheet matching the app's visual style.
// ============================================================

import UIKit

// MARK: - Data Model

struct ActionSheetOption {
    let label: String
    let value: String
    let description: String?
    
    init(label: String, value: String, description: String? = nil) {
        self.label = label
        self.value = value
        self.description = description
    }
}

// MARK: - ActionSheetViewController

final class ActionSheetViewController: UIViewController {
    
    // MARK: - Configuration
    
    private let sheetTitle: String
    private var options: [ActionSheetOption]
    private var filteredOptions: [ActionSheetOption]
    private let selectedValue: String?
    private let onSelect: (ActionSheetOption) -> Void
    private let searchThreshold = 6 // show search when > N options
    
    // MARK: - UI Elements
    
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.background
        v.layer.cornerRadius = Theme.CornerRadius.lg
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let dragHandle: UIView = {
        let v = UIView()
        v.backgroundColor = Theme.Colors.border
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Fonts.subtitle
        l.textColor = Theme.Colors.text
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = Theme.Colors.textMuted
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        btn.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let searchField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Search..."
        tf.font = Theme.Fonts.body
        tf.textColor = Theme.Colors.text
        tf.backgroundColor = Theme.Colors.backgroundAlt
        tf.layer.borderWidth = 1
        tf.layer.borderColor = Theme.Colors.borderLight.cgColor
        tf.layer.cornerRadius = Theme.CornerRadius.md
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.rightViewMode = .always
        tf.clearButtonMode = .whileEditing
        tf.autocorrectionType = .no
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .singleLine
        tv.separatorColor = Theme.Colors.borderLight
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tv.backgroundColor = .clear
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 52
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.setTitleColor(Theme.Colors.error, for: .normal)
        btn.titleLabel?.font = Theme.Fonts.semibold(14)
        btn.backgroundColor = Theme.Colors.backgroundAlt
        btn.layer.cornerRadius = Theme.CornerRadius.md
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "No results found"
        l.font = Theme.Fonts.body
        l.textColor = Theme.Colors.textMuted
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private var containerBottomConstraint: NSLayoutConstraint?
    
    // MARK: - Init
    
    init(title: String,
         options: [ActionSheetOption],
         selectedValue: String? = nil,
         onSelect: @escaping (ActionSheetOption) -> Void) {
        self.sheetTitle = title
        self.options = options
        self.filteredOptions = options
        self.selectedValue = selectedValue
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        setupUI()
        setupActions()
        setupTable()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Dimmed background
        let dimView = UIView()
        dimView.backgroundColor = Theme.Colors.overlay
        dimView.alpha = 0
        dimView.tag = 100
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        dimView.addGestureRecognizer(tap)
        
        // Container
        view.addSubview(containerView)
        let bottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 600)
        containerBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.7),
        ])
        
        // Drag handle
        containerView.addSubview(dragHandle)
        NSLayoutConstraint.activate([
            dragHandle.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            dragHandle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: Theme.Sizes.dragHandleWidth),
            dragHandle.heightAnchor.constraint(equalToConstant: Theme.Sizes.dragHandleHeight),
        ])
        
        // Header row
        containerView.addSubview(titleLabel)
        containerView.addSubview(closeButton)
        titleLabel.text = sheetTitle
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        let showSearch = options.count > searchThreshold
        
        // Search field (conditional)
        if showSearch {
            containerView.addSubview(searchField)
            NSLayoutConstraint.activate([
                searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
                searchField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
                searchField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                searchField.heightAnchor.constraint(equalToConstant: 40),
            ])
        }
        
        // Table view
        containerView.addSubview(tableView)
        containerView.addSubview(emptyLabel)
        
        let tableTopAnchor = showSearch
            ? searchField.bottomAnchor
            : titleLabel.bottomAnchor
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: tableTopAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
        
        // Cancel button
        containerView.addSubview(cancelButton)
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
        ])
        
        // Calculate table height: cap at a reasonable size
        let maxTableRows: CGFloat = 6
        let estimatedRowH: CGFloat = 52
        let tableHeight = min(CGFloat(options.count), maxTableRows) * estimatedRowH
        tableView.heightAnchor.constraint(equalToConstant: max(tableHeight, estimatedRowH)).isActive = true
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.delegate = self
        
        // Swipe down to dismiss
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(pan)
    }
    
    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ActionSheetCell.self, forCellReuseIdentifier: ActionSheetCell.reuseId)
    }
    
    // MARK: - Animation
    
    private func animateIn() {
        view.layoutIfNeeded()
        containerBottomConstraint?.constant = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.viewWithTag(100)?.alpha = 1
            self.view.layoutIfNeeded()
        } completion: { _ in
            // Scroll to selected item if there is one
            if let selectedValue = self.selectedValue,
               let idx = self.filteredOptions.firstIndex(where: { $0.value == selectedValue }) {
                self.tableView.scrollToRow(at: IndexPath(row: idx, section: 0), at: .middle, animated: true)
            }
        }
    }
    
    @objc private func dismissSheet() {
        searchField.resignFirstResponder()
        containerBottomConstraint?.constant = 600
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.view.viewWithTag(100)?.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }
    
    // MARK: - Search
    
    @objc private func searchChanged() {
        let query = (searchField.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            filteredOptions = options
        } else {
            filteredOptions = options.filter { $0.label.lowercased().contains(query) }
        }
        emptyLabel.isHidden = !filteredOptions.isEmpty
        tableView.reloadData()
    }
    
    // MARK: - Pan Gesture (swipe to dismiss)
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: containerView)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                containerBottomConstraint?.constant = translation.y
                view.layoutIfNeeded()
                let progress = min(translation.y / 300, 1)
                view.viewWithTag(100)?.alpha = 1 - progress * 0.5
            }
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: containerView)
            if translation.y > 100 || velocity.y > 500 {
                dismissSheet()
            } else {
                containerBottomConstraint?.constant = 0
                UIView.animate(withDuration: 0.2) {
                    self.view.viewWithTag(100)?.alpha = 1
                    self.view.layoutIfNeeded()
                }
            }
        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension ActionSheetViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ActionSheetCell.reuseId, for: indexPath) as! ActionSheetCell
        let option = filteredOptions[indexPath.row]
        let isSelected = option.value == selectedValue
        cell.configure(option: option, isSelected: isSelected)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let option = filteredOptions[indexPath.row]
        onSelect(option)
        dismissSheet()
    }
}

// MARK: - UITextFieldDelegate

extension ActionSheetViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - ActionSheetCell

private final class ActionSheetCell: UITableViewCell {
    static let reuseId = "ActionSheetCell"
    
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Fonts.body
        l.textColor = Theme.Colors.text
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let descLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.Fonts.captionSmall
        l.textColor = Theme.Colors.textMuted
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let checkImageView: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iv.image = UIImage(systemName: "checkmark", withConfiguration: config)
        iv.tintColor = Theme.Colors.primary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()
    
    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 2
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .default
        
        let selectedBg = UIView()
        selectedBg.backgroundColor = Theme.Colors.backgroundAlt
        selectedBackgroundView = selectedBg
        
        contentStack.addArrangedSubview(nameLabel)
        contentStack.addArrangedSubview(descLabel)
        
        contentView.addSubview(contentStack)
        contentView.addSubview(checkImageView)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: checkImageView.leadingAnchor, constant: -8),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            checkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(option: ActionSheetOption, isSelected: Bool) {
        nameLabel.text = option.label
        
        if let desc = option.description, !desc.isEmpty {
            descLabel.text = desc
            descLabel.isHidden = false
        } else {
            descLabel.isHidden = true
        }
        
        checkImageView.isHidden = !isSelected
        
        if isSelected {
            nameLabel.font = Theme.Fonts.semibold(14)
            nameLabel.textColor = Theme.Colors.primary
        } else {
            nameLabel.font = Theme.Fonts.body
            nameLabel.textColor = Theme.Colors.text
        }
    }
}

// MARK: - Convenience Presenter

extension UIViewController {
    /// Shows a custom action sheet bottom picker.
    func presentActionSheet(
        title: String,
        options: [ActionSheetOption],
        selectedValue: String? = nil,
        onSelect: @escaping (ActionSheetOption) -> Void
    ) {
        let sheet = ActionSheetViewController(
            title: title,
            options: options,
            selectedValue: selectedValue,
            onSelect: onSelect
        )
        present(sheet, animated: false)
    }
}
