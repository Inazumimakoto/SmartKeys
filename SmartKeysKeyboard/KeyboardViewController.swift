import UIKit

private enum FlickDirection: CaseIterable {
    case center, up, down, left, right
}

private final class FlickPopupView: UIView {
    private var labels: [FlickDirection: UILabel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)

        func makeLabel() -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 16, weight: .semibold)
            label.textAlignment = .center
            label.textColor = .label
            label.backgroundColor = .clear
            label.widthAnchor.constraint(equalToConstant: 32).isActive = true
            label.heightAnchor.constraint(equalToConstant: 28).isActive = true
            return label
        }

        let upLabel = makeLabel()
        let downLabel = makeLabel()
        let leftLabel = makeLabel()
        let rightLabel = makeLabel()
        let centerLabel = makeLabel()

        labels[.up] = upLabel
        labels[.down] = downLabel
        labels[.left] = leftLabel
        labels[.right] = rightLabel
        labels[.center] = centerLabel

        let middle = UIStackView(arrangedSubviews: [leftLabel, centerLabel, rightLabel])
        middle.axis = .horizontal
        middle.alignment = .center
        middle.distribution = .equalCentering
        middle.spacing = 6

        let container = UIStackView(arrangedSubviews: [upLabel, middle, downLabel])
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 4
        container.translatesAutoresizingMaskIntoConstraints = false

        addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTexts(base: String, outputs: [FlickDirection: String]) {
        labels[.center]?.text = base
        for direction in FlickDirection.allCases where direction != .center {
            if let text = outputs[direction] {
                labels[direction]?.text = text
                labels[direction]?.isHidden = false
            } else {
                labels[direction]?.text = nil
                labels[direction]?.isHidden = true
            }
        }
        updateSelection(.center)
    }

    func updateSelection(_ direction: FlickDirection) {
        for (dir, label) in labels {
            if dir == direction {
                label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
                label.layer.cornerRadius = 6
                label.layer.masksToBounds = true
            } else {
                label.backgroundColor = .clear
                label.layer.cornerRadius = 0
                label.layer.masksToBounds = false
            }
        }
    }
}

private final class FlickKeyButton: UIButton {
    var baseKey: String = ""
    var flickOutputs: [FlickDirection: String] = [:] {
        didSet { updateFlickGuideTexts() }
    }
    var commitHandler: ((FlickDirection, String) -> Void)?
    var centerTapHandler: (() -> Void)?

    private var popupView: FlickPopupView?
    private var startPoint: CGPoint = .zero
    private var currentDirection: FlickDirection = .center
    private var flickGuideLabels: [FlickDirection: UILabel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        adjustsImageWhenHighlighted = false
        setupFlickGuides()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        adjustsImageWhenHighlighted = false
        setupFlickGuides()
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        startPoint = touch.location(in: self)
        if !flickOutputs.isEmpty {
            showPopup()
        }
        currentDirection = .center
        return super.beginTracking(touch, with: event)
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard !flickOutputs.isEmpty else { return super.continueTracking(touch, with: event) }
        let point = touch.location(in: self)
        let dx = point.x - startPoint.x
        let dy = point.y - startPoint.y
        let threshold: CGFloat = 18
        var newDirection: FlickDirection = .center
        if abs(dx) > threshold || abs(dy) > threshold {
            if abs(dx) > abs(dy) {
                newDirection = dx > 0 ? .right : .left
            } else {
                newDirection = dy < 0 ? .up : .down
            }
        }
        if flickOutputs[newDirection] == nil { newDirection = .center }
        if newDirection != currentDirection {
            currentDirection = newDirection
            popupView?.updateSelection(newDirection)
        }
        return super.continueTracking(touch, with: event)
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        defer {
            hidePopup()
            currentDirection = .center
        }

        if currentDirection == .center {
            if isEnabled && didEndInside(touch) {
                centerTapHandler?()
            }
            super.endTracking(touch, with: event)
            return
        }

        if let output = flickOutputs[currentDirection] {
            commitHandler?(currentDirection, output)
            super.cancelTracking(with: event)
        } else {
            super.endTracking(touch, with: event)
        }
    }

