import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var pendingOpenFiles: [String] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        collectCommandLineFiles()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.showWindow(nil)
            mainWindowController?.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        mainWindowController = MainWindowController()
        wireMenuTargets()
        guard let window = mainWindowController?.window else {
            fputs("Enigma XOR: failed to create main window\n", stderr)
            return
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        if !pendingOpenFiles.isEmpty {
            let files = pendingOpenFiles
            pendingOpenFiles.removeAll()
            processOpenFiles(files)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if mainWindowController?.mainViewController != nil {
            processOpenFiles(filenames)
        } else {
            pendingOpenFiles.append(contentsOf: filenames)
        }
    }

    private func collectCommandLineFiles() {
        let paths = CommandLine.arguments.dropFirst()
            .map { ($0 as NSString).expandingTildeInPath }
            .filter { FileManager.default.isReadableFile(atPath: $0) }
        guard !paths.isEmpty else { return }
        pendingOpenFiles.append(contentsOf: paths)
    }

    private func processOpenFiles(_ filenames: [String]) {
        guard let mainView = mainWindowController?.mainViewController else { return }
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainView.openFiles(filenames.map { URL(fileURLWithPath: $0) })
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        appMenuItem.title = "Enigma XOR"
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Enigma XOR")
        appMenu.addItem(menuItem(title: "About Enigma XOR", action: #selector(showAbout)))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem(title: "How the Enigma Machine Works", action: #selector(showDescription)))
        appMenu.addItem(menuItem(title: "Encoding and Decoding Steps", action: #selector(showEncodeHelp)))
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit Enigma XOR",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem()
        fileMenuItem.title = "File"
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(menuItem(title: "Open Text File…", action: #selector(MainViewController.chooseInputFile), key: "o"))
        fileMenu.addItem(menuItem(title: "Encipher", action: #selector(MainViewController.encipher), key: "e"))
        fileMenu.addItem(menuItem(title: "Decipher", action: #selector(MainViewController.decipher), key: "d"))
        fileMenu.addItem(menuItem(title: "Save Ciphertext…", action: #selector(MainViewController.saveCiphertext), key: "s"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem(title: "Export Settings…", action: #selector(MainViewController.exportSettings)))
        fileMenu.addItem(menuItem(title: "Export Codebook…", action: #selector(MainViewController.exportCodebook)))
        fileMenu.addItem(menuItem(title: "Import Settings…", action: #selector(MainViewController.importSettings)))
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu

        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Edit"
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        let copyOut = editMenu.addItem(withTitle: "Copy Output", action: #selector(MainViewController.copyOutput), keyEquivalent: "c")
        copyOut.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(menuItem(title: "Clear", action: #selector(MainViewController.clearTexts), key: "k"))
        editMenuItem.submenu = editMenu

        let helpMenuItem = NSMenuItem()
        helpMenuItem.title = "Help"
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(menuItem(title: "Encoding and Decoding Steps", action: #selector(showEncodeHelp)))
        helpMenu.addItem(menuItem(title: "How the Enigma Machine Works", action: #selector(showDescription)))
        helpMenuItem.submenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    private func wireMenuTargets() {
        guard let mainView = mainWindowController?.mainViewController else { return }
        let actions: [Selector] = [
            #selector(MainViewController.chooseInputFile),
            #selector(MainViewController.encipher),
            #selector(MainViewController.decipher),
            #selector(MainViewController.saveCiphertext),
            #selector(MainViewController.exportSettings),
            #selector(MainViewController.exportCodebook),
            #selector(MainViewController.importSettings),
            #selector(MainViewController.copyOutput),
            #selector(MainViewController.clearTexts)
        ]
        for menu in NSApp.mainMenu?.items.compactMap(\.submenu) ?? [] {
            for item in menu.items {
                guard let action = item.action, actions.contains(action) else { continue }
                item.target = mainView
            }
        }
    }

    private func menuItem(title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if action == #selector(showAbout)
            || action == #selector(showDescription)
            || action == #selector(showEncodeHelp) {
            item.target = self
        }
        return item
    }

    @objc func showDescription() {
        DescriptionWindowController.shared.show()
    }

    @objc func showEncodeHelp() {
        HelpWindowController.shared.show()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Enigma XOR"
        alert.informativeText = """
        A historical M3 / M4 Naval Enigma, plus one XOR-Schlüssel.

        The rotors, reflector, plugboard, and double-step are the wartime machine. After the lamp, each letter index (A = 0) is XORed with the next Schlüssel letter. Values 26–31 are written as digits 2–7. An empty XOR key is historical Enigma: AAAAA → BDZGO.

        Encipher is rotors then XOR. Decipher is XOR then rotors. They are the same pass only when the XOR key is empty. On encipher, digits in the message become English words (optional). Digits 2–7 in ciphertext are symbols, not numbers.

        Version \(AppInfo.version) (build \(AppInfo.build))

        Educational use only. This is not a modern cipher.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
