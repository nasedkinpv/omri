//
//  TerminalSessionView.swift
//  Omri (iOS)
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//
//  iOS terminal session view with voice dictation controls
//

import SwiftUI
import SwiftTerm

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

struct TerminalSessionView: View {
    let connection: SSHConnection
    @Bindable var connectionState: ConnectionState

    @State private var isDictating = false
    @State private var isLoadingModels = false
    @State private var terminalManager: iOSTerminalManager?
    @State private var sshClient: SSHClientManager?
    @State private var isConnecting = false
    @State private var connectionError: String?
    @State private var dictationManager: DictationManager?
    @State private var dictationError: String?
    @State private var hasConnectedSSH = false
    @State private var terminalSize: CGSize = .zero
    @State private var keyboardHeight: CGFloat = 0
    @StateObject private var terminalSettings = TerminalSettings.shared
    @GestureState private var magnificationScale: CGFloat = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            // KEYBOARD-AWARE SIZING STRATEGY:
            // We use .ignoresSafeArea(.keyboard) below to prevent iOS from automatically
            // shrinking geometry.size when keyboard appears. This lets us manually control
            // sizing by subtracting keyboardHeight here. Without this, geometry.size would
            // collapse to ~7pt when keyboard shows, causing negative terminal heights.
            let availableHeight = geometry.size.height - keyboardHeight

