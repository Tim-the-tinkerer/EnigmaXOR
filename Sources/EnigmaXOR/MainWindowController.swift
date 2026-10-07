import AppKit
import UniformTypeIdentifiers

final class MainWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Enigma XOR"
        window.center()
        window.backgroundColor = Theme.background
        window.minSize = NSSize(width: 700, height: 640)
        window.isReleasedWhenClosed = false

        let viewController = MainViewController()
        super.init(window: window)
        window.contentViewController = viewController
    }

    var mainViewController: MainViewController? {
        contentViewController as? MainViewController
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Compact single-window layout modeled on EnigmaVault 2.5: stacked panels,
/// window sized to content, no custom archive format.
final class MainViewController: NSViewController {
    private var configuration = EnigmaConfiguration.maximumSecurity
    private var sourceName = "message"
    private var lastOutputWasDecipher = false
    private weak var saveOutputButton: NSButton?
    private weak var outputTitleLabel: NSTextField?

    private let statusLabel = NSTextField.makeLabel("Ready.")
    private let selfTestLabel = NSTextField.makeLabel("", muted: true)
    private let modeControl = NSSegmentedControl(
        labels: ["M3 (3 rotors)", "M4 Naval (4 rotors)"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let rotorsField = NSTextField.makeInput(placeholder: "I-II-III")
    private let reflectorPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let ringsField = NSTextField.makeInput(placeholder: "AAA")
    private let positionsField = NSTextField.makeInput(placeholder: "AAA")
    private let plugsField = NSTextField.makeInput(placeholder: "AB CD EF (up to 10 pairs)")
    private let xorField = NSTextField.makeInput(placeholder: "A–Z, empty = historical Enigma")
    private let groupFivesCheckbox = NSButton(checkboxWithTitle: "Group in fives", target: nil, action: nil)
    private let spellNumbersCheckbox = NSButton(checkboxWithTitle: "Spell numbers in English", target: nil, action: nil)

    private var inputTextView: NSTextView!
    private var outputTextView: NSTextView!

    private weak var rootStack: NSStackView?
    private var hasSizedWindow = false

    private static let contentMargin: CGFloat = 16
    private static let contentWidth: CGFloat = 728

    override func loadView() {
        let dropView = FileDropView(frame: NSRect(x: 0, y: 0, width: 760, height: 980))
        dropView.layer?.backgroundColor = Theme.background.cgColor
        dropView.onFilesDropped = { [weak self] urls in
            self?.openFiles(urls)
        }
        dropView.layer?.masksToBounds = false
        view = dropView

        let root = NSStackView()
        root.translatesAutoresizingMaskIntoConstraints = false
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.setHuggingPriority(.required, for: .vertical)
        rootStack = root
        view.addSubview(root)

        root.addArrangedSubview(makeHeader())
        root.addArrangedSubview(makeMachinePanel())
        root.addArrangedSubview(makeMessagePanel())
        root.addArrangedSubview(makeOutputPanel())
        root.addArrangedSubview(makeActionPanel())
        root.addArrangedSubview(makeKeyPanel())
        root.addArrangedSubview(makeStatusPanel())

        let m = Self.contentMargin
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: m),
            root.widthAnchor.constraint(equalToConstant: Self.contentWidth)
        ])

        configureControls()
        refreshMachineFields()
        runSelfTest()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !hasSizedWindow,
           let window = view.window,
           let root = rootStack {
            hasSizedWindow = true

            view.layoutSubtreeIfNeeded()
            let laidOut = root.fittingSize.height
            let frameH = root.frame.height
            let contentH = max(laidOut, frameH, 1)
            let m = Self.contentMargin
            let height = ceil(contentH + m * 2)
            window.setContentSize(NSSize(width: 760, height: height))
            window.minSize = NSSize(width: 700, height: min(height, 640))
            window.center()
        }
        sizeTextViewsToScrollers()
        view.window?.makeFirstResponder(inputTextView)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        sizeTextViewsToScrollers()
    }

    private func panelInsets() -> NSEdgeInsets {
        NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
    }

    // MARK: Panels

    private func makeHeader() -> NSView {
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        column.translatesAutoresizingMaskIntoConstraints = false

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 12

        let title = NSTextField(labelWithString: "Enigma XOR")
        title.font = Theme.title
        title.textColor = Theme.accent
        title.setContentCompressionResistancePriority(.required, for: .vertical)
        topRow.addArrangedSubview(title)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topRow.addArrangedSubview(spacer)

        let helpButton = NSButton(title: "How It Works", target: self, action: #selector(showDescription))
        helpButton.bezelStyle = .rounded
        topRow.addArrangedSubview(helpButton)

        topRow.translatesAutoresizingMaskIntoConstraints = false
        topRow.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        column.addArrangedSubview(topRow)

        let subtitle = NSTextField(labelWithString: "Historical M3 / M4, then a bitwise XOR — plaintext in, ciphertext out")
        subtitle.font = Theme.body
        subtitle.textColor = Theme.muted
        column.addArrangedSubview(subtitle)

        column.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        return column
    }

    private func makeMachinePanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 8
        panel.edgeInsets = panelInsets()
        panel.applyPanelStyle()

        panel.addArrangedSubview(sectionTitle("MACHINE SETTINGS"))

        modeControl.selectedSegment = configuration.mode == .m3 ? 0 : 1
        modeControl.target = self
        modeControl.action = #selector(modeChanged)
        panel.addArrangedSubview(modeControl)

        panel.addArrangedSubview(fieldRow(label: "Rotors", field: rotorsField))
        panel.addArrangedSubview(popupRow(label: "Reflector", popup: reflectorPopup))
        panel.addArrangedSubview(fieldRow(label: "Rings", field: ringsField))
        panel.addArrangedSubview(fieldRow(label: "Positions", field: positionsField))
        panel.addArrangedSubview(fieldRow(label: "Plugboard", field: plugsField))
        panel.addArrangedSubview(fieldRow(label: "XOR key", field: xorField))

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let wikiButton = NSButton.makeSecondary("Wiki Test Vector")
        wikiButton.target = self
        wikiButton.action = #selector(applyWikiTestVector)
        buttonRow.addArrangedSubview(wikiButton)

        let randomPos = NSButton.makeSecondary("Randomize Positions")
        randomPos.target = self
        randomPos.action = #selector(randomizePositions)
        buttonRow.addArrangedSubview(randomPos)

        let randomAll = NSButton.makeSecondary("Randomize Machine")
        randomAll.target = self
        randomAll.action = #selector(randomizeMachine)
        buttonRow.addArrangedSubview(randomAll)

        panel.addArrangedSubview(buttonRow)
        panel.addArrangedSubview(selfTestLabel)
        return panel
    }

    private func makeMessagePanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 8
        panel.edgeInsets = panelInsets()
        panel.applyPanelStyle()

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.addArrangedSubview(sectionTitle("MESSAGE"))

        spellNumbersCheckbox.state = .on
        spellNumbersCheckbox.attributedTitle = NSAttributedString(
            string: "Spell numbers in English",
            attributes: [.foregroundColor: Theme.text, .font: Theme.body]
        )
        header.addArrangedSubview(spellNumbersCheckbox)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        panel.addArrangedSubview(header)

        let dropHint = NSTextField(wrappingLabelWithString: "Type, paste, or drag a text file. Digits in a message become English words before enciphering. Ciphertext may contain the digits 2–7. A settings or codebook file loads the machine instead.")
        dropHint.preferredMaxLayoutWidth = Self.contentWidth - 8
        dropHint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        dropHint.textColor = Theme.muted
        dropHint.preferredMaxLayoutWidth = 696
        panel.addArrangedSubview(dropHint)

        let (scroll, textView) = makeTextView(placeholderHint: true)
        inputTextView = textView
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 696).isActive = true
        panel.addArrangedSubview(scroll)
        return panel
    }

    private func makeOutputPanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 8
        panel.edgeInsets = panelInsets()
        panel.applyPanelStyle()

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        let title = sectionTitle("CIPHERTEXT")
        outputTitleLabel = title
        header.addArrangedSubview(title)

        groupFivesCheckbox.state = .on
        groupFivesCheckbox.attributedTitle = NSAttributedString(
            string: "Group in fives",
            attributes: [.foregroundColor: Theme.text, .font: Theme.body]
        )
        header.addArrangedSubview(groupFivesCheckbox)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        panel.addArrangedSubview(header)

        let (scroll, textView) = makeTextView(placeholderHint: false)
        outputTextView = textView
        textView.isEditable = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 696).isActive = true
        panel.addArrangedSubview(scroll)
        return panel
    }

    private func makeActionPanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .horizontal
        panel.alignment = .centerY
        panel.spacing = 12
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true

        let encipherButton = NSButton.makePrimary("Encipher")
        encipherButton.target = self
        encipherButton.action = #selector(encipher)
        panel.addArrangedSubview(encipherButton)

        let decipherButton = NSButton.makePrimary("Decipher")
        decipherButton.target = self
        decipherButton.action = #selector(decipher)
        panel.addArrangedSubview(decipherButton)

        let swapButton = NSButton.makeSecondary("Swap")
        swapButton.target = self
        swapButton.action = #selector(swapTexts)
        panel.addArrangedSubview(swapButton)

        let clearButton = NSButton.makeSecondary("Clear")
        clearButton.target = self
        clearButton.action = #selector(clearTexts)
        panel.addArrangedSubview(clearButton)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        panel.addArrangedSubview(spacer)

        let copyButton = NSButton.makeSecondary("Copy Output")
        copyButton.target = self
        copyButton.action = #selector(copyOutput)
        panel.addArrangedSubview(copyButton)

        let saveButton = NSButton.makePrimary("Save Ciphertext…")
        saveButton.target = self
        saveButton.action = #selector(saveCiphertext)
        saveOutputButton = saveButton
        panel.addArrangedSubview(saveButton)

        return panel
    }

    private func makeKeyPanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 8
        panel.edgeInsets = panelInsets()
        panel.applyPanelStyle()

        panel.addArrangedSubview(sectionTitle("KEY MATERIAL"))

        let hint = NSTextField(labelWithString: "Ciphertext is a plain text file. Export settings or a codebook so it can be read later.")
        hint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hint.textColor = Theme.muted
        hint.preferredMaxLayoutWidth = 696
        panel.addArrangedSubview(hint)

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10

        let exportSettingsButton = NSButton.makeSecondary("Export Settings…")
        exportSettingsButton.target = self
        exportSettingsButton.action = #selector(exportSettings)
        row.addArrangedSubview(exportSettingsButton)

        let exportBookButton = NSButton.makeSecondary("Export Codebook…")
        exportBookButton.target = self
        exportBookButton.action = #selector(exportCodebook)
        row.addArrangedSubview(exportBookButton)

        let importSettingsButton = NSButton.makeSecondary("Import Settings…")
        importSettingsButton.target = self
        importSettingsButton.action = #selector(importSettings)
        row.addArrangedSubview(importSettingsButton)

        panel.addArrangedSubview(row)
        return panel
    }

    private func makeStatusPanel() -> NSView {
        let panel = NSStackView()
        panel.orientation = .vertical
        panel.alignment = .leading
        panel.spacing = 6
        panel.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        panel.applyPanelStyle()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.addArrangedSubview(sectionTitle("STATUS"))

        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(statusLabel)

        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: Self.contentWidth - 28).isActive = true
        panel.addArrangedSubview(row)
        return panel
    }

    // MARK: Controls

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = Theme.muted
        return label
    }

    private func fieldRow(label: String, field: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let name = NSTextField(labelWithString: label)
        name.font = Theme.body
        name.textColor = Theme.text
        name.widthAnchor.constraint(equalToConstant: 90).isActive = true

        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 580).isActive = true

        row.addArrangedSubview(name)
        row.addArrangedSubview(field)
        return row
    }

    private func popupRow(label: String, popup: NSPopUpButton) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY

        let name = NSTextField(labelWithString: label)
        name.font = Theme.body
        name.textColor = Theme.text
        name.widthAnchor.constraint(equalToConstant: 90).isActive = true

        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(equalToConstant: 220).isActive = true

        row.addArrangedSubview(name)
        row.addArrangedSubview(popup)
        return row
    }

    private func makeTextView(placeholderHint: Bool) -> (NSScrollView, NSTextView) {
        let initial = NSRect(x: 0, y: 0, width: 696, height: 110)
        let textView = DropTextView(frame: initial)
        textView.onFilesDropped = { [weak self] urls in
            self?.openFiles(urls)
        }
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = Theme.monospaced
        textView.textColor = Theme.text
        textView.backgroundColor = Theme.field
        textView.insertionPointColor = Theme.accent
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = NSSize(width: 0, height: 110)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 696, height: CGFloat.greatestFiniteMagnitude)
        if placeholderHint {
            textView.string = ""
        }

        let scroll = FileDropScrollView(frame: initial)
        scroll.onFilesDropped = { [weak self] urls in
            self?.openFiles(urls)
        }
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.documentView = textView
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.field
        return (scroll, textView)
    }

    private func sizeTextViewsToScrollers() {
        for textView in [inputTextView, outputTextView] {
            guard let textView, let scroll = textView.enclosingScrollView else { continue }
            let width = max(scroll.contentSize.width, 1)
            let minHeight = max(scroll.contentSize.height, 1)
            textView.minSize = NSSize(width: width, height: minHeight)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            var frame = textView.frame
            frame.size.width = width
            if frame.size.height < minHeight {
                frame.size.height = minHeight
            }
            textView.frame = frame
            textView.textContainer?.containerSize = NSSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    private func configureControls() {
        reflectorPopup.removeAllItems()
        reflectorPopup.addItems(withTitles: ["UKW-B", "UKW-C", "UKW-B Thin", "UKW-C Thin"])
        reflectorPopup.target = self
        reflectorPopup.action = #selector(reflectorChanged)
        updateReflectorPopupForMode(configuration.mode)
    }

    private func refreshMachineFields() {
        rotorsField.stringValue = configuration.rotorNames.joined(separator: "-")
        ringsField.stringValue = configuration.rings
        positionsField.stringValue = configuration.positions
        plugsField.stringValue = configuration.plugPairs.joined(separator: " ")
        xorField.stringValue = configuration.xorKey
        modeControl.selectedSegment = configuration.mode == .m3 ? 0 : 1
        updateReflectorPopupForMode(configuration.mode)
        updateReflectorPopupSelection()
    }

    private func updateReflectorPopupSelection() {
        let mapping = ["B": 0, "C": 1, "B-Thin": 2, "C-Thin": 3]
        reflectorPopup.selectItem(at: mapping[configuration.reflector] ?? 0)
    }

    private func updateReflectorPopupForMode(_ mode: EnigmaMode) {
        let naval = mode == .m4
        if let item = reflectorPopup.item(at: 0) { item.isEnabled = !naval }
        if let item = reflectorPopup.item(at: 1) { item.isEnabled = !naval }
        if let item = reflectorPopup.item(at: 2) { item.isEnabled = naval }
        if let item = reflectorPopup.item(at: 3) { item.isEnabled = naval }
        let index = reflectorPopup.indexOfSelectedItem
        if naval, index == 0 || index == 1 {
            reflectorPopup.selectItem(at: index == 1 ? 3 : 2)
        } else if !naval, index >= 2 {
            reflectorPopup.selectItem(at: index == 3 ? 1 : 0)
        }
    }

    private func reflectorValueFromPopup() -> String {
        let naval = modeControl.selectedSegment == 1
        switch reflectorPopup.indexOfSelectedItem {
        case 1: return naval ? "C-Thin" : "C"
        case 2: return naval ? "B-Thin" : "B"
        case 3: return naval ? "C-Thin" : "C"
        default: return naval ? "B-Thin" : "B"
        }
    }

    private func currentConfigurationFromUI() throws -> EnigmaConfiguration {
        let rotorNames = rotorsField.stringValue
            .split(whereSeparator: { $0 == "-" || $0 == " " || $0 == "," })
            .map { String($0) }
            .filter { !$0.isEmpty }

        let mode: EnigmaMode = modeControl.selectedSegment == 0 ? .m3 : .m4
        let config = EnigmaConfiguration(
            mode: mode,
            rotorNames: rotorNames,
            reflector: reflectorValueFromPopup(),
            rings: ringsField.stringValue.replacingOccurrences(of: " ", with: ""),
            positions: positionsField.stringValue.replacingOccurrences(of: " ", with: ""),
            plugPairs: EnigmaValidation.parsePlugPairTokens(plugsField.stringValue),
            xorKey: xorField.stringValue
        )
        configuration = try config.validated()
        return configuration
    }

    private func runSelfTest() {
        if EnigmaSelfTest.passed() {
            selfTestLabel.stringValue = "Self-test passed: AAAAA → BDZGO, U-264, XOR"
            selfTestLabel.textColor = Theme.accent
        } else {
            selfTestLabel.stringValue = "Self-test failed — machine implementation may be incorrect."
            selfTestLabel.textColor = .systemRed
        }
    }

    private func setStatus(_ text: String, isError: Bool = false) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? .systemRed : Theme.text
    }

    // MARK: Cipher

    @objc func encipher() {
        process(
            deciphering: false,
            spellNumbers: spellNumbersCheckbox.state == .on,
            groupOutput: groupFivesCheckbox.state == .on
        )
    }

    @objc func decipher() {
        process(deciphering: true, spellNumbers: false, groupOutput: groupFivesCheckbox.state == .on)
    }

    private func process(deciphering: Bool, spellNumbers: Bool, groupOutput: Bool) {
        do {
            let config = try currentConfigurationFromUI()
            let machine = try EnigmaMachine(configuration: config)
            let symbols: String
            let result: String
            if deciphering {
                symbols = EnigmaText.cipherSymbols(from: inputTextView.string)
                guard !symbols.isEmpty else {
                    setStatus("No ciphertext symbols. Use A–Z, and digits 2–7 where the XOR overflowed.", isError: true)
                    return
                }
                result = machine.decipherMessage(symbols)
            } else {
                symbols = EnigmaText.letters(from: inputTextView.string, spellNumbers: spellNumbers)
                guard !symbols.isEmpty else {
                    setStatus("No letters in the message. Enigma only ciphers A–Z.", isError: true)
                    return
                }
                result = machine.encipherMessage(symbols)
            }
            outputTextView.string = groupOutput ? EnigmaText.grouped(result) : result
            lastOutputWasDecipher = deciphering
            refreshOutputChrome()
            let spelled = spellNumbers && inputTextView.string.contains(where: \.isNumber)
            let note = spelled ? " Numbers spelled in English." : ""
            let xorNote = config.xorKey.isEmpty ? " No XOR." : " XOR \(config.xorKey)."
            let mismatch = result.contains("?") ? " A ? is a letter this XOR key cannot recover." : ""
            setStatus("\(symbols.count) symbols.\(note)\(xorNote)\(mismatch) Windows now \(machine.currentPositions()). Reset Grundstellung for the next message.")
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    private func refreshOutputChrome() {
        outputTitleLabel?.stringValue = lastOutputWasDecipher ? "DECIPHERED" : "CIPHERTEXT"
        saveOutputButton?.title = lastOutputWasDecipher ? "Save Deciphered…" : "Save Ciphertext…"
    }

    @objc func swapTexts() {
        let input = inputTextView.string
        inputTextView.string = outputTextView.string
        outputTextView.string = input
        setStatus("Swapped message and ciphertext.")
    }

    @objc func clearTexts() {
        inputTextView.string = ""
        outputTextView.string = ""
        sourceName = "message"
        lastOutputWasDecipher = false
        refreshOutputChrome()
        view.window?.makeFirstResponder(inputTextView)
        setStatus("Cleared message and output. Machine settings unchanged.")
    }

    @objc func copyOutput() {
        let text = outputTextView.string
        guard !text.isEmpty else {
            setStatus("Nothing to copy.", isError: true)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        setStatus(lastOutputWasDecipher ? "Copied deciphered text." : "Copied ciphertext.")
    }

    @objc func saveCiphertext() {
        let text = outputTextView.string
        guard !text.isEmpty else {
            setStatus("Encipher or decipher a message first.", isError: true)
            return
        }
        let filename = EnigmaOutputName.saveFilename(base: sourceName, deciphered: lastOutputWasDecipher)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        panel.title = lastOutputWasDecipher ? "Save Deciphered Text" : "Save Ciphertext"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                if self?.lastOutputWasDecipher == true {
                    self?.setStatus("Wrote \(url.lastPathComponent).")
                } else {
                    self?.setStatus("Wrote \(url.lastPathComponent). Export settings or a codebook to decipher it later.")
                }
            } catch {
                self?.setStatus(error.localizedDescription, isError: true)
            }
        }
    }

    @objc func exportSettings() {
        do {
            let config = try currentConfigurationFromUI()
            presentSave(filename: "\(sourceName)-settings.txt", contents: EnigmaSettings.exportSettings(config), kind: "settings")
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    @objc func exportCodebook() {
        do {
            let config = try currentConfigurationFromUI()
            presentSave(filename: "\(sourceName)-codebook.txt", contents: EnigmaSettings.exportCodebook(config), kind: "codebook")
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    @objc func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import Settings or Codebook"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadDroppedFile(url)
        }
    }

    private func presentSave(filename: String, contents: String, kind: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try contents.write(to: url, atomically: true, encoding: .utf8)
                self?.setStatus("Wrote \(kind) to \(url.lastPathComponent).")
            } catch {
                self?.setStatus(error.localizedDescription, isError: true)
            }
        }
    }

    // MARK: Files

    func openFiles(_ urls: [URL]) {
        guard let url = urls.first else { return }
        loadDroppedFile(url)
    }

    @objc func chooseInputFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .utf8PlainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Text File"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadDroppedFile(url)
        }
    }

    private func loadDroppedFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            if EnigmaSettings.looksLikeSettings(text) {
                let config = try EnigmaSettings.parse(text)
                configuration = try config.validated()
                refreshMachineFields()
                setStatus("Loaded machine settings from \(url.lastPathComponent).")
            } else {
                inputTextView.string = text
                sourceName = EnigmaOutputName.messageBase(
                    from: url.deletingPathExtension().lastPathComponent
                )
                setStatus("Loaded \(url.lastPathComponent) (\(EnigmaText.letters(from: text).count) letters).")
            }
        } catch {
            setStatus(error.localizedDescription, isError: true)
        }
    }

    // MARK: Machine actions

    @objc func showDescription() {
        DescriptionWindowController.shared.show()
    }

    @objc private func modeChanged() {
        let mode: EnigmaMode = modeControl.selectedSegment == 0 ? .m3 : .m4
        configuration = .default(mode: mode)
        refreshMachineFields()
        setStatus("Switched to \(mode.rawValue.uppercased()) mode.")
    }

    @objc private func reflectorChanged() {
        configuration.reflector = reflectorValueFromPopup()
    }

    @objc private func applyWikiTestVector() {
        configuration = .wikiTestVector
        refreshMachineFields()
        inputTextView.string = "AAAAA"
        outputTextView.string = ""
        setStatus("Loaded wiki test vector (I-II-III, AAA, UKW-B, no XOR). Encipher should yield BDZGO.")
    }

    @objc private func randomizePositions() {
        let count = modeControl.selectedSegment == 0 ? 3 : 4
        let letters = (0..<count).map { _ in Character(UnicodeScalar(65 + UInt8(Int.random(in: 0..<26)))) }
        positionsField.stringValue = String(letters)
        setStatus("Randomized starting positions.")
    }

    @objc private func randomizeMachine() {
        let mode: EnigmaMode = modeControl.selectedSegment == 0 ? .m3 : .m4
        let moving = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"].shuffled()
        var rotors: [String]
        var reflector: String
        if mode == .m4 {
            rotors = [Bool.random() ? "Beta" : "Gamma"] + Array(moving.prefix(3))
            reflector = Bool.random() ? "B-Thin" : "C-Thin"
        } else {
            rotors = Array(moving.prefix(3))
            reflector = Bool.random() ? "B" : "C"
        }
        func randomLetters(_ n: Int) -> String {
            String((0..<n).map { _ in Character(UnicodeScalar(65 + UInt8(Int.random(in: 0..<26)))) })
        }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").shuffled()
        var plugs: [String] = []
        for i in stride(from: 0, to: 20, by: 2) {
            plugs.append(String([alphabet[i], alphabet[i + 1]]))
        }
        configuration = EnigmaConfiguration(
            mode: mode,
            rotorNames: rotors,
            reflector: reflector,
            rings: randomLetters(rotors.count),
            positions: randomLetters(rotors.count),
            plugPairs: plugs,
            xorKey: randomLetters(8)
        )
        refreshMachineFields()
        setStatus("Randomized full machine (rotors, rings, positions, 10 stecker, XOR key).")
    }
}
