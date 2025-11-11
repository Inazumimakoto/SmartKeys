import UIKit

final class InputEngine {

    // 画面に出している未確定ローマ字
    private var buffer: [Character] = []

    private let vowels: Set<Character> = ["a","i","u","e","o"]
    private let consonants: Set<Character> = Set("bcdfghjklmnpqrstvwxyz")
    // 促音対象（nnは除外する）
    private let sokuonTargets: Set<Character> = Set("bcdfghjklmpqrstvwxyz").subtracting(["n"])

    // ===== 単音（清音/濁音/半濁音/代替/外来/拡張） =====
    // ※ 母音1文字 a/i/u/e/o もここに入っている
    private let mono: [String:String] = [
        "a":"あ","i":"い","u":"う","e":"え","o":"お",

        "ka":"か","ki":"き","ku":"く","ke":"け","ko":"こ",
        "ga":"が","gi":"ぎ","gu":"ぐ","ge":"げ","go":"ご",

        "sa":"さ","si":"し","shi":"し","su":"す","se":"せ","so":"そ",
        "za":"ざ","zi":"じ","ji":"じ","zu":"ず","ze":"ぜ","zo":"ぞ",

        "ta":"た","ti":"ち","chi":"ち","tu":"つ","tsu":"つ","te":"て","to":"と",
        "da":"だ","di":"ぢ","du":"づ","dzu":"づ","de":"で","do":"ど",

        "na":"な","ni":"に","nu":"ぬ","ne":"ね","no":"の",

        "ha":"は","hi":"ひ","hu":"ふ","fu":"ふ","he":"へ","ho":"ほ",
        "ba":"ば","bi":"び","bu":"ぶ","be":"べ","bo":"ぼ",
        "pa":"ぱ","pi":"ぴ","pu":"ぷ","pe":"ぺ","po":"ぽ",

        "ma":"ま","mi":"み","mu":"む","me":"め","mo":"も",

        "ya":"や","yu":"ゆ","yo":"よ",

        "ra":"ら","ri":"り","ru":"る","re":"れ","ro":"ろ",

        "wa":"わ","wi":"うぃ","we":"うぇ","wo":"を",

        // c/q 便宜
        "ca":"か","ci":"し","cu":"く","ce":"せ","co":"こ",
        "qa":"くぁ","qi":"くぃ","qu":"く","qe":"くぇ","qo":"くぉ",

        // f 系
        "fa":"ふぁ","fi":"ふぃ","fe":"ふぇ","fo":"ふぉ",

        // v 系
        "va":"ゔぁ","vi":"ゔぃ","vu":"ゔ","ve":"ゔぇ","vo":"ゔぉ",

        // ye
        "ye":"いぇ",

        // wh 系
        "wha":"うぁ","whi":"うぃ","whu":"う","whe":"うぇ","who":"うぉ",

        // tw / dw 系
        "twa":"とぁ","twi":"とぃ","twu":"とぅ","twe":"とぇ","two":"とぉ",
        "dwa":"どぁ","dwi":"どぃ","dwu":"どぅ","dwe":"どぇ","dwo":"どぉ",

        // qwa 系（kwa 別名）
        "qwa":"くぁ","qwi":"くぃ","qwe":"くぇ","qwo":"くぉ"
    ]

    // ===== 拗音 =====
    private let yoon: [String:String] = [
        // k/g
        "kya":"きゃ","kyu":"きゅ","kyo":"きょ",
        "gya":"ぎゃ","gyu":"ぎゅ","gyo":"ぎょ",

        // s/z/j
        "sya":"しゃ","sha":"しゃ","syu":"しゅ","shu":"しゅ","syo":"しょ","sho":"しょ",
        "zya":"じゃ","ja":"じゃ","jya":"じゃ",
        "zyu":"じゅ","ju":"じゅ","jyu":"じゅ",
        "zyo":"じょ","jo":"じょ","jyo":"じょ",
        "she":"しぇ","je":"じぇ",

        // t/d/ch
        "tya":"ちゃ","cha":"ちゃ","tyu":"ちゅ","chu":"ちゅ","tyo":"ちょ","cho":"ちょ",
        "che":"ちぇ",
        "tsa":"つぁ","tsi":"つぃ","tse":"つぇ","tso":"つぉ",
        "dya":"ぢゃ","dyu":"ぢゅ","dyo":"ぢょ",

        // n
        "nya":"にゃ","nyu":"にゅ","nyo":"にょ",

        // h/b/p/m/r
        "hya":"ひゃ","hyu":"ひゅ","hyo":"ひょ",
        "bya":"びゃ","byu":"びゅ","byo":"びょ",
        "pya":"ぴゃ","pyu":"ぴゅ","pyo":"ぴょ",
        "mya":"みゃ","myu":"みゅ","myo":"みょ",
        "rya":"りゃ","ryu":"りゅ","ryo":"りょ",

        // f 拗音
        "fya":"ふゃ","fyu":"ふゅ","fyo":"ふょ",

        // kw/gw
        "kwa":"くぁ","kwi":"くぃ","kwe":"くぇ","kwo":"くぉ",
        "gwa":"ぐぁ","gwi":"ぐぃ","gwe":"ぐぇ","gwo":"ぐぉ",

        // c 系 alias
        "cya":"ちゃ","cyu":"ちゅ","cyo":"ちょ"
    ]