    override func cancelTracking(with event: UIEvent?) {
        hidePopup()
        currentDirection = .center
        super.cancelTracking(with: event)
    }

    private func didEndInside(_ touch: UITouch?) -> Bool {
        guard let touch else { return isTouchInside }
        let location = touch.location(in: self)
        return bounds.contains(location)
    }

    private func showPopup() {
        if popupView == nil {
            let popup = FlickPopupView()
            addSubview(popup)
            NSLayoutConstraint.activate([
                popup.centerXAnchor.constraint(equalTo: centerXAnchor),
                popup.centerYAnchor.constraint(equalTo: centerYAnchor),
                popup.widthAnchor.constraint(equalToConstant: 96),
                popup.heightAnchor.constraint(equalToConstant: 96)
            ])
            popup.alpha = 0
            popup.isHidden = true
            popupView = popup
        }
        let base = title(for: .normal) ?? baseKey
        popupView?.updateTexts(base: base, outputs: flickOutputs)
        popupView?.alpha = 1.0
        popupView?.isHidden = false
        layer.zPosition = 100
    }

    private func hidePopup() {
        popupView?.alpha = 0
        popupView?.isHidden = true
        layer.zPosition = 0
    }

    private func setupFlickGuides() {
        clipsToBounds = false
        let font = UIFont.systemFont(ofSize: 10, weight: .regular)
        let color = UIColor.secondaryLabel

        func makeGuideLabel() -> UILabel {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = font
            label.textColor = color
            label.textAlignment = .center
            label.isHidden = true
            addSubview(label)
            return label
        }

        let up = makeGuideLabel()
        NSLayoutConstraint.activate([
            up.centerXAnchor.constraint(equalTo: centerXAnchor),
            up.topAnchor.constraint(equalTo: topAnchor, constant: 4)
        ])
        flickGuideLabels[.up] = up

        let down = makeGuideLabel()
        NSLayoutConstraint.activate([
            down.centerXAnchor.constraint(equalTo: centerXAnchor),
            down.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
        flickGuideLabels[.down] = down

        let left = makeGuideLabel()
        NSLayoutConstraint.activate([
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)
        ])
        flickGuideLabels[.left] = left

        let right = makeGuideLabel()
        NSLayoutConstraint.activate([
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
        flickGuideLabels[.right] = right

        updateFlickGuideTexts()
    }

    private func updateFlickGuideTexts() {
        for (direction, label) in flickGuideLabels {
            if let text = flickOutputs[direction], !text.isEmpty {
                label.text = text
                label.isHidden = false
            } else {
                label.text = nil
                label.isHidden = true
            }
        }
    }
}

final class KeyboardViewController: UIInputViewController {
    private let toolbar = UIStackView()
    private let main = UIStackView()
    private var isShifted = false

    // IME
    private let ime = InputEngine()

    private let flickAssignments: [String: [FlickDirection: String]] = [
        // 1段目 上=数字 下=記号
        "q": [.up: "1", .down: "!"],
        "w": [.up: "2", .down: "@"],
        "e": [.up: "3", .down: "#"],
        "r": [.up: "4", .down: "$"],
        "t": [.up: "5", .down: "%"],
        "y": [.up: "6", .down: "^"],
        "u": [.up: "7", .down: "&"],
        "i": [.up: "8", .down: "*"],
        "o": [.up: "9", .down: "("],
        "p": [.up: "0", .down: ")"],

        // 2段目
        "a": [.up: "-", .down: "'"],
        "s": [.up: "_", .down: "\""],
        "d": [.up: "=", .down: ":"],
        "f": [.up: "+", .down: ";"],
        "g": [.up: "[", .down: "/"],
        "h": [.up: "]", .down: "\\"],
        "j": [.up: "{", .down: "<"],
        "k": [.up: "}", .down: ">"],
        "l": [.up: "\"", .down: "?"],
        "ー": [.up: "|", .down: "〜"],

        // 3段目
        "z": [.up: "~", .down: "|"],
        "x": [.up: "`", .down: "\\"],
        "c": [.up: "^", .down: "/"],
        "v": [.up: "&", .down: "?"],
        "b": [.up: "*", .down: "!"],
        "n": [.up: "%", .down: "#"],
        "m": [.up: "$", .down: "@"]
    ]

    // オートリピート
    private var repeatTimer: Timer?
    private var repeatCount: Int = 0
    private var repeatingId: String?
    private let repeatableIds: Set<String> = ["left", "right", "plus1", "minus1", "delete"]

    override func viewDidLoad() {
        super.viewDidLoad()
        inputView?.backgroundColor = .systemBackground

        // ===== ツールバー =====
        toolbar.axis = .horizontal
        toolbar.distribution = .fillEqually
        toolbar.spacing = 6
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        func wireToolbarTargets(button b: UIButton, id: String) {
            if repeatableIds.contains(id) {
                b.addTarget(self, action: #selector(repeatPressDown(_:)), for: .touchDown)
                b.addTarget(self, action: #selector(repeatPressEnd(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            } else {
                b.addTarget(self, action: #selector(toolbarTapped(_:)), for: .touchUpInside)
            }
        }
        func makeSymbolButton(_ systemName: String, id: String) -> UIButton {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: systemName), for: .normal)
            b.tintColor = .label
            b.backgroundColor = .tertiarySystemBackground
            b.layer.cornerRadius = 6
            b.heightAnchor.constraint(equalToConstant: 36).isActive = true
            b.accessibilityIdentifier = id
            wireToolbarTargets(button: b, id: id)
            return b
        }
        func makeTextButton(_ title: String, id: String) -> UIButton {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            b.backgroundColor = .tertiarySystemBackground
            b.layer.cornerRadius = 6
            b.heightAnchor.constraint(equalToConstant: 36).isActive = true
            b.accessibilityIdentifier = id
            wireToolbarTargets(button: b, id: id)
            return b
        }

        // ← → 行頭 行末 +1 -1（※記号はキー面に移動）
        [
            makeSymbolButton("arrow.left", id: "left"),
            makeSymbolButton("arrow.right", id: "right"),
            makeSymbolButton("arrow.left.to.line", id: "home"),
            makeSymbolButton("arrow.right.to.line", id: "end"),
            makeTextButton("+1", id: "plus1"),
            makeTextButton("-1", id: "minus1")
        ].forEach { toolbar.addArrangedSubview($0) }

        // ===== 本体キーボード =====
        main.axis = .vertical
        main.distribution = .fillEqually
        main.spacing = 6
        main.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbar)
        view.addSubview(main)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            toolbar.heightAnchor.constraint(equalToConstant: 40),

            main.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 6),
            main.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            main.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            main.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])

        buildQwerty()
    }

