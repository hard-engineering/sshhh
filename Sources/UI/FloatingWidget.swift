import Cocoa
import SwiftUI

/// Floating widget that shows recording/processing state
class FloatingWidget: WidgetDisplaying {

    /// Legacy State enum - maps to WidgetState
    typealias State = WidgetState
    
    private var window: NSWindow?
    private var hostingView: NSHostingView<WidgetView>?
    private var currentState: State = .recording
    
    init() {
        setupWindow()
    }
    
    private func setupWindow() {
        let contentView = WidgetView(state: .constant(.recording))
        hostingView = NSHostingView(rootView: contentView)
        
        // Use a larger window size than the content to allow for shadows without clipping
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window?.hasShadow = false
        window?.ignoresMouseEvents = true // Don't block interactions
        window?.contentView = hostingView
        
        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 50 // Half of 100
            let y = screenFrame.maxY - 100 - 20 // 100 height + 20 margin
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    func show(state: State) {
        currentState = state
        
        let contentView = WidgetView(state: .constant(state))
        hostingView?.rootView = contentView
        
        window?.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
}

// MARK: - SwiftUI Widget View

struct WidgetView: View {
    @Binding var state: WidgetState
    
    var body: some View {
        ZStack {
            // Main Content
            ZStack {
                if state == .recording {
                    AudioPlayingIndicatorRings(size: 32, color: .red)
                } else if state == .processing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 32, height: 32)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
            )
        }
        .frame(width: 100, height: 100) // Match window size
    }
}

// MARK: - Animations

struct AudioPlayingIndicatorRings: View {
    @State private var isAnimating = false
    
    var size: CGFloat = 32
    var color: Color = .blue
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(isAnimating ? 1.0 + CGFloat(index) * 0.4 : 0.4)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }
            
            // Center dot (Mic)
            Image(systemName: "mic.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
        .onAppear {
            isAnimating = true
        }
    }
}


