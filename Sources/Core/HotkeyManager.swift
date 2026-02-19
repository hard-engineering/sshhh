import Cocoa
import Carbon

/// Monitors global hotkey (Option key) for push-to-talk functionality
class HotkeyManager {

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void

    private var isOptionPressed = false
    /// Tracks if Option is being used as part of a keyboard shortcut
    private var isShortcutCombo = false
    /// Tracks if recording has been activated for this Option press
    private var recordingActivated = false
    /// Work item for delayed activation
    private var activationWorkItem: DispatchWorkItem?

    /// Delay before activating recording (filters accidental taps)
    let activationDelay: TimeInterval

    init(
        activationDelay: TimeInterval = 0.15,
        onKeyDown: @escaping () -> Void,
        onKeyUp: @escaping () -> Void
    ) {
        self.activationDelay = activationDelay
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
    }
    
    deinit {
        stop()
    }
    
    func start() {
        // Check accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("⚠️ Accessibility permission required")
            return
        }
        
        // Create event tap for modifier key changes AND regular key presses
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)
        
        // Store self reference for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleEvent(event)
                
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        
        guard let eventTap = eventTap else {
            print("❌ Failed to create event tap")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("✅ Hotkey manager started (Option key)")
        }
    }
    
    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
    }
    
    private func handleEvent(_ event: CGEvent) {
        let eventType = event.type
        let flags = event.flags
        let optionPressed = flags.contains(.maskAlternate)

        // Handle regular key presses while Option is held
        if eventType == .keyDown && isOptionPressed {
            // A regular key was pressed while Option is held - this is a keyboard shortcut
            if !isShortcutCombo {
                print("🔑 Shortcut combo detected (Option + key)")
                isShortcutCombo = true

                // Cancel pending activation if still waiting
                activationWorkItem?.cancel()
                activationWorkItem = nil

                // If recording was already activated, stop it
                if recordingActivated {
                    print("🔑 Stopping recording due to shortcut combo")
                    recordingActivated = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onKeyUp()
                    }
                }
            }
            return
        }

        // Handle modifier key changes (Option press/release)
        guard eventType == .flagsChanged else { return }

        if optionPressed && !isOptionPressed {
            // Option key just pressed
            print("🔑 Option Key Down detected")
            isOptionPressed = true
            isShortcutCombo = false
            recordingActivated = false

            // Check if other modifier keys are held (Cmd, Ctrl, Shift)
            let otherModifiersHeld = flags.contains(.maskCommand) ||
                                     flags.contains(.maskControl) ||
                                     flags.contains(.maskShift)

            if otherModifiersHeld {
                // Option pressed with other modifiers - likely a shortcut
                print("🔑 Option pressed with other modifiers, ignoring")
                isShortcutCombo = true
            } else {
                // Option pressed alone - schedule recording activation after delay
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self,
                          self.isOptionPressed,
                          !self.isShortcutCombo else {
                        return
                    }
                    print("🔑 Activation delay passed, starting recording")
                    self.recordingActivated = true
                    self.onKeyDown()
                }
                activationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay, execute: workItem)
            }
        } else if !optionPressed && isOptionPressed {
            // Option key released
            print("🔑 Option Key Up detected")
            isOptionPressed = false

            // Cancel pending activation if still waiting
            activationWorkItem?.cancel()
            activationWorkItem = nil

            // Only call onKeyUp if recording was actually activated
            if recordingActivated {
                recordingActivated = false
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyUp()
                }
            }

            // Reset shortcut combo flag
            isShortcutCombo = false
        }
    }
}
