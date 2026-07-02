//
//  AppDelegate.swift
//  Omri
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import AVFoundation
import Cocoa
import UserNotifications

// MARK: - Import Shared Logger
// Note: Logger.swift is in Shared/Utils/ and available to both targets

@MainActor  // Make AppDelegate a MainActor class
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioManager: AudioManager!  // This will also be main actor isolated
    private var pasteManager: PasteManager!  // Keep a reference to PasteManager
    private var transformationService: TransformationService?
    private var settingsWindowController: SettingsWindowController?
    #if SSH_TERMINAL
    private var sshConnectionsWindowController: SSHConnectionsWindowController?
    #endif
    private var downloadStatusMenuItem: NSMenuItem?  // For showing download progress

    // Shared reference for accessing AudioManager from Settings
    static var shared: AppDelegate?

    // Method to access AudioManager for VAD updates
    func getAudioManager() -> AudioManager? {
        return audioManager
    }

    // Status bar icon: a single Omri glyph, tinted by state.
    private let defaultIcon = "SVG Icon"

    // Brand colors for status-bar state tinting (asset catalog tokens).
    private let brandPrimary = NSColor(named: "BrandPrimary") ?? .controlAccentColor
    private let brandSecondary = NSColor(named: "BrandSecondary") ?? .controlAccentColor
    private let brandError = NSColor(named: "BrandError") ?? .systemRed

    // Helper function to create properly sized menu bar icons
    private func createMenuBarIcon(named iconName: String) -> NSImage? {
        if let image = NSImage(named: iconName) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        return nil
    }

    // The Omri glyph tinted with a state color (non-template, so the tint shows).
    private func tintedStatusIcon(color: NSColor) -> NSImage? {
        createTintedImage(from: createMenuBarIcon(named: defaultIcon), color: color)
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set shared reference for accessing AudioManager from Settings
        AppDelegate.shared = self

        // Register custom fonts (Hack Nerd Font for terminal)
        #if os(macOS) && SSH_TERMINAL
        FontRegistration.registerHackNerdFont()
        #endif

        // Request notification permissions for UserNotifications framework
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.log("Failed to request notification permissions: \(error.localizedDescription)", context: "App", level: .error)
            }
        }

        // Initialize services with API key from settings
        initializeServices()

        setupStatusItem()
        setupPermissions()

        // Run without a dock icon
        NSApp.setActivationPolicy(.accessory)

        // Listen for API and provider changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApiKeyChange),
            name: .apiKeyChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProviderChange),
            name: .transcriptionApiChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransformProviderChange),
            name: .transformationApiChanged,
            object: nil
        )
    }

    private func initializeServices() {
        // Initialize transcription services
        let transcriptionProvider = Settings.shared.transcriptionProvider
        let transcriptionApiKey = Settings.shared.apiKey(for: transcriptionProvider)

        // Initialize transformation services
        let transformProvider = Settings.shared.transformationProvider
        // Use the API key associated with the selected *transformation* provider
        let transformApiKey = Settings.shared.apiKey(for: transformProvider)

        var transcriptionService: TranscriptionService? = nil

        // Initialize transcription service
        if transcriptionProvider.isOnDevice {
            // On-device provider - no API key required
            Logger.log("Using Apple (On-Device) transcription - no API key required", context: "App", level: .info)
            transcriptionService = nil
        } else if let transcriptionApiKey = transcriptionApiKey, !transcriptionApiKey.isEmpty {
            // Cloud providers - require API key
            Logger.log("Initializing \(transcriptionProvider.rawValue) transcription services", context: "App", level: .info)

            switch transcriptionProvider {
            case .groq:
                transcriptionService = GroqTranscriptionService(apiKey: transcriptionApiKey)
            case .groqTranslations:
                transcriptionService = GroqTranscriptionService(
                    apiKey: transcriptionApiKey,
                    translation: true
                )
            case .openai:
                transcriptionService = OpenAITranscriptionService(apiKey: transcriptionApiKey)
            case .custom:
                let customURL = Settings.shared.customTranscriptionBaseURL
                transcriptionService = CustomTranscriptionService(apiKey: transcriptionApiKey, baseURL: customURL)
            case .apple, .parakeet:
                break // Handled above - on-device providers
            }
        } else {
            Logger.log("No API key found for \(transcriptionProvider.rawValue), transcription services will not be initialized.", context: "App", level: .warning)
        }

        // Initialize transformation service
        if transformProvider.requiresApiKey && (transformApiKey == nil || transformApiKey!.isEmpty) {
            Logger.log("No API key found for \(transformProvider.rawValue), transformation services will not be initialized.", context: "App", level: .warning)
            transformationService = nil
        } else {
            Logger.log("Initializing \(transformProvider.rawValue) transformation services", context: "App", level: .info)
            
            switch transformProvider {
            case .groq:
                transformationService = UnifiedTransformationService.groq(apiKey: transformApiKey!)
            case .openai:
                transformationService = UnifiedTransformationService.openAI(apiKey: transformApiKey!)
            case .custom:
                let customURL = Settings.shared.customTransformationBaseURL
                transformationService = UnifiedTransformationService.custom(apiKey: transformApiKey ?? "", baseURL: customURL)
            }
        }

        // Initialize PasteManager and pass services + delegate
        pasteManager = PasteManager(
            transformationService: transformationService,
            delegate: self  // Set AppDelegate as the delegate
        )

        // Initialize AudioManager, passing transcription service and paste manager
        // NOTE: This assumes AudioManager's init is updated to accept PasteManager
        //       or that AudioManager internally uses a shared PasteManager instance.
        //       PasteManager directly, its init signature must change.
        // Update: Passing the pasteManager instance now.
        audioManager = AudioManager(
            transcriptionService: transcriptionService,
            pasteManager: pasteManager  // Pass the instance with the delegate
        )
        audioManager.delegate = self
    }

    @objc private func handleApiKeyChange(_ notification: Notification) {
        Logger.log("API key changed, reinitializing services", context: "App", level: .info)
        initializeServices()
    }

    @objc private func handleProviderChange(_ notification: Notification) {
        Logger.log("Transcription provider changed, reinitializing services", context: "App", level: .info)
        initializeServices()
    }

    @objc private func handleTransformProviderChange(_ notification: Notification) {
        Logger.log("Transformation provider changed, reinitializing services", context: "App", level: .info)
        initializeServices()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use custom SVG icon for idle state with proper menu bar sizing and template behavior
            button.image = createMenuBarIcon(named: defaultIcon)
            button.toolTip = "Omri"
        }

        let menu = NSMenu()

        // Download status item (initially hidden)
        let downloadItem = NSMenuItem(title: "Downloading models...", action: nil, keyEquivalent: "")
        downloadItem.isEnabled = false  // Non-interactive status display
        downloadItem.isHidden = true
        downloadStatusMenuItem = downloadItem
        menu.addItem(downloadItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        #if SSH_TERMINAL
        menu.addItem(
            NSMenuItem(title: "SSH Connections...", action: #selector(showSSHConnections), keyEquivalent: ""))
        #endif
        menu.addItem(
            NSMenuItem(
                title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "p")
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        settingsWindowController?.window?.center()
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    #if SSH_TERMINAL
    @objc private func showSSHConnections() {
        if sshConnectionsWindowController == nil {
            sshConnectionsWindowController = SSHConnectionsWindowController()
        }

        sshConnectionsWindowController?.window?.center()
        sshConnectionsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    #endif

    private func setupPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                Task { @MainActor in
                    self.showPermissionAlert(for: "Microphone")
                }
            }
        }

        // Also check accessibility permissions
        let options =
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessibilityEnabled {
            Task { @MainActor in
                self.showPermissionAlert(for: "Accessibility")
            }
        }
        // as Groq transcription uses the API and only microphone access is required locally.
    }

    @objc private func checkPermissions() {
        let alert = NSAlert()
        alert.messageText = "Checking Permissions"
        alert.informativeText =
            "Omri needs microphone and accessibility permissions to function properly."

        let micStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == .authorized
        let accessibilityStatus = AXIsProcessTrustedWithOptions(nil as CFDictionary?)

        if micStatus && accessibilityStatus {
            alert.messageText = "All Permissions Granted"
            alert.informativeText = "Omri has all required permissions."
        } else {
            alert.messageText = "Missing Permissions"
            alert.informativeText = """
                Omri requires the following permissions:

                Microphone: \(micStatus ? "Granted" : "Missing")
                Accessibility: \(accessibilityStatus ? "Granted" : "Missing")

                Please grant the missing permissions in System Settings.
                """

            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                openSystemSettings()
            }
            return
        }

        alert.runModal()
    }

    private func createTintedImage(from image: NSImage?, color: NSColor) -> NSImage? {
        guard let image = image else { return nil }
        
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        
        // Draw the original image
        image.draw(in: NSRect(origin: .zero, size: image.size))
        
        // Apply color tint
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        
        tintedImage.unlockFocus()
        tintedImage.isTemplate = false
        
        return tintedImage
    }
    
    private func openSystemSettings() {
        // For Microphone
        if let micURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        {
            NSWorkspace.shared.open(micURL)
        }

        // For Accessibility
        if let accessibilityURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(accessibilityURL)
        }
    }

    private func showPermissionAlert(for permission: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "\(permission) Access Required"
            alert.informativeText =
                "Please enable \(permission) access in System Settings to use Omri."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AudioManagerDelegate

extension AppDelegate: AudioManagerDelegate {
    // Since AppDelegate is @MainActor, these methods are already on the main actor.
    func audioManagerDidStartRecording() {
        // Recording state: primary glyph.
        self.statusItem.button?.image = tintedStatusIcon(color: brandPrimary)
    }

    func audioManagerDidStopRecording() {
        // Return to standard macOS template icon
        self.statusItem.button?.image = createMenuBarIcon(named: defaultIcon)
    }

    func audioManagerWillStartNetworkProcessing() {
        // Processing state: secondary glyph.
        self.statusItem.button?.image = tintedStatusIcon(color: brandSecondary)
    }

    func audioManager(didReceiveError error: Error) {
        // Return to standard macOS template icon on error
        self.statusItem.button?.image = createMenuBarIcon(named: defaultIcon)

        // For better UX, use non-intrusive error handling instead of modal alerts
        let errorMessage: String
        if let localizedError = error as? LocalizedError,
            let errorDescription = localizedError.errorDescription
        {
            errorMessage = errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Only show modal alerts for critical errors that require immediate attention
        if let audioError = error as? AudioManagerError {
            switch audioError {
            case .microphoneAccessDenied:
                // This is critical - user needs to grant permission
                showCriticalAlert(title: "Microphone Access Required", message: errorMessage)
            case .transcriptionServiceMissing:
                // This is critical - app won't work without service
                showCriticalAlert(title: "Service Configuration Required", message: errorMessage)
            default:
                // For recording failures, conversion errors, etc., use non-intrusive feedback
                showNonIntrusiveError(message: errorMessage)
            }
        } else {
            // For other errors, use non-intrusive feedback
            showNonIntrusiveError(message: errorMessage)
        }
    }
    
    private func showCriticalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showNonIntrusiveError(message: String) {
        // Use modern UserNotifications framework for non-intrusive feedback
        let content = UNMutableNotificationContent()
        content.title = "Omri"
        content.body = message
        content.sound = nil // Silent notification to avoid interruption

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.log("Failed to show notification: \(error.localizedDescription)", context: "App", level: .error)
            }
        }

        // Briefly tint the status bar glyph red to indicate error, then revert
        self.statusItem.button?.image = tintedStatusIcon(color: brandError)

        // Revert to normal icon after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.statusItem.button?.image = self.createMenuBarIcon(named: self.defaultIcon)
        }
    }
}

// MARK: - PasteManagerDelegate

extension AppDelegate: PasteManagerDelegate {
    func pasteManagerWillStartProcessing() {
        // No longer setting icon here, AudioManagerDelegate handles start
        Logger.log("pasteManagerWillStartProcessing - (Icon setting moved)", context: "App", level: .debug)
    }

    func pasteManagerWillStartTransformation() {
        // AI transformation state: secondary glyph.
        self.statusItem.button?.image = tintedStatusIcon(color: brandSecondary)
    }

    func pasteManagerDidFinishProcessing() {
        // Success state: secondary glyph (briefly), then back to idle.
        self.statusItem.button?.image = tintedStatusIcon(color: brandSecondary)

        // Reset to normal template icon after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusItem.button?.image = self.createMenuBarIcon(named: self.defaultIcon)
        }
    }
}

// MARK: - Download Status
extension AppDelegate {
    func showDownloadStatus(message: String) {
        downloadStatusMenuItem?.title = message
        downloadStatusMenuItem?.isHidden = false
    }

    func hideDownloadStatus() {
        downloadStatusMenuItem?.isHidden = true
    }
}
