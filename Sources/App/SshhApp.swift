import SwiftUI

@main
struct SshhApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we're a menubar-only app
        Settings {
            EmptyView()
        }
    }
}
