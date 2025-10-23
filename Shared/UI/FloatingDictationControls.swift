//
//  FloatingDictationControls.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  Cross-platform floating dictation controls with iOS 26 Liquid Glass
//  Features: Draggable positioning, long-press gestures, hover states
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

struct FloatingDictationControls: View {
    // Core state
    let isDictating: Bool
    let isLoading: Bool
    let onToggleDictation: () -> Void
    let onClear: () -> Void
    let onClearLongPress: (() -> Void)?
    let onEnter: () -> Void

    // Layout constraints (iOS only)
    #if os(iOS)
    let keyboardHeight: CGFloat
    #endif

    // Initialize with optional long press
    init(
        isDictating: Bool,
        isLoading: Bool,
        onToggleDictation: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onClearLongPress: (() -> Void)? = nil,
        onEnter: @escaping () -> Void,
        keyboardHeight: CGFloat = 0,
        containerSize: CGSize = .zero
    ) {
        self.isDictating = isDictating
        self.isLoading = isLoading
        self.onToggleDictation = onToggleDictation
        self.onClear = onClear
        self.onClearLongPress = onClearLongPress
        self.onEnter = onEnter
        #if os(iOS)
        self.keyboardHeight = keyboardHeight
        self.containerSize = containerSize
        #endif
    }

    // Animation state
    @State private var pulseScale: CGFloat = 1.0

    // Draggable offset state (iOS only)
    @AppStorage("dictationControlsOffsetX") private var savedOffsetX: Double = 0
    @AppStorage("dictationControlsOffsetY") private var savedOffsetY: Double = 0
    @State private var currentOffset = CGSize.zero  // Current drag offset

    #if os(iOS)
    let containerSize: CGSize  // Container bounds for drag limits (passed from parent)
    @State private var controlsSize = CGSize.zero  // Actual measured size of controls
    #endif

    // Interaction states
    @GestureState private var isClearLongPressing = false
    @State private var clearCompleted = false
    @GestureState private var isDictateHolding = false  // For hold-to-record
    @State private var dictateHoldStarted = false       // Track if hold recording started
    @GestureState private var isEnterPressed = false    // For enter button pressed state
    @State private var isHoveringDictate = false
    @State private var isHoveringClear = false
    @State private var isHoveringEnter = false

    var body: some View {
        #if os(iOS)
        draggableControls
        #else
        // macOS: Fixed centered position (no dragging needed in windowed environment)
        controlsContent
        #endif
    }

    // MARK: - Draggable iOS Layout

