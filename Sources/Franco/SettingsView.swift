import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var recording = false
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @State private var loginError: String? = nil
    @State private var testText = ""
    @State private var learnedCount = 0
    @State private var monitor: Any? = nil

    private let languages: [(String, String)] = [("ar", "🇪🇬 Arabic (Franco / Arabizi)"), ("hi", "🇮🇳 Hindi (Hinglish)"), ("ru", "🇷🇺 Russian (translit)"), ("fa", "🇮🇷 Persian (Pinglish)")]

    var body: some View {
        Form {
            Section {
                Toggle("Franco enabled", isOn: $settings.enabled)
                Picker("Language", selection: $settings.language) {
                    ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                }
                HStack {
                    Text("Toggle hotkey")
                    Spacer()
                    Button(recording ? "Press keys…" : settings.hotkey.display) { startRecording() }
                        .keyboardShortcut(.defaultAction)
                    Button("Reset") { settings.hotkey = .default }.controlSize(.small)
                }
                Toggle("Language shortcuts (same modifiers + 1–4)", isOn: $settings.languageHotkeys)
            } header: { Text("General") }

            Section {
                Toggle("Commit first candidate on Space", isOn: $settings.commitOnSpace)
                Toggle("Localize punctuation (? → ؟, , → ،)", isOn: $settings.arabicPunctuation)
                Toggle("Learn picked words (rank them first next time)", isOn: $settings.learnWords)
                HStack {
                    Button("Forget learned words") {
                        for id in Profile.all { Engine.shared.transliterator(id)?.lexicon.resetLearned() }
                        learnedCount = 0
                    }
                    Text(learnedCount > 0 ? "\(learnedCount) learned" : "").foregroundStyle(.secondary).font(.caption)
                }
            } header: { Text("Typing") }

            Section {
                Toggle("Show panel at the text caret (falls back to mouse)", isOn: $settings.panelAtCaret)
                Toggle("Show keyboard hints in panel", isOn: $settings.showHints)
                Stepper("Max candidates: \(settings.maxCandidates)", value: $settings.maxCandidates, in: 3...9)
                HStack { Text("Text size"); Slider(value: $settings.panelScale, in: 0.8...1.5) }
            } header: { Text("Panel") }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { v in
                        do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginError = nil }
                        catch { loginError = "Needs the packaged Franco.app: \(error.localizedDescription)"; launchAtLogin = !v }
                    }
                if let e = loginError { Text(e).font(.caption).foregroundStyle(.red) }
                HStack {
                    Text(AXIsProcessTrusted() ? "Accessibility: granted ✓" : "Accessibility: NOT granted")
                        .foregroundStyle(AXIsProcessTrusted() ? .green : .red)
                    Spacer()
                    Button("Open System Settings") { AppDelegate.openAccessibilityPane() }.controlSize(.small)
                }
            } header: { Text("System") }

            Section {
                TextField("Type here to try it: mar7aba, ezayak, 3amel eh…", text: $testText, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 16))
            } header: { Text("Try it") } footer: {
                Text("Type a word in Latin letters. Space or Enter commits the highlighted suggestion, ↑↓ or Tab cycles, Esc keeps the Latin text.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 640)
        .onAppear { learnedCount = Profile.all.compactMap { Engine.shared.transliterator($0)?.lexicon.learned.count }.reduce(0, +) }
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ev in
            let f = ev.modifierFlags
            let h = Hotkey(keyCode: ev.keyCode, command: f.contains(.command), shift: f.contains(.shift),
                           control: f.contains(.control), option: f.contains(.option))
            if ev.keyCode == 53 { recording = false } // Esc cancels
            else if h.command || h.control || h.option { settings.hotkey = h; recording = false }
            if !recording, let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            return nil
        }
    }
}
