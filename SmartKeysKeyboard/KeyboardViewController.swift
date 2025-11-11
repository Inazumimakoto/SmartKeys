import UIKit

final class KeyboardViewController: UIInputViewController {
    private let toolbar = UIStackView()
    private let main = UIStackView()
    private var isShifted = false

    // IME
    private let ime = InputEngine()

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
            let b = UIButton(type:.system)
            b.backgroundColor = .secondarySystemBackground
            b.layer.cornerRadius = 6
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            b.titleLabel?.font = .systemFont(ofSize: 20)
            b.setTitle(title(for:key), for: .normal)
            b.tag = tag(for:key)

            switch key {
            case .delete:
                b.accessibilityIdentifier = "delete"
                b.addTarget(self, action: #selector(repeatPressDown(_:)), for: .touchDown)
                b.addTarget(self, action: #selector(repeatPressEnd(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            default:
                b.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
            }

            row.addArrangedSubview(b)
        }
        return row
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