    #if os(iOS)
    private var draggableControls: some View {
        controlsContent
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            controlsSize = geometry.size
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            controlsSize = newSize
                        }
                }
            )
            .contentShape(Rectangle())  // Make entire panel area (including padding) hittable for drag
            .offset(currentOffset)
            .simultaneousGesture(dragGesture)  // simultaneousGesture allows both drag and button taps
            .onAppear {
                // Restore saved offset from @AppStorage
                currentOffset = CGSize(width: savedOffsetX, height: savedOffsetY)
            }
    }
    #endif

    // MARK: - Controls Content

    private var controlsContent: some View {
        HStack(spacing: 8) {
            dictateButton

            #if os(iOS)
            // Visual drag indicator (iOS only - entire control is draggable)
            Divider()
                .frame(width: 1, height: 24)
                .frame(width: 20)  // Visual spacing
                .allowsHitTesting(false)  // Drag gesture attached to parent
            #else
            Divider()
                .frame(height: 24)
            #endif

            clearButton
            enterButton
        }
        .padding(.horizontal, 6)  // Reduced horizontal padding to match circular button edge
        .padding(.vertical, 12)    // Keep vertical padding for balance
        .applyGlassEffect()
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .onChange(of: isDictating) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.3
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
    }

    // MARK: - Button Components

    private var dictateButton: some View {
        let buttonTint: Color
        let accessLabel: String
        let accessHint: String

        if isLoading {
            buttonTint = Color("BrandBlue").opacity(0.6)
            accessLabel = "Loading Models"
            accessHint = "Please wait while models are downloaded"
        } else if isDictating {
            buttonTint = Color.red
            accessLabel = "Stop Dictation"
            accessHint = "Tap to stop, or hold to record"
        } else {
            buttonTint = Color("BrandBlue")
            accessLabel = "Start Dictation"
            accessHint = "Tap to start, or hold for 1s to record"
        }

        return Button(action: {
            guard !isLoading else { return }

            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            #endif
            onToggleDictation()
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: isDictating ? "stop.fill" : "mic.fill")
                        .font(.title3.weight(.medium))
                        .frame(width: 44, height: 44)
                        #if os(iOS)
                        .symbolEffect(.pulse, isActive: isDictating)
                        #endif
                }
            }
        }
        .buttonStyle(glassProminentButtonStyle)
        .buttonBorderShape(.circle)
        .tint(buttonTint)
        .overlay(pulseOverlay)
        .scaleEffect(isDictateHolding ? 0.95 : (isHoveringDictate ? 1.05 : 1.0))  // Pressed state
        .opacity(isDictateHolding ? 0.8 : 1.0)  // More obvious pressed state
        .disabled(isLoading)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0)
                .updating($isDictateHolding) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    guard !isLoading else { return }

                    #if os(iOS)
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                    #endif

                    // Start recording on long press complete
                    if !isDictating {
                        dictateHoldStarted = true
                        onToggleDictation()
                    }
                }
        )
        .onChange(of: isDictateHolding) { _, isHolding in
            // When user releases after starting hold recording, stop it
            if !isHolding && dictateHoldStarted && isDictating {
                dictateHoldStarted = false
                // Small delay before stopping to ensure user had time to speak
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if isDictating {
                        onToggleDictation()
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHoveringDictate = hovering
            }
        }
        .accessibilityLabel(accessLabel)
        .accessibilityHint(accessHint)
    }

    @ViewBuilder
    private var pulseOverlay: some View {
        if isDictating {
            let opacityValue = 1.0 - ((pulseScale - 1.0) * 2.0)
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                .scaleEffect(pulseScale)
                .opacity(opacityValue)
        }
    }

    private var clearButton: some View {
        Button {
            // Single tap: Clear current input line (Ctrl+U)
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
            onClear()
        } label: {
            Image(systemName: "xmark.circle")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(glassButtonStyle)
        .buttonBorderShape(.circle)
        .scaleEffect(isClearLongPressing ? 1.1 : (isHoveringClear ? 1.05 : 1.0))
        .opacity(isClearLongPressing ? 0.8 : 1.0)
        .simultaneousGesture(
            // Add long press gesture alongside tap (if callback provided)
            onClearLongPress != nil ?
                LongPressGesture(minimumDuration: 0.8)
                    .updating($isClearLongPressing) { currentState, gestureState, transaction in
                        gestureState = currentState
                    }
                    .onEnded { _ in
                        #if os(iOS)
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        #endif
                        onClearLongPress?()
                        clearCompleted = true
                    }
                : nil
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHoveringClear = hovering
            }
        }
        .accessibilityLabel("Clear Input")
        .accessibilityHint(onClearLongPress != nil ? "Tap to clear input, long press to clear screen" : "Tap to clear current line")
    }

    private var enterButton: some View {
        Button(action: {
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
            onEnter()
        }) {
            Image(systemName: "return")
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(glassButtonStyle)
        .buttonBorderShape(.circle)
        .scaleEffect(isEnterPressed ? 0.95 : (isHoveringEnter ? 1.05 : 1.0))  // Pressed state
        .opacity(isEnterPressed ? 0.8 : 1.0)  // More obvious pressed state
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isEnterPressed) { _, gestureState, _ in
                    gestureState = true
                }
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHoveringEnter = hovering
            }
        }
        .accessibilityLabel("Enter")
        .accessibilityHint("Tap to send return key")
    }

    // MARK: - Button Styles (iOS 26+ Glass Support)

    private var glassButtonStyle: some PrimitiveButtonStyle {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return GlassButtonStyle()
        } else {
            return BorderedButtonStyle()
        }
        #else
        return BorderedButtonStyle()
        #endif
    }

    private var glassProminentButtonStyle: some PrimitiveButtonStyle {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return GlassProminentButtonStyle()
        } else {
            return BorderedProminentButtonStyle()
        }
        #else
        return BorderedProminentButtonStyle()
        #endif
    }

    // MARK: - Draggable Positioning (iOS)

    #if os(iOS)
    private var dragGesture: some Gesture {
        // minimumDistance: 10 prevents accidental drags and allows button taps to work
        DragGesture(minimumDistance: 10, coordinateSpace: .named("container"))
            .onChanged { value in
                // Calculate desired offset
                let desiredX = savedOffsetX + value.translation.width
                let desiredY = savedOffsetY + value.translation.height

                // Apply bounds to prevent dragging off-screen or under keyboard/navbar
                let clampedOffset = clampOffset(x: desiredX, y: desiredY)
                currentOffset = clampedOffset
            }
            .onEnded { value in
                // Calculate final offset with bounds
                let desiredX = savedOffsetX + value.translation.width
                let desiredY = savedOffsetY + value.translation.height
                let clampedOffset = clampOffset(x: desiredX, y: desiredY)

                // Save clamped offset to @AppStorage
                savedOffsetX = clampedOffset.width
                savedOffsetY = clampedOffset.height
                currentOffset = clampedOffset
            }
    }

    /// Clamps offset to keep controls within visible bounds
    private func clampOffset(x: Double, y: Double) -> CGSize {
        guard containerSize.width > 0 && containerSize.height > 0,
              controlsSize.width > 0 && controlsSize.height > 0 else {
            // Don't clamp if container or controls not yet measured
            return CGSize(width: x, height: y)
        }

        let controlsWidth = controlsSize.width
        let controlsHeight = controlsSize.height
        let padding: CGFloat = 8  // Compact spacing (matches overlay padding and CustomTerminalAccessory)

        // X bounds: Controls start at trailing edge with 8pt padding
        // Can move left to show on screen, can't move right beyond initial
        let minX = -(containerSize.width - controlsWidth - padding * 2)
        let maxX: CGFloat = 0  // Can't move right beyond initial position

        // Y bounds: Controls start at bottom with 8pt padding
        // Can move up within terminal area (overlay is relative to terminal, not screen)
        // containerSize.height is already the terminal bounds, no need to subtract navbar
        let minY = -(containerSize.height - controlsHeight - padding * 2)
        let maxY: CGFloat = 0  // Can't move down beyond initial position

        return CGSize(
            width: min(max(x, minX), maxX),
            height: min(max(y, minY), maxY)
        )
    }
    #endif
}