            // VStack to push content above keyboard
            VStack(spacing: 0) {
                // Terminal view (main content)
                if let manager = terminalManager {
                    // Calculate size accounting for safe area padding
                    // Use safe area insets with minimum 8pt for comfortable spacing
                    let horizontalPadding = max(geometry.safeAreaInsets.leading, 8)
                    let verticalPadding = max(geometry.safeAreaInsets.top, 8)
                    let adjustedSize = CGSize(
                        width: geometry.size.width - (horizontalPadding * 2),
                        height: availableHeight - (verticalPadding * 2)
                    )

                    #if DEBUG
                    let _ = Logger.log("""
                        Terminal Layout:
                           Screen height: \(Int(geometry.size.height))pt
                           Keyboard height: \(Int(keyboardHeight))pt
                           Available height: \(Int(availableHeight))pt
                           Terminal height: \(Int(adjustedSize.height))pt
                           Spacer height: \(Int(keyboardHeight))pt
                           VStack total: \(Int(availableHeight + keyboardHeight))pt
                           Gap check: \(Int(geometry.size.height)) - \(Int(availableHeight + keyboardHeight)) = \(Int(geometry.size.height - (availableHeight + keyboardHeight)))pt
                        """, context: "Terminal", level: .debug)
                    #endif

                    iOSTerminalView(
                        manager: manager,
                        size: adjustedSize,
                        fontSize: terminalSettings.fontSize
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .gesture(
                        MagnifyGesture()
                            .updating($magnificationScale) { value, gestureState, _ in
                                gestureState = value.magnification
                            }
                            .onEnded { value in
                                updateTerminalFontSize(with: value.magnification)
                            }
                    )
                    .onGeometryChange(for: CGSize.self) { proxy in
                        // Track terminal size from GeometryReader
                        proxy.size
                    } action: { newSize in
                        // Trigger SSH connection after first layout completes
                        if !hasConnectedSSH && newSize.width > 0 && newSize.height > 0 {
                            terminalSize = newSize
                            Task {
                                await performSSHConnection()
                            }
                            hasConnectedSSH = true
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // Floating dictation controls (iOS 26 Liquid Glass)
                        FloatingDictationControls(
                            isDictating: isDictating,
                            isLoading: isLoadingModels,
                            onToggleDictation: toggleDictation,
                            onClear: clearInput,
                            onClearLongPress: clearScreen,
                            onEnter: sendEnter,
                            keyboardHeight: keyboardHeight,
                            containerSize: CGSize(
                                width: geometry.size.width,
                                height: availableHeight  // Overlay parent size (terminal + padding)
                            )
                        )
                        .padding(.trailing, horizontalPadding)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 8))
                    }
                } else {
                    terminalPlaceholder
                }

                // Spacer to push terminal content above keyboard
                // This prevents keyboard from covering terminal and FloatingDictationControls
                if keyboardHeight > 0 {
                    Spacer()
                        .frame(height: keyboardHeight)
                }
            }
        }
        .coordinateSpace(name: "container")
        // Prevent iOS from auto-shrinking GeometryReader when keyboard appears
        .ignoresSafeArea(.keyboard)
        // Respect top safe area for proper status bar clearance
        .navigationTitle(connection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden)  // Hide navigation bar for clean terminal experience
        .overlay(alignment: .topLeading) {
            // Floating disconnect button (native iOS 26 style)
            // Uses standard iOS margin (16pt) from safe area edge
            GeometryReader { buttonGeometry in
                Button(action: disconnect) {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.left")
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .disabled(isConnecting)
                .padding(.leading, buttonGeometry.safeAreaInsets.leading + 16)
                .padding(.top, buttonGeometry.safeAreaInsets.top + 16)
            }
        }
        .onAppear {
            prepareTerminal()
            setupDictation()
        }
        .onDisappear {
            cleanup()
        }
        .alert("Connection Failed", isPresented: .constant(connectionError != nil)) {
            Button("Dismiss") {
                connectionError = nil
            }
            Button("Retry") {
                connectionError = nil
                Task {
                    await performSSHConnection()
                }
            }
        } message: {
            if let error = connectionError {
                Text(error)
            }
        }
        .alert("Dictation Error", isPresented: .constant(dictationError != nil)) {
            Button("Dismiss") {
                dictationError = nil
            }
        } message: {
            if let error = dictationError {
                Text(error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardHeight(from: notification, isHiding: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            // Handle keyboard height changes (system ↔ emoji, external keyboard, iPad split/undock)
            updateKeyboardHeight(from: notification)
        }
    }


    private var terminalPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Terminal View")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Connection:")
                    .font(.headline)
                Text("Host: \(connection.host)")
                Text("User: \(connection.username)")
                Text("Port: \(connection.port)")
                Text("Auth: \(connection.authMethod.rawValue)")
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            Text("SwiftTerm iOS integration coming next")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Actions

    private func prepareTerminal() {
        // Load password from Keychain if needed
        var connectionWithPassword = connection
        connectionWithPassword.loadPassword()

        // Create terminal manager (dimensions will be set in makeUIView)
        let manager = iOSTerminalManager(
            connection: connectionWithPassword,
            fontSize: terminalSettings.fontSize
        )
        terminalManager = manager

        // Create SSH client (will connect later with actual dimensions)
        let client = SSHClientManager(
            connection: connectionWithPassword,
            initialCols: 80,  // Placeholder - will be updated before connection
            initialRows: 24   // Placeholder - will be updated before connection
        )

        // Set up closure-based callbacks instead of delegate
        client.onConnect = {
            let connectedMessage = """
            Connected!

            """
            manager.terminalView.feed(byteArray: ArraySlice(connectedMessage.utf8))
        }

        client.onDisconnect = {
            let disconnectedMessage = """
            \r\nConnection closed.\r\n
            """
            manager.terminalView.feed(byteArray: ArraySlice(disconnectedMessage.utf8))
        }

        client.onReceiveOutput = { data in
            manager.terminalView.feed(byteArray: ArraySlice(data))
        }

        manager.sshClient = client
        sshClient = client

        Logger.log("Terminal prepared, waiting for layout to determine actual dimensions", context: "Terminal", level: .info)
    }

    private func performSSHConnection() async {
        guard let manager = terminalManager,
              let client = sshClient else {
            Logger.log("Cannot connect: terminal manager or SSH client not initialized", context: "Terminal", level: .warning)
            return
        }

        // Get actual terminal dimensions (set by makeUIView after layout)
        let terminal = manager.terminalView.getTerminal()
        let actualCols = terminal.cols
        let actualRows = terminal.rows

        Logger.log("Connecting SSH with actual terminal dimensions: \(actualCols)x\(actualRows)", context: "Terminal", level: .info)

        await MainActor.run {
            isConnecting = true
            connectionError = nil
        }

        do {
            Logger.log("Attempting SSH connection to \(connection.host):\(connection.port)...", context: "Terminal", level: .info)
            try await client.connect(cols: actualCols, rows: actualRows)
            await MainActor.run {
                isConnecting = false
            }
            Logger.log("SSH connection successful!", context: "Terminal", level: .info)
        } catch {
            await MainActor.run {
                isConnecting = false
                connectionError = error.localizedDescription
            }
            Logger.log("SSH connection failed: \(error)", context: "Terminal", level: .error)

            // Display error in terminal
            await MainActor.run {
                let errorMessage = """

                Connection failed: \(error.localizedDescription)

                """
                manager.terminalView.feed(byteArray: ArraySlice(errorMessage.utf8))
            }
        }
    }

    private func disconnect() {
        cleanup()
        dismiss()
    }

    private func cleanup() {
        Task {
            await sshClient?.disconnect()
        }
        connectionState.disconnect()
    }

    private func setupDictation() {
        let manager = DictationManager()

        // Set up closures instead of delegate
        manager.onStartRecording = {
            Logger.log("Recording started", context: "Dictation", level: .info)
        }

        manager.onStopRecording = {
            Logger.log("Recording stopped", context: "Dictation", level: .info)
        }

        manager.onError = { error in
            dictationError = error.localizedDescription
            isDictating = false
        }

        manager.onTranscriptionComplete = { text in
            Logger.log("Transcription complete - '\(text)'", context: "Dictation", level: .info)
            // Send transcribed text to terminal
            terminalManager?.sendText(text)
        }

        manager.onModelLoading = { isLoading in
            Logger.log("Model loading state - \(isLoading ? "loading" : "done")", context: "Dictation", level: .debug)
            isLoadingModels = isLoading
        }

        dictationManager = manager
    }

    private func toggleDictation() {
        guard let manager = dictationManager else { return }

        if isDictating {
            // Stop dictation
            Task {
                await manager.stopDictation()
                isDictating = false
            }
        } else {
            // Start dictation
            Task {
                do {
                    try await manager.startDictation()
                    isDictating = true
                } catch {
                    dictationError = error.localizedDescription
                }
            }
        }
    }

    private func clearInput() {
        // Send Ctrl+U to terminal (clear current input line)
        terminalManager?.sendText("\u{15}")
    }

    private func clearScreen() {
        // Send Ctrl+L to terminal (clear screen)
        terminalManager?.sendText("\u{0C}")
    }

    private func sendEnter() {
        // Send carriage return to terminal (standard Enter key behavior)
        // \r triggers command execution in shells, while \n is just line feed
        terminalManager?.sendText("\r")
    }


    // MARK: - Keyboard Handling

    /// Updates terminal size based on keyboard notifications with animation curve matching
    private func updateKeyboardHeight(from notification: Notification, isHiding: Bool = false) {
        guard let userInfo = notification.userInfo else { return }

        // Extract keyboard frame
        let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let newHeight = isHiding ? 0 : keyboardFrame.height

        #if DEBUG
        Logger.log("Keyboard notification: \(isHiding ? "hiding" : "showing")", context: "Keyboard", level: .debug)
        Logger.log("   Frame: \(keyboardFrame)", context: "Keyboard", level: .debug)
        Logger.log("   Reported height: \(newHeight)pt", context: "Keyboard", level: .debug)

        // Check if inputAccessoryView is included in reported height
        if !isHiding, let terminalView = terminalManager?.terminalView,
           let accessory = terminalView.inputAccessoryView {
            let accessoryHeight = accessory.intrinsicContentSize.height
            Logger.log("   inputAccessoryView height: \(accessoryHeight)pt", context: "Keyboard", level: .debug)

            // iOS should include accessory in keyboard frame (total ~350-390pt)
            // System keyboard alone is ~291pt on iPhone
            if newHeight < 320 {
                Logger.log("   WARNING: Keyboard height seems too small!", context: "Keyboard", level: .warning)
                Logger.log("   Expected: ~\(newHeight + accessoryHeight)pt (keyboard + accessory)", context: "Keyboard", level: .warning)
                Logger.log("   This will cause a ~\(Int(accessoryHeight))pt gap!", context: "Keyboard", level: .warning)
            } else {
                Logger.log("   Height appears to include inputAccessoryView", context: "Keyboard", level: .debug)
            }
        }
        #endif

        // Extract animation parameters from notification (iOS best practice)
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int ?? 0

        // Use keyboard's animation curve for perfect sync
        if let uiKitCurve = UIView.AnimationCurve(rawValue: curveValue) {
            let timing = UICubicTimingParameters(animationCurve: uiKitCurve)
            withAnimation(.timingCurve(
                Double(timing.controlPoint1.x),
                Double(timing.controlPoint1.y),
                Double(timing.controlPoint2.x),
                Double(timing.controlPoint2.y),
                duration: duration
            )) {
                keyboardHeight = newHeight
            }
        } else {
            // Fallback to easeOut if curve extraction fails
            withAnimation(.easeOut(duration: duration)) {
                keyboardHeight = newHeight
            }
        }

        #if DEBUG
        Logger.log("   Updated keyboardHeight state: \(keyboardHeight)pt", context: "Keyboard", level: .debug)
        #endif
    }

    private func updateTerminalFontSize(with magnification: CGFloat) {
        // Calculate new font size with constraints (10pt - 24pt)
        let newSize = terminalSettings.fontSize * magnification
        terminalSettings.fontSize = min(max(newSize, 10), 24)

        // Update terminal font (will trigger recalculation of rows/cols via sizeChanged delegate)
        terminalManager?.updateFont(size: terminalSettings.fontSize)
    }
}

// MARK: - iOS Terminal Manager

@MainActor
class iOSTerminalManager: TerminalViewDelegate {
    let connection: SSHConnection
    let terminalView: TerminalView
    weak var sshClient: SSHClientManager?
    private var hasDisplayedWelcome = false
    private var currentFontSize: CGFloat

    init(connection: SSHConnection, fontSize: CGFloat = 12.0) {
        self.connection = connection
        self.currentFontSize = fontSize
        self.terminalView = TerminalView()

        // Configure terminal appearance with dynamic font size
        // TODO: Add terminal settings UI for font selection, color schemes
        if let hackFont = UIFont(name: "HackNFM-Regular", size: fontSize) {
            terminalView.font = hackFont
            Logger.log("Using Hack Nerd Font (HackNFM-Regular) @ \(fontSize)pt", context: "Terminal", level: .info)
        } else {
            terminalView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            Logger.log("Hack Nerd Font not found, falling back to system monospace @ \(fontSize)pt", context: "Terminal", level: .warning)
        }

        terminalView.nativeForegroundColor = .label
        terminalView.nativeBackgroundColor = .systemBackground

        // Set delegate to receive keyboard input and terminal events
        terminalView.terminalDelegate = self

        // Terminal will be sized in makeUIView() with actual GeometryReader dimensions
        // SSH connection will be triggered after terminal is properly sized
        Logger.log("Terminal manager initialized, will be sized during layout", context: "Terminal", level: .info)
    }

    func updateFont(size: CGFloat) {
        currentFontSize = size

        if let hackFont = UIFont(name: "HackNFM-Regular", size: size) {
            terminalView.font = hackFont
            Logger.log("Updated terminal font size to \(size)pt", context: "Terminal", level: .info)
        } else {
            terminalView.font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            Logger.log("Updated terminal font size to \(size)pt (system fallback)", context: "Terminal", level: .info)
        }

        // Font change will trigger terminal resizing via sizeChanged() delegate
    }

    func displayWelcomeMessage() {
        guard !hasDisplayedWelcome else { return }
        hasDisplayedWelcome = true

        // Display connecting message
        let connectingMessage = """
        Connecting to \(connection.username)@\(connection.host):\(connection.port)...
        """

        terminalView.feed(byteArray: ArraySlice(connectingMessage.utf8))
    }

    func sendText(_ text: String) {
        Task {
            // Send character-by-character to properly update shell readline buffer
            // This ensures backspace works on dictated text (fixes readline desync issue)
            for char in text {
                try? await sshClient?.sendText(String(char))
                // Small delay allows readline to process each character
                // 10ms per char = 100 chars/sec (feels instant to user)
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        // Forward keyboard input to SSH
        Task {
            do {
                let text = String(bytes: data, encoding: .utf8) ?? ""
                try await sshClient?.sendText(text)
            } catch {
                Logger.log("Error sending keyboard input: \(error)", context: "Terminal", level: .error)
            }
        }
    }

    func scrolled(source: TerminalView, position: Double) {
        // Terminal scroll position changed by user
        // SwiftTerm handles viewport updates internally
        // This notification allows us to respond to scroll events if needed
    }

    func bell(source: TerminalView) {
        // Provide haptic feedback for terminal bell
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        // Copy to iOS clipboard
        UIPasteboard.general.string = String(data: content, encoding: .utf8)
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        // Terminal lines changed - enables efficient partial redraws
        // This is called when specific terminal lines are updated
        // Helps optimize rendering performance during heavy output
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        // Terminal size changed - notify SSH server of new PTY dimensions
        Logger.log("Size changed to \(newCols)x\(newRows)", context: "Terminal", level: .info)

        // Notify SSH server of new PTY dimensions
        // SwiftTerm handles scroll view updates internally
        Task {
            do {
                try await sshClient?.resizeTerminal(cols: newCols, rows: newRows)
            } catch {
                Logger.log("Error notifying SSH server of size change: \(error)", context: "Terminal", level: .error)
            }
        }
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        // Optional: Could update navigation title
        Logger.log("Terminal title: \(title)", context: "Terminal", level: .debug)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Optional: Track current directory
        if let dir = directory {
            Logger.log("Current directory: \(dir)", context: "Terminal", level: .debug)
        }
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {
        // Open links in Safari
        if let url = URL(string: link) {
            UIApplication.shared.open(url)
        }
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        // Not needed for standard SSH
    }
}

// MARK: - iOS Terminal View (UIViewRepresentable)

struct iOSTerminalView: UIViewRepresentable {
    let manager: iOSTerminalManager
    let size: CGSize
    let fontSize: CGFloat

    func makeUIView(context: Context) -> TerminalView {
        let terminalView = manager.terminalView

        // Set explicit frame based on available size
        terminalView.frame = CGRect(origin: .zero, size: size)

        // Note: Not using autoresizingMask - rely on SwiftUI's updateUIView for resizing
        // This prevents conflicts between UIKit auto-resizing and SwiftUI layout updates

        // Custom keyboard accessory with essential terminal keys
        // Provides: ESC, Ctrl+C, Tab, Paste, Arrow keys
        // Customize buttons in OmriiOS/Models/CustomTerminalAccessory.swift
        let customAccessory = CustomTerminalAccessory(
            frame: CGRect(x: 0, y: 0, width: size.width, height: 44),
            terminalView: terminalView
        )
        terminalView.inputAccessoryView = customAccessory

        // Calculate and set initial terminal size with ACTUAL view dimensions
        resizeTerminal(terminalView, to: size)

        // Display welcome message now that terminal is sized
        manager.displayWelcomeMessage()

        // Make terminal first responder to receive keyboard input
        DispatchQueue.main.async {
            _ = terminalView.becomeFirstResponder()
        }

        // SSH connection will be triggered by onGeometryChange after layout completes
        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Update frame if size changed
        if uiView.frame.size != size {
            #if DEBUG
            Logger.log("Terminal resize: \(Int(uiView.frame.size.width))x\(Int(uiView.frame.size.height)) → \(Int(size.width))x\(Int(size.height))", context: "Terminal", level: .debug)
            #endif

            uiView.frame = CGRect(origin: .zero, size: size)
            resizeTerminal(uiView, to: size)
        }
    }

    private func resizeTerminal(_ terminalView: TerminalView, to size: CGSize) {
        guard size.width > 0 && size.height > 0 else {
            Logger.log("Invalid size: \(size)", context: "Terminal", level: .error)
            return
        }

        // Calculate character dimensions using UIKit
        let font = terminalView.font
        let charSize = ("W" as NSString).size(withAttributes: [.font: font])
        let charWidth = charSize.width
        let charHeight = charSize.height

        guard charWidth > 0 && charHeight > 0 else {
            Logger.log("Invalid char size: \(charSize)", context: "Terminal", level: .error)
            return
        }

        let cols = Int(size.width / charWidth)
        let rows = Int(size.height / charHeight)

        guard cols > 0 && rows > 0 else {
            Logger.log("Invalid terminal dimensions: \(cols)x\(rows)", context: "Terminal", level: .error)
            return
        }

        // Resize terminal locally
        let terminal = terminalView.getTerminal()
        if terminal.cols != cols || terminal.rows != rows {
            terminalView.resize(cols: cols, rows: rows)
            Logger.log("Terminal resized to \(cols)x\(rows) for view size \(size)", context: "Terminal", level: .info)

            // SwiftTerm's resize() handles scroll view updates internally
            // The sizeChanged() delegate will be called, which notifies SSH server

            // Note: We don't call sshClient.resizeTerminal here because
            // it will be called from the sizeChanged() delegate method
        }
    }
}

#Preview {
    @Previewable @State var connectionState = ConnectionState()
    NavigationStack {
        TerminalSessionView(
            connection: SSHConnection(
                host: "example.com",
                username: "user",
                port: 22
            ),
            connectionState: connectionState
        )
    }
}