    // MARK: - QWERTY
    private enum Key { case char(String), shift, delete, space, `return`, globe }

    private func buildQwerty() {
        main.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1段目
        let r1 = "qwertyuiop".map{ Key.char(String($0)) }
        // 2段目（Lの右に「ー」を追加）
        var r2 = [Key.char("a"),.char("s"),.char("d"),.char("f"),.char("g"),.char("h"),.char("j"),.char("k"),.char("l")]
        r2.append(.char("ー"))
        // 3段目
        let r3: [Key] = [.shift] + "zxcvbnm".map{ .char(String($0)) } + [.delete]
        // 4段目（スペース左に「、」、右に「。」）
        let r4: [Key] = [.globe, .char("、"), .space, .char("。"), .return]

        [r1,r2,r3,r4].forEach { main.addArrangedSubview(makeRow($0)) }
    }

    private func makeRow(_ keys:[Key]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 6
        keys.forEach { key in
            let button = createButton(for: key)
            row.addArrangedSubview(button)
        }
        return row
    }

    private func createButton(for key: Key) -> UIButton {
        switch key {
        case .char(let s):
            let button = FlickKeyButton()
            button.baseKey = s
            configureKeyAppearance(button)
            button.tag = tag(for: key)
            button.setTitle(title(for: key), for: .normal)
            let lookupKey = s.lowercased()
            if let outputs = flickAssignments[lookupKey] ?? flickAssignments[s] {
                button.flickOutputs = outputs
            }
            button.commitHandler = { [weak self] _, output in
                self?.handleFlickSelection(output: output)
            }
            button.centerTapHandler = { [weak self, weak button] in
                guard let button = button else { return }
                self?.keyTapped(button)
            }
            return button
        case .delete:
            let button = UIButton(type: .system)
            configureKeyAppearance(button)
            button.setTitle(title(for: key), for: .normal)
            button.tag = tag(for: key)
            button.accessibilityIdentifier = "delete"
            button.addTarget(self, action: #selector(repeatPressDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(repeatPressEnd(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            return button
        default:
            let button = UIButton(type: .system)
            configureKeyAppearance(button)
            button.setTitle(title(for: key), for: .normal)
            button.tag = tag(for: key)
            button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            return button
        }
    }

    private func configureKeyAppearance(_ button: UIButton) {
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 6
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.setTitleColor(.label, for: .normal)
    }

    private func handleFlickSelection(output: String) {
        ime.commitPendingIfNeeded(proxy: textDocumentProxy, endOfWordTrigger: true)
        textDocumentProxy.insertText(output)
        if isShifted {
            isShifted = false
            refreshTitles()
        }
    }

    private func title(for key:Key)->String {
        switch key {
        case .char(let s): return s.count == 1 ? (isShifted ? s.uppercased() : s.lowercased()) : s
        case .shift: return isShifted ? "⇧" : "⇪"
        case .delete: return "⌫"
        case .space: return "space"
        case .return: return "return"
        case .globe: return "🌐"
        }
    }
    private func tag(for key:Key)->Int {
        switch key {
        case .char(let s): return 1000 + (s.unicodeScalars.first?.value ?? 0).hashValue
        case .shift: return 1; case .delete: return 2; case .space: return 3
        case .return: return 4; case .globe: return 5
        }
    }

    @objc private func keyTapped(_ sender:UIButton){
        switch sender.tag {
        case 1: isShifted.toggle(); refreshTitles()
        case 2:
            if !ime.handleDelete(proxy: textDocumentProxy) {
                textDocumentProxy.deleteBackward()
            }
        case 3:
            ime.commitPendingIfNeeded(proxy: textDocumentProxy, endOfWordTrigger: true)
            textDocumentProxy.insertText(" ")
        case 4:
            ime.commitPendingIfNeeded(proxy: textDocumentProxy, endOfWordTrigger: true)
            textDocumentProxy.insertText("\n")
        case 5: advanceToNextInputMode()
        default:
            guard let t0 = sender.title(for: .normal) else { return }
            // アルファベットは shift 反映、それ以外（ー、、、。）はそのまま
            let out: Character
            if t0.count == 1, let ch = t0.first {
                let display = isShifted ? Character(t0.uppercased()) : ch
                out = display
            } else {
                out = Character(t0)
            }
            ime.feed(letter: out, proxy: textDocumentProxy)
            if isShifted { isShifted = false; refreshTitles() }
        }
    }

    private func refreshTitles(){
        for case let row as UIStackView in main.arrangedSubviews {
            for case let b as UIButton in row.arrangedSubviews {
                switch b.tag {
                case 1: b.setTitle(title(for:.shift), for:.normal)
                case 2: b.setTitle(title(for:.delete), for:.normal)
                case 3: b.setTitle(title(for:.space), for:.normal)
                case 4: b.setTitle(title(for:.return), for:.normal)
                case 5: b.setTitle(title(for:.globe), for:.normal)
                default:
                    if let t=b.title(for:.normal) {
                        if t.count == 1, ("a"..."z").contains(Character(t.lowercased())) {
                            b.setTitle(isShifted ? t.uppercased() : t.lowercased(), for:.normal)
                        } // 記号はそのまま
                    }
                }
            }
        }
    }

    // MARK: - Toolbar actions / repeat
    @objc private func toolbarTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        performToolbarAction(id)
    }

