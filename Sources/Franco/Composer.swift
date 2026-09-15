import AppKit

/// Composition state machine: buffers a Latin word, shows candidates, commits/cancels.
final class Composer {
    private(set) var buffer: String = ""
    private var candidates: [Candidate] = []
    private var selected = 0
    let panel = CandidatePanel()
    private let settings = Settings.shared

    var isComposing: Bool { !buffer.isEmpty }

    private var translit: Transliterator? { Engine.shared.transliterator(settings.language) }

    // MARK: input

    /// Called for a printable character the user typed (already passed through to the app).
    func append(_ ch: Character) {
        buffer.append(ch)
        recompute(reposition: buffer.count == 1)
    }

    func backspace() {
        guard !buffer.isEmpty else { return }
        buffer.removeLast()
        if buffer.isEmpty { cancel() } else { recompute(reposition: false) }
    }

    func moveSelection(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        selected = (selected + delta + candidates.count) % candidates.count
        panel.model.selected = selected
    }

    func select(index: Int) {
        guard index >= 0, index < candidates.count else { return }
        selected = index
        panel.model.selected = selected
    }

    /// Commit the highlighted candidate, replacing the typed Latin text. `trailing` is appended (space/punct).
    func commit(trailing: String = "") {
        guard isComposing else { return }
        let typed = buffer
        let cand = candidates.indices.contains(selected) ? candidates[selected] : nil
        let out = cand?.text ?? typed
        let digitsOnly = typed.allSatisfy { $0.isNumber }
        reset()
        if digitsOnly || out == typed {
            if !trailing.isEmpty { Injector.type(trailing) }
            return
        }
        Log.info("commit '\(typed)' → '\(out)'")
        Injector.replace(deleteCount: typed.count, with: out, trailing: trailing)
        if settings.learnWords, let c = cand, (c.kind != .exact || selected > 0) {
            translit?.lexicon.learn(c.text)
        }
    }

    /// Keep the Latin text as typed; just close the panel.
    func cancel() { reset() }

    private func reset() {
        buffer = ""; candidates = []; selected = 0
        panel.hide()
    }

    // MARK: candidates

    private func recompute(reposition: Bool) {
        guard let t = translit else { return }
        candidates = t.candidates(for: buffer, limit: settings.maxCandidates)
        if buffer.count == 1 { Log.info("compose start '\(buffer)' → \(candidates.count) candidates") }
        selected = 0
        let m = panel.model
        m.input = buffer
        m.candidates = candidates
        m.selected = 0
        m.rtl = t.profile.rtl
        m.flag = t.profile.flag
        if candidates.isEmpty { panel.hide(); return }
        if reposition || !panel.isVisible {
            let anchor = settings.panelAtCaret ? CaretLocator.locate() : CaretLocator.Anchor(rect: mouseRect(), exact: false)
            panel.show(at: anchor)
        } else {
            panel.refresh()
        }
    }

    private func mouseRect() -> CGRect {
        let m = NSEvent.mouseLocation
        return CGRect(x: m.x, y: m.y - 8, width: 1, height: 16)
    }

    func punctuation(for ch: Character) -> String {
        guard settings.arabicPunctuation, let p = Engine.shared.profile(settings.language)?.punct[String(ch)] else { return String(ch) }
        return p
    }
}
