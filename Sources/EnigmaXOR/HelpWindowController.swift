import AppKit

enum HelpDocument {
    static func encodingSteps() -> String {
        if let url = locateHELP(),
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.isEmpty {
            return text
        }
        return "HELP.md was not found. It should sit next to the app sources, and is copied into EnigmaXOR.app/Contents/Resources/ on build."
    }

    static func locateHELP() -> URL? {
        if let bundled = Bundle.main.url(forResource: "HELP", withExtension: "md") {
            return bundled
        }
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidate = root.appendingPathComponent("HELP.md")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }
}

final class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 680),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Encoding and Decoding Steps"
        window.center()
        window.backgroundColor = Theme.background
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 520, height: 400)

        super.init(window: window)
        window.contentViewController = HelpViewController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class HelpViewController: NSViewController {
    private var textView: NSTextView?

    override func loadView() {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.background
        scrollView.appearance = NSAppearance(named: .darkAqua)
        scrollView.frame = NSRect(x: 0, y: 0, width: 740, height: 680)

        guard let textView = scrollView.documentView as? NSTextView else {
            view = scrollView
            return
        }
        self.textView = textView

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = Theme.background
        textView.insertionPointColor = Theme.accent
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 8
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let body = NSMutableParagraphStyle()
        body.lineSpacing = 2
        body.paragraphSpacing = 4

        textView.textStorage?.setAttributedString(NSAttributedString(
            string: HelpDocument.encodingSteps(),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: Theme.text,
                .paragraphStyle: body
            ]
        ))

        view = scrollView
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let textView else { return }
        let width = max(textView.bounds.width, 1)
        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
    }
}
