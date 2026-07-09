//
//  DictationHUD.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2026 beneric.studio. All rights reserved.
//
//  A notch overlay that shows what Omri heard, and — when the transcript is only
//  copied rather than inserted — reminds the user to paste it.
//
//  Geometry, the notch shape and the notchless fallback come from DynamicNotchKit.
//  Its panel is a non-activating one shown with orderFrontRegardless(), so the user's
//  cursor stays in whatever app they were typing in and ⌘V still lands there.
//

import AppKit
import DynamicNotchKit
import SwiftUI

// MARK: - State

@MainActor
@Observable
final class DictationHUDState {
    enum Phase {
        case recording
        case processing
        case result(pasteHint: Bool)
    }

    var phase: Phase = .recording
    var text: String = ""
}

// MARK: - Controller

@MainActor
final class DictationHUD {
    private let state = DictationHUDState()
    private lazy var notch = makeNotch()
    private var dismissTask: Task<Void, Never>?

    func showRecording() {
        dismissTask?.cancel()
        state.text = ""
        state.phase = .recording
        // Compact: just a pulsing dot beside the notch until there is something to read.
        Task { await notch.compact(on: .withMouse) }
    }

    func showProcessing() {
        state.phase = .processing
    }

    /// In-progress transcript. Only streaming providers send these; cloud APIs return once.
    func showVolatileText(_ text: String) {
        state.text = text
        Task { await notch.expand(on: .withMouse) }
    }

    /// Final transcript. Stays up longer when the user still has to paste it themselves.
    func showResult(_ text: String, pasteHint: Bool) {
        state.text = text
        state.phase = .result(pasteHint: pasteHint)
        Task { await notch.expand(on: .withMouse) }
        dismiss(after: pasteHint ? .seconds(5) : .seconds(2))
    }

    func hide() {
        dismissTask?.cancel()
        Task { await notch.hide() }
    }

    private func dismiss(after duration: Duration) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            await notch.hide()
        }
    }

    private func makeNotch() -> DynamicNotch<ExpandedView, CompactIndicator, EmptyView> {
        DynamicNotch(
            // Omri's overlay is not interactive: hovering it must not keep it on screen.
            hoverBehavior: [],
            expanded: { [state] in ExpandedView(state: state) },
            compactLeading: { [state] in CompactIndicator(state: state) }
        )
    }
}

private extension NSScreen {
    /// DynamicNotchKit defaults to `screens[0]`; dictation should follow the user instead.
    static var withMouse: NSScreen {
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? screens[0]
    }
}

// MARK: - Views

private struct CompactIndicator: View {
    let state: DictationHUDState

    var body: some View {
        Group {
            switch state.phase {
            case .recording:
                PulsingDot(color: Color("BrandPrimary"))
            case .processing:
                ProgressView().controlSize(.mini)
            case .result:
                Image(systemName: "checkmark")
                    .foregroundStyle(Color("BrandSecondary"))
            }
        }
        .frame(width: 20, height: 20)
    }
}

private struct ExpandedView: View {
    let state: DictationHUDState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(state.text)
                .font(.system(size: 14))
                .lineLimit(3)
                // Long dictations should keep the newest words visible.
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.interpolate)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 320)
        .animation(.snappy(duration: 0.2), value: state.text)
    }

    private var title: String {
        switch state.phase {
        case .recording: "Listening…"
        case .processing: "Transcribing…"
        case .result(let pasteHint): pasteHint ? "Copied — press ⌘V to paste" : "Inserted"
        }
    }
}

private struct PulsingDot: View {
    let color: Color
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(pulsing ? 1.0 : 0.6)
            .opacity(pulsing ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}
