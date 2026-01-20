# PixelPantry Swift SDK

A Swift package for integrating automatic app updates into macOS applications via the PixelPantry distribution platform.

## Requirements

- macOS 13.0+
- Swift 5.9+
- **Non-sandboxed app** (required for automatic installation)

> **Important:** Your app must have `com.apple.security.app-sandbox` set to `false` in your entitlements file and `ENABLE_APP_SANDBOX = NO` in your Xcode build settings for automatic updates to work. Sandboxed apps cannot replace themselves or request admin privileges.

## Installation

### Swift Package Manager

Add PixelPantry to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/pixel-pantry/PixelPantry.git", from: "1.0.9")
]
```

Or in Xcode: **File > Add Package Dependencies** > Enter the repository URL:
```
https://github.com/pixel-pantry/PixelPantry.git
```

## Quick Start

### 1. Get Your Credentials

1. Register your app at [PixelPantry Developer Portal](https://pixelpantry.app)
2. Get your **App Key** (starts with `pk_`) and **App Secret** (starts with `sk_`)

### 2. Configure PixelPantry

Configure the SDK early in your app's lifecycle (e.g., in your AppDelegate):

```swift
import PixelPantry

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PixelPantry.configure(
            bundleId: "com.yourcompany.yourapp",
            appKey: "pk_your_app_key",
            appSecret: "sk_your_app_secret"
        )
    }
}
```

### 3. Check for Updates on Launch

The easiest way to add update checking:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    PixelPantry.configure(
        bundleId: "com.yourcompany.yourapp",
        appKey: "pk_your_app_key",
        appSecret: "sk_your_app_secret"
    )

    // Check for updates after a short delay
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        await PixelPantry.checkForUpdatesOnLaunch()
    }
}
```

This will:
1. Silently check for updates
2. Show a native alert if an update is available
3. If the user clicks "Install Now", show the update window with progress
4. Download, install, and relaunch the app automatically

## Update Methods

### Recommended: Alert + Update Window

```swift
// Shows alert first, then update window if user accepts
await PixelPantry.checkForUpdatesOnLaunch(showAlertFirst: true)
```

### Direct Update Window

```swift
// Shows update window directly (no confirmation alert)
await PixelPantry.checkForUpdatesOnLaunch(showAlertFirst: false)

// Or manually for a specific update
await PixelPantry.showUpdateWindowIfAvailable()
```

### Check and Prompt

```swift
// Returns true if update was found and user clicked "Install Now"
let userAccepted = await PixelPantry.checkAndPromptForUpdate()
```

### Manual Control

For complete control over the update process:

```swift
// 1. Check for updates
let result = await PixelPantry.checkForUpdates()

switch result {
case .available(let update):
    print("Update available: \(update.version)")
    print("Release notes: \(update.releaseNotes)")

    // 2. Download with progress tracking
    let downloadResult = await PixelPantry.downloadUpdate(update) { progress in
        print("Download progress: \(Int(progress * 100))%")
    }

    switch downloadResult {
    case .success(let fileURL):
        // 3. Install and relaunch
        let installResult = await PixelPantry.installUpdate(from: fileURL)
        if case .failure(let error) = installResult {
            print("Installation failed: \(error)")
        }
    case .failure(let error):
        print("Download failed: \(error)")
    }

case .upToDate:
    print("Already on latest version")

case .error(let error):
    print("Error checking for updates: \(error)")
}
```

### Combined Download + Install

```swift
if case .available(let update) = await PixelPantry.checkForUpdates() {
    let result = await PixelPantry.downloadAndInstall(update) { progress in
        print("Download: \(Int(progress * 100))%")
    }

    switch result {
    case .success:
        print("Update installed, app will relaunch")
    case .failure(let error):
        print("Update failed: \(error)")
    }
}
```

## Built-in UI Components

### SwiftUI Update View

```swift
import PixelPantry
import SwiftUI

struct SettingsView: View {
    @State private var showingUpdate = false

    var body: some View {
        VStack {
            Button("Check for Updates") {
                showingUpdate = true
            }
        }
        .sheet(isPresented: $showingUpdate) {
            PixelPantryUpdateView()
        }
    }
}
```

### AppKit Update Window

```swift
// Show window if update is available
await PixelPantry.showUpdateWindowIfAvailable()

// Or show for a specific update
if case .available(let update) = await PixelPantry.checkForUpdates() {
    await MainActor.run {
        PixelPantry.showUpdateWindow(for: update)
    }
}
```

## Disabling Sandbox (Required)

For automatic updates to work, you must disable the App Sandbox:

### 1. Update Entitlements File

In your `.entitlements` file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 2. Update Build Settings

In Xcode, go to your target's **Build Settings** and set:
- `ENABLE_APP_SANDBOX` = `NO`

> **Note:** If you need to distribute on the Mac App Store (which requires sandboxing), you cannot use automatic updates. The SDK will fall back to copying the update to the user's Desktop/Downloads folder with manual installation instructions.

## How Installation Works

1. **Direct Install** - First tries to copy the new app directly (works if you have write permission to the install location)
2. **Admin Privileges** - If direct install fails, shows macOS password dialog to request admin privileges
3. **Manual Fallback** - If both fail (e.g., sandboxed app), copies to Desktop and shows instructions

## Error Handling

```swift
let result = await PixelPantry.checkForUpdates()

if case .error(let error) = result {
    switch error {
    case .notConfigured:
        print("Call PixelPantry.configure() first")
    case .networkError(let message):
        print("Network error: \(message)")
    case .invalidResponse(let statusCode, let message):
        print("Server error \(statusCode ?? 0): \(message)")
    case .downloadFailed(let reason):
        print("Download failed: \(reason)")
    case .verificationFailed:
        print("File hash verification failed")
    case .installationFailed(let reason):
        print("Installation failed: \(reason)")
    }
}
```

## Supported Archive Types

The installer automatically handles:
- `.zip` - ZIP archives (extracted using `ditto`)
- `.dmg` - Disk images (mounted, app extracted, unmounted)

## Security

- All API requests are signed using HMAC-SHA256 with your app secret
- Downloaded files are verified against SHA256 checksums (when provided by server)
- Existing apps are moved to Trash before replacement (recoverable)
- Admin password is requested via macOS Security framework (never stored)

## Version Information

```swift
// Get current app version
let currentVersion = PixelPantry.currentVersion  // e.g., "1.0.0"

// Get current macOS version
let macOSVersion = PixelPantry.currentMacOSVersion  // e.g., "14.0"

// Check if SDK is configured
let isReady = PixelPantry.isConfigured  // true/false
```

## Complete Example

```swift
import SwiftUI
import PixelPantry

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure PixelPantry
        PixelPantry.configure(
            bundleId: "com.example.myapp",
            appKey: "pk_abc123",
            appSecret: "sk_xyz789"
        )

        // Check for updates on launch
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await PixelPantry.checkForUpdatesOnLaunch()
        }
    }
}
```

## Troubleshooting

### "Installation cancelled by user"
The user clicked Cancel on the password dialog.

### No password dialog appears
- Ensure your app is not sandboxed (check both entitlements and build settings)
- Clean build folder (Product > Clean Build Folder) and rebuild

### "Permission denied" errors
- Make sure `ENABLE_APP_SANDBOX = NO` in build settings
- Rebuild the app after changing entitlements

### Update downloads but doesn't install
Check the Xcode console for `[PixelPantry]` log messages to see where it's failing.

## License

MIT License - see LICENSE file for details.
