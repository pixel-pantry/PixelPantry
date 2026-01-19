# PixelPantry

A Swift package for integrating automatic app updates into macOS applications via the PixelPantry distribution platform.

## Requirements

- macOS 13.0+
- Swift 5.9+

## Installation

Add PixelPantry to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/pixel-pantry/PixelPantry.git", from: "1.0.0")
]
```

Or in Xcode: File > Add Package Dependencies > Enter the repository URL.

## Quick Start

### 1. Configure PixelPantry

Configure the SDK early in your app's lifecycle (e.g., in your App struct or AppDelegate):

```swift
import PixelPantry

@main
struct MyApp: App {
    init() {
        PixelPantry.configure(
            bundleId: "com.yourcompany.yourapp",
            appSecret: "your_app_secret"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Check for Updates

#### Using the Built-in UI (Recommended)

```swift
import PixelPantry
import SwiftUI

struct ContentView: View {
    @State private var showingUpdateSheet = false

    var body: some View {
        VStack {
            // Your app content
        }
        .task {
            // Check on launch
            let result = await PixelPantry.checkForUpdates()
            if case .available = result {
                showingUpdateSheet = true
            }
        }
        .sheet(isPresented: $showingUpdateSheet) {
            PixelPantryUpdateView()
        }
    }
}
```

#### Using the AppKit Window

```swift
// Shows a native window if an update is available
await PixelPantry.showUpdateWindowIfAvailable()
```

### 3. Manual Update Flow

For complete control over the update process:

```swift
// Check for updates
let result = await PixelPantry.checkForUpdates()

switch result {
case .available(let update):
    print("Update available: \(update.version)")
    print("Release notes: \(update.releaseNotes ?? "None")")

    // Download with progress tracking
    let fileURL = try await PixelPantry.downloadUpdate(update) { progress in
        print("Download progress: \(Int(progress * 100))%")
    }

    // Install and relaunch
    try await PixelPantry.installUpdate(from: fileURL)

case .noUpdate:
    print("Already on latest version")

case .error(let error):
    print("Error checking for updates: \(error)")
}
```

## Configuration Options

```swift
PixelPantry.configure(
    bundleId: "com.yourcompany.yourapp",
    appSecret: "your_app_secret",
    baseURL: "https://custom-server.example.com"  // Optional: custom server URL
)
```

## Update Model

The `Update` struct contains information about an available update:

```swift
public struct Update {
    public let version: String           // e.g., "2.0.0"
    public let releaseNotes: String?     // Markdown release notes
    public let downloadURL: URL          // Direct download URL
    public let sha256: String?           // SHA256 hash for verification
    public let fileSize: Int64?          // File size in bytes
    public let minOSVersion: String?     // Minimum macOS version required
    public let isCritical: Bool          // Whether this is a critical update
}
```

## Error Handling

PixelPantry uses the `PPError` enum for error handling:

```swift
do {
    let result = await PixelPantry.checkForUpdates()
    // ...
} catch let error as PPError {
    switch error {
    case .notConfigured:
        print("Call PixelPantry.configure() first")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    case .invalidResponse(let statusCode, let message):
        print("Server error \(statusCode): \(message)")
    case .downloadFailed(let reason):
        print("Download failed: \(reason)")
    case .verificationFailed:
        print("File hash verification failed")
    case .installationFailed(let reason):
        print("Installation failed: \(reason)")
    default:
        print("Error: \(error)")
    }
}
```

## Supported File Types

The installer supports:
- `.dmg` - Disk images (mounted and extracted automatically)
- `.zip` - ZIP archives (extracted automatically)

## Security

- All API requests are signed using HMAC-SHA256
- Downloaded files are verified against SHA256 checksums (when provided)
- Existing apps are moved to Trash before replacement (recoverable)

## License

MIT License - see LICENSE file for details.
