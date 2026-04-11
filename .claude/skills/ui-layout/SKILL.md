---
name: ui-layout
description: SwiftUI layout patterns and pitfalls for sshhh. Use when modifying MainWindowController, MainContentView, sidebar, or any SwiftUI views hosted in NSHostingView.
---

# UI Layout — SwiftUI in NSHostingView

## Pitfalls

- **Never use `NavigationSplitView`** when hosted inside an `NSHostingView` in a manually-created `NSWindow`. It always injects a sidebar toggle toolbar button that cannot be removed — `.toolbar(removing: .sidebarToggle)` and `window.toolbar = nil` both fail silently. Use a plain `HStack` + `Divider` with a fixed-width `List(.sidebar)` instead.

## Current Layout (MainContentView)

The main window uses `HStack` with a 180pt sidebar `List` and a `Divider`:

```swift
HStack(spacing: 0) {
    SidebarView(selection: $navigationState.selection)
        .frame(width: 180)
    Divider()
    Group { /* detail view */ }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

Navigation state is driven by `NavigationState` (ObservableObject) so AppDelegate can programmatically switch tabs (e.g. menubar "History" item).
