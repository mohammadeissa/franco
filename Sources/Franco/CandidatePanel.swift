import AppKit
import SwiftUI

/// Observable model for the candidate list.
final class CandidateModel: ObservableObject {
    @Published var input: String = ""
    @Published var candidates: [Candidate] = []
    @Published var selected: Int = 0
    @Published var rtl: Bool = true
    @Published var flag: String = ""
}

struct CandidateListView: View {
    @ObservedObject var model: CandidateModel
    @ObservedObject var settings = Settings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(model.flag).font(.system(size: 11))
                Text(model.input).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.top, 7).padding(.bottom, 4)
            ForEach(Array(model.candidates.enumerated()), id: \.offset) { i, c in
                HStack(spacing: 8) {
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(i == model.selected ? Color.white.opacity(0.9) : Color.secondary)
                        .frame(width: 14)
                    Text(c.text)
                        .font(.system(size: 17 * settings.panelScale, weight: i == model.selected ? .semibold : .regular))
                        .foregroundStyle(i == model.selected ? Color.white : Color.primary)
                        .environment(\.layoutDirection, model.rtl ? .rightToLeft : .leftToRight)
                    Spacer(minLength: 8)
                    if c.kind != .exact {
                        Text(c.kind == .literal ? "literal" : "more")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(i == model.selected ? Color.white.opacity(0.8) : Color.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(i == model.selected ? Color.accentColor : Color.clear)
                )
                .padding(.horizontal, 4)
            }
            if settings.showHints {
                Text("space · enter  ↑↓ tab  esc keeps latin")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 10).padding(.top, 5).padding(.bottom, 6)
            } else {
                Spacer().frame(height: 5)
            }
        }
        .frame(minWidth: 190, maxWidth: 300, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

/// Floating non-activating panel anchored near the caret.
final class CandidatePanel {
    let model = CandidateModel()
    private let panel: NSPanel
    private let host: NSHostingView<CandidateListView>

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
                        styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                        backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.ignoresMouseEvents = true
        host = NSHostingView(rootView: CandidateListView(model: model))
        panel.contentView = host
    }

    func show(at anchor: CaretLocator.Anchor) {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        var origin = CGPoint(x: anchor.rect.minX, y: anchor.rect.minY - size.height - 6)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: anchor.rect.midX, y: anchor.rect.midY)) }) ?? NSScreen.main {
            let f = screen.visibleFrame
            if origin.y < f.minY { origin.y = anchor.rect.maxY + 6 }          // flip above
            if origin.x + size.width > f.maxX { origin.x = f.maxX - size.width - 8 }
            if origin.x < f.minX { origin.x = f.minX + 8 }
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func refresh() {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        var f = panel.frame
        let top = f.maxY
        f.size = size
        f.origin.y = top - size.height
        panel.setFrame(f, display: true)
    }

    func hide() { panel.orderOut(nil) }
    var isVisible: Bool { panel.isVisible }
}