    // ===== 小書き =====
    private let smalls: [String:String] = [
        "xa":"ぁ","xi":"ぃ","xu":"ぅ","xe":"ぇ","xo":"ぉ",
        "la":"ぁ","li":"ぃ","lu":"ぅ","le":"ぇ","lo":"ぉ",

        "xya":"ゃ","xyu":"ゅ","xyo":"ょ",
        "lya":"ゃ","lyu":"ゅ","lyo":"ょ",

        "xtu":"っ","ltu":"っ","ltsu":"っ",

        "xwa":"ゎ","lwa":"ゎ",

        // 拡張（小書きの i/e）
        "xyi":"ぃ","lyi":"ぃ","xye":"ぇ","lye":"ぇ",

        // 歴史的仮名
        "wyi":"ゐ","wye":"ゑ"
    ]

    func feed(letter: Character, proxy: UITextDocumentProxy) {
        // 非英字（スペース・記号・改行など）
        guard letter.isAsciiLetter else {
            commitPendingIfNeeded(proxy: proxy, endOfWordTrigger: true)
            proxy.insertText(String(letter))
            return
        }

        let ch = Character(letter.lowercased())

        // --- ★最優先：buffer が「n」で、今回も 'n' → 「nn を ん」に確定（2文字目は出さない）
        if buffer == ["n"], ch == "n" {
            // 直前に表示された 'n' を消して ん に置換
            proxy.deleteBackward()
            proxy.insertText("ん")
            buffer.removeAll()
            return
        }

        // --- 特例：buffer が「n」で、今回が子音（'y' 以外 & 'n' 以外）→ 直前の 'n' を「ん」に置換して続行
        if buffer == ["n"], consonants.contains(ch), ch != "y", ch != "n" {
            proxy.deleteBackward()      // 直前の 'n'
            proxy.insertText("ん")      // 置換
            buffer.removeAll()
            // このあと通常処理に落ちる（今回の子音 ch はこの後で表示）
        }

        // --- 促音：同一子音が連続（nn は除外）
        if let last = buffer.last, last == ch, sokuonTargets.contains(ch) {
            proxy.deleteBackward()
            proxy.insertText("っ")
            proxy.insertText(String(ch))
            buffer = [ch]
            return
        }

        // まず表示 → バッファ追加
        proxy.insertText(String(ch))
        buffer.append(ch)

        // === 置換（最長一致）===
        if let (len, kana) = longestMatch() {
            for _ in 0..<len { proxy.deleteBackward() }
            proxy.insertText(kana)
            buffer.removeAll()
            return
        }

        // --- 安全網：'nn' を見つけたら即「ん」
        if buffer.count >= 2, buffer.suffix(2) == Array("nn") {
            proxy.deleteBackward()
            proxy.deleteBackward()
            proxy.insertText("ん")
            buffer.removeAll()
        }
    }


    // Delete：バッファがあれば1文字巻き戻し（画面も1字消す）
    @discardableResult
    func handleDelete(proxy: UITextDocumentProxy) -> Bool {
        if !buffer.isEmpty {
            buffer.removeLast()
            proxy.deleteBackward()
            return true
        }
        return false
    }

    // スペース/改行/句読点直前など（語末処理）
    func commitPendingIfNeeded(proxy: UITextDocumentProxy, endOfWordTrigger: Bool) {
        guard !buffer.isEmpty else { return }
        if buffer == ["n"] {
            // 最後が n 単独 → 直前の 'n' を「ん」に置換
            proxy.deleteBackward()
            proxy.insertText("ん")
            buffer.removeAll()
            return
        }
        // それ以外は“表示済みローマ字のまま確定”
        buffer.removeAll()
    }

    // 小書き → 拗音 → 単音 の順で、長いキーを優先（4→3→2→1）
    private func longestMatch() -> (Int, String)? {
        let s = String(buffer)
        for len in [4,3,2,1] { // ★ 1 を追加：a/i/u/e/o など単母音も即かな化
            guard s.count >= len else { continue }
            let key = String(s.suffix(len))
            if let v = smalls[key] { return (len, v) }
            if let v = yoon[key]   { return (len, v) }
            if let v = mono[key]   { return (len, v) }
        }
        return nil
    }
}

private extension Character {
    var isAsciiLetter: Bool {
        let lower = String(self).lowercased()
        return lower.count == 1 && ("a"..."z").contains(Character(lower))
    }
}

