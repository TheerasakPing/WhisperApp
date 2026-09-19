import Foundation
import AppKit
import Carbon.HIToolbox

final class CommandHotkeyManager {
    static let shared = CommandHotkeyManager()

    private let defaultsKey = "command.hotkey.config"
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var modifierOnlyDown = false
    private var config: HotkeyConfig

    var onInvoke: (() -> Void)?

    static let defaultConfig = HotkeyConfig(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt(
            NSEvent.ModifierFlags.control.rawValue |
            NSEvent.ModifierFlags.option.rawValue
        ),
        isHoldMode: false,
        isModifierOnly: false
    )

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            config = saved
        } else {
            config = Self.defaultConfig
        }
    }

    var currentConfig: HotkeyConfig { config }

    func updateConfig(_ newConfig: HotkeyConfig) {
        var normalized = newConfig
        normalized.isHoldMode = false
        config = normalized
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        restartMonitors()
    }

    func reset() {
        updateConfig(Self.defaultConfig)
    }

    func start() {
        restartMonitors()
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        modifierOnlyDown = false
    }

    private func restartMonitors() {
        stop()
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        if config.isModifierOnly {
            handleModifier(event)
            return
        }

        guard event.type == .keyDown, !event.isARepeat else { return }
        let eventFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredFlags = NSEvent.ModifierFlags(rawValue: config.modifiers)
            .intersection(.deviceIndependentFlagsMask)
        guard UInt32(event.keyCode) == config.keyCode,
              eventFlags == requiredFlags else { return }
        onInvoke?()
    }

    private func handleModifier(_ event: NSEvent) {
        guard event.type == .flagsChanged else { return }
        let required = NSEvent.ModifierFlags(rawValue: config.modifiers)
            .intersection(.deviceIndependentFlagsMask)
        let down = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(required)

        if down && !modifierOnlyDown {
            modifierOnlyDown = true
            onInvoke?()
        } else if !down {
            modifierOnlyDown = false
        }
    }
}