// MARK: - Glass Effect Modifier (iOS 26+)

extension View {
    /// Applies iOS 26 Liquid Glass effect on supported OS versions,
    /// falls back to regular material capsule on iOS 17-25 and macOS
    @ViewBuilder
    func applyGlassEffect() -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            self
                .background {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.interactive())
                }
        } else {
            self
                .background(.regularMaterial, in: Capsule())
        }
        #else
        self
            .background(.regularMaterial, in: Capsule())
        #endif
    }
}

// MARK: - Custom Button Styles (iOS 26)

#if os(iOS)
@available(iOS 26.0, *)
struct GlassButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.glass)
    }
}

@available(iOS 26.0, *)
struct GlassProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.glassProminent)
    }
}
#endif

struct BorderedButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.bordered)
    }
}

struct BorderedProminentButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonStyle(.borderedProminent)
    }
}

// MARK: - Preview

#if os(iOS)
#Preview("Idle") {
    GeometryReader { geometry in
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            VStack {
                Spacer()

                FloatingDictationControls(
                    isDictating: false,
                    isLoading: false,
                    onToggleDictation: { Logger.log("Toggle dictation", context: "UI", level: .debug) },
                    onClear: { Logger.log("Clear", context: "UI", level: .debug) },
                    onEnter: { Logger.log("Enter", context: "UI", level: .debug) },
                    containerSize: CGSize(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                )
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Recording") {
    GeometryReader { geometry in
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            VStack {
                Spacer()

                FloatingDictationControls(
                    isDictating: true,
                    isLoading: false,
                    onToggleDictation: { Logger.log("Toggle dictation", context: "UI", level: .debug) },
                    onClear: { Logger.log("Clear", context: "UI", level: .debug) },
                    onEnter: { Logger.log("Enter", context: "UI", level: .debug) },
                    containerSize: CGSize(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                )
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
    }
}

#Preview("Loading Models") {
    GeometryReader { geometry in
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()

            VStack {
                Spacer()

                FloatingDictationControls(
                    isDictating: false,
                    isLoading: true,
                    onToggleDictation: { Logger.log("Toggle dictation", context: "UI", level: .debug) },
                    onClear: { Logger.log("Clear", context: "UI", level: .debug) },
                    onEnter: { Logger.log("Enter", context: "UI", level: .debug) },
                    containerSize: CGSize(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                )
                .padding(.trailing, 8)
                .padding(.bottom, 8)
            }
        }
    }
}
#endif