    private func performToolbarAction(_ id: String) {
        switch id {
        case "left":  textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
        case "right": textDocumentProxy.adjustTextPosition(byCharacterOffset: +1)
        case "home":  moveLineHome()
        case "end":   moveLineEnd()
        case "plus1": smartIncrement()
        case "minus1": smartDecrement()
        case "delete":
            if !ime.handleDelete(proxy: textDocumentProxy) {
                textDocumentProxy.deleteBackward()
            }
        default: break
        }
    }

    // オートリピート
    @objc private func repeatPressDown(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier, repeatableIds.contains(id) else { return }
        stopRepeating()
        repeatingId = id
        repeatCount = 0
        performToolbarAction(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, self.repeatingId == id else { return }
            self.scheduleNextRepeat()
        }
    }
    @objc private func repeatPressEnd(_ sender: UIButton) { stopRepeating() }
    private func stopRepeating() {
        repeatTimer?.invalidate(); repeatTimer = nil
        repeatingId = nil; repeatCount = 0
    }
    private func scheduleNextRepeat() {
        guard let id = repeatingId else { return }
        let interval = currentRepeatInterval(for: repeatCount)
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self, let id = self.repeatingId else { return }
            self.performToolbarAction(id)
            self.repeatCount += 1
            self.scheduleNextRepeat()
        }
        RunLoop.current.add(repeatTimer!, forMode: .common)
    }
    private func currentRepeatInterval(for count: Int) -> TimeInterval {
        switch count { case ..<10: return 0.12; case ..<25: return 0.07; default: return 0.03 }
    }

    // ===== 行頭 / 行末 =====
    private func moveLineHome() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let left = before.lastIndex(of: "\n").map { before.distance(from: $0, to: before.endIndex) - 1 } ?? before.count
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -left)
    }
    private func moveLineEnd() {
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let right = after.firstIndex(of: "\n").map { after.distance(from: after.startIndex, to: $0) } ?? after.count
        textDocumentProxy.adjustTextPosition(byCharacterOffset: right)
    }

    // ===== スマート増減/曜日/時刻 =====
    private func smartIncrement() {
        if adjustTimeToken(deltaMinutes: +1) { return }
        if rotateWeekday(direction: +1) { return }
        if incrementNumberToken() { return }
    }
    private func smartDecrement() {
        if adjustTimeToken(deltaMinutes: -1) { return }
        if rotateWeekday(direction: -1) { return }
        if decrementNumberToken() { return }
    }

    @discardableResult
    private func incrementNumberToken() -> Bool {
        guard let info = numberTokenAroundCaret() else { return false }
        let (token, rightDigitsCount) = info
        let hasLeadingZero = token.count > 1 && token.first == "0"
        let n = Int(token) ?? 0
        let newVal = n + 1
        let newToken = hasLeadingZero ? String(format: "%0\(token.count)d", newVal) : String(newVal)
        replaceToken(tokenLength: token.count, moveRight: rightDigitsCount, with: newToken)
        return true
    }
    @discardableResult
    private func decrementNumberToken() -> Bool {
        guard let info = numberTokenAroundCaret() else { return false }
        let (token, rightDigitsCount) = info
        let hasLeadingZero = token.count > 1 && token.first == "0"
        let n = Int(token) ?? 0
        let newVal = max(0, n - 1)
        let newToken = hasLeadingZero ? String(format: "%0\(token.count)d", newVal) : String(newVal)
        replaceToken(tokenLength: token.count, moveRight: rightDigitsCount, with: newToken)
        return true
    }
    private func numberTokenAroundCaret() -> (token: String, rightDigitsCount: Int)? {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after  = textDocumentProxy.documentContextAfterInput  ?? ""
        let L = String(before.suffix(64))
        let R = String(after.prefix(64))
        let leftDigits  = L.reversed().prefix { $0.isNumber }.reversed()
        let rightDigits = R.prefix { $0.isNumber }
        let token = String(leftDigits + rightDigits)
        guard !token.isEmpty else { return nil }
        return (token, rightDigits.count)
    }
    private func replaceToken(tokenLength: Int, moveRight: Int, with newText: String) {
        if moveRight != 0 { textDocumentProxy.adjustTextPosition(byCharacterOffset: moveRight) }
        for _ in 0..<tokenLength { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(newText)
    }

    @discardableResult
    private func adjustTimeToken(deltaMinutes: Int) -> Bool {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after  = textDocumentProxy.documentContextAfterInput  ?? ""
        let leftPart  = String(before.suffix(32))
        let rightPart = String(after.prefix(32))
        let s = leftPart + rightPart
        let pattern = #"([0-9]+):([0-5]\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let matches = regex.matches(in: s, range: NSRange(location: 0, length: s.utf16.count))
        guard !matches.isEmpty else { return false }
        let caret = leftPart.count
        var chosen: NSTextCheckingResult?
        for m in matches {
            let start = m.range(at: 0).location
            let end   = start + m.range(at: 0).length
            if start <= caret && caret <= end { chosen = m; break }
        }
        guard let chosen = chosen,
              let fr = Range(chosen.range(at: 0), in: s),
              let hr = Range(chosen.range(at: 1), in: s),
              let mr = Range(chosen.range(at: 2), in: s) else { return false }

        let tokenStart = s.distance(from: s.startIndex, to: fr.lowerBound)
        let tokenEnd   = s.distance(from: s.startIndex, to: fr.upperBound)
        let hourEndPos = s.distance(from: s.startIndex, to: hr.upperBound)
        let caretInHour = caret <= hourEndPos

        let hh = Int(String(s[hr])) ?? 0
        let mm = Int(String(s[mr])) ?? 0
        var newHH = hh
        var newMM = mm
        if caretInHour { newHH = (deltaMinutes > 0) ? (hh + 1) : max(0, hh - 1) }
        else           { newMM = (deltaMinutes > 0) ? (mm + 1) % 60 : ((mm == 0) ? 59 : (mm - 1)) }

        let hhText = "\(newHH)"
        let mmText = String(format: "%02d", newMM)
        let newToken = "\(hhText):\(mmText)"

        let moveToEnd = tokenEnd - caret
        if moveToEnd != 0 { textDocumentProxy.adjustTextPosition(byCharacterOffset: moveToEnd) }
        for _ in 0..<(tokenEnd - tokenStart) { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(newToken)
        if caretInHour {
            let back = mmText.count + 1
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -back)
        }
        return true
    }

    // ===== 曜日 =====
    @discardableResult
    private func rotateWeekday(direction: Int) -> Bool {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after  = textDocumentProxy.documentContextAfterInput  ?? ""
        let prev = before.last.map(String.init) ?? ""
        let next = after.first.map(String.init) ?? ""
        let days = ["月","火","水","木","金","土","日"]
        func step(_ s:String)->String? {
            guard let i = days.firstIndex(of: s) else { return nil }
            let j = (i + direction + days.count) % days.count
            return days[j]
        }
        if let r = step(prev) {
            textDocumentProxy.deleteBackward(); textDocumentProxy.insertText(r); return true
        } else if let r = step(next) {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
            textDocumentProxy.deleteBackward(); textDocumentProxy.insertText(r); return true
        }
        return false
    }
}
