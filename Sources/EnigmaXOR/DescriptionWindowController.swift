import AppKit

final class DescriptionWindowController: NSWindowController {
    static let shared = DescriptionWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "How the Enigma Machine Works"
        window.center()
        window.backgroundColor = Theme.background
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentViewController = DescriptionViewController()
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

final class DescriptionViewController: NSViewController {
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
        scrollView.frame = NSRect(x: 0, y: 0, width: 720, height: 640)

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

        let body = NSMutableParagraphStyle()
        body.lineSpacing = 3
        body.paragraphSpacing = 6

        textView.textStorage?.setAttributedString(NSAttributedString(
            string: Self.descriptionText,
            attributes: [
                .font: Theme.body,
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

    private static let descriptionText = """
    ENIGMA XOR — M3 / M4, THEN XOR
    ==============================

    Version \(AppInfo.version) (build \(AppInfo.build))

    The rotors, reflector, plugboard, ring settings, and pawl-and-ratchet stepping are a historical M3 (three rotors) or M4 Naval (four rotors). The military entry wheel is the identity alphabet, so it is not drawn as its own wheel.

    The one thing a 1942 machine did not do is the XOR-Schlüssel. After the lamp lights, that letter’s index (A = 0) is XORed with the next letter of the Schlüssel. Results 0–25 stay A–Z. Results 26–31 are written as the digits 2–7. An empty Schlüssel, or a Schlüssel of only A’s, is historical Enigma.

    It is not a file-archive tool. There is no custom container. You type, paste, or drop a text file; the machine emits a plain text ciphertext file in five-symbol groups. Machine settings live in a separate settings sheet or codebook so the message can be read later.

    With no XOR key, Encipher and Decipher are the same rotor pass. With a key, Decipher XORs first. For the exact pipeline, see Help → Encoding and Decoding Steps.


    THE MACHINE
    -----------

    Signal path (every letter):

      keyboard → plugboard → rotors right-to-left → reflector
              → rotors left-to-right → plugboard → lamp
              → XOR with the next XOR-Schlüssel letter

    Rotors step before the letter is enciphered. The right-hand (fast) rotor steps every keypress. When it sits on a turnover notch it also steps the middle rotor. If the middle rotor is itself on a notch, it double-steps — a real mechanical quirk of the pawl-and-ratchet drive.

    M3 uses three moving rotors chosen from I–VIII and a wide reflector UKW-B or UKW-C.

    M4 adds a static Greek rotor (Beta or Gamma) on the left and a thin reflector (UKW-B Thin or UKW-C Thin). The Greek rotor does not step during a message. With Beta at A and UKW-B Thin, M4 is electrically identical to M3 with UKW-B — that was how the Navy stayed compatible with three-rotor traffic.

    The plugboard (Steckerbrett) swaps up to ten letter pairs, both on the way in and on the way out.

    Because of the reflector, no lamp letter ever matches the key that was pressed. The XOR can undo that: a ciphertext symbol may equal the plaintext letter. With a Schlüssel set, encipherment is not its own inverse. Decipher strips the XOR, then runs the same rotors.


    HOW TO USE IT
    -------------

    1. Choose M3 or M4. Set Walzenlage (rotor order), UKW, Ringstellung, Grundstellung, Steckerbrett, and the XOR key. Leave the XOR key empty for a historical machine.
    2. Type, paste, or drop a text file. On encipher, digits become English words (42 → FORTY TWO, 3.14 → THREE POINT ONE FOUR, 007 → ZERO ZERO SEVEN, 12:30 → TWELVE THIRTY). Clock times before HOURS are hour + hundred: 1800 HOURS → EIGHTEEN HUNDRED HOURS, 1850 HOURS → EIGHTEEN HUNDRED AND FIFTY HOURS (1800 alone is still ONE THOUSAND EIGHT HUNDRED). Invalid clocks are not rejected (1260 HOURS → TWELVE HUNDRED AND SIXTY HOURS; 2400 HOURS → TWENTY FOUR HUNDRED HOURS). A leading minus is MINUS (`-4`); a dash in a date or phone number is not (`2026-09-14`, `555-1234`). Uncheck “Spell numbers in English” to drop digits instead. Decipher never spells numbers. Ä/Ö/Ü become AE/OE/UE; ß becomes SS. Other non-letters are ignored.
    3. Encipher. Save the ciphertext as an ordinary .txt file.
    4. Export Settings (a labeled key sheet) or a Codebook (Schlüsseltafel) so the recipient can restore the machine.
    5. To decipher: import that sheet, paste the ciphertext, turn Group in fives **off**, then Decipher. If grouping stays on, the recovered letters are wrapped into fives again. Reset Grundstellung first — the app does that on every run.
    6. Clear (⌘K) empties the message and output only. The machine is left as set.


    WIKI TEST VECTOR
    ----------------

    Rotors I-II-III, rings AAA, windows AAA, UKW-B, no stecker, no XOR:

      AAAAA      →  BDZGO
      HELLOWORLD →  ILBDAAMTAZ

    The same machine with XOR key Z:

      AAAAA      →  Y2A7X

    Launch also checks the 1942 U-264 message (Beta II IV I, UKW-B Thin, rings AAAV, windows VJNA) and the Scharnhorst M3 intercept. Those are historical Enigma, with the XOR key empty.


    WHAT THIS IS NOT
    ----------------

    Enigma was broken at Bletchley Park. The lamp’s refusal to repeat a letter, stereotyped openings, and captured codebooks made it tractable. The XOR hides the no-self-encryption property and is still not a modern cipher: the Schlüssel is written on the key sheet in the clear. Do not protect real secrets with it. For that, use FileVault, age, or GPG.

    Ciphertext files are ordinary text, including the digits 2–7 when the XOR overflows. Anyone with the settings or codebook can read them.
    """
}
