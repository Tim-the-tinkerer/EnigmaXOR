import AppKit

enum Theme {
    static let background = NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.12, alpha: 1.0)
    static let panel = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)
    static let accent = NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.22, alpha: 1.0)
    static let text = NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.86, alpha: 1.0)
    static let muted = NSColor(calibratedRed: 0.55, green: 0.53, blue: 0.50, alpha: 1.0)
    static let border = NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.22, alpha: 1.0)
    static let field = NSColor(calibratedWhite: 0.12, alpha: 1.0)

    static let monospaced = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    static let monospacedLarge = NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold)
    static let title = NSFont.systemFont(ofSize: 22, weight: .bold)
    static let body = NSFont.systemFont(ofSize: 13, weight: .regular)
}

extension NSView {
    func applyPanelStyle() {
        wantsLayer = true
        layer?.backgroundColor = Theme.panel.cgColor
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        layer?.borderColor = Theme.border.cgColor
    }
}

extension NSTextField {
    static func makeLabel(_ text: String, muted: Bool = false) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.textColor = muted ? Theme.muted : Theme.text
        field.font = Theme.body
        return field
    }

    static func makeInput(placeholder: String = "") -> NSTextField {
        let field = NSTextField(string: "")
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = Theme.monospaced
        field.textColor = Theme.text
        field.backgroundColor = Theme.field
        field.focusRingType = .none
        return field
    }
}

extension NSButton {
    static func makePrimary(_ title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = Theme.body
        button.contentTintColor = Theme.accent
        return button
    }

    static func makeSecondary(_ title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = Theme.body
        return button
    }
}
