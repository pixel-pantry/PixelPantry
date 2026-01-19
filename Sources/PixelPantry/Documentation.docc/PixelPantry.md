# ``PixelPantry``

Integrate automatic app updates into your macOS application.

## Overview

PixelPantry provides a complete solution for checking, downloading, and installing app updates in macOS applications. It handles all the complexity of update management including cryptographic request signing, download verification, and seamless installation.

### Quick Start

Configure PixelPantry early in your app's lifecycle:

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

Then check for updates:

```swift
let result = await PixelPantry.checkForUpdates()

switch result {
case .available(let update):
    print("New version available: \(update.version)")
case .noUpdate:
    print("You're on the latest version")
case .error(let error):
    print("Error: \(error)")
}
```

### Using the Built-in UI

PixelPantry includes a ready-to-use SwiftUI view:

```swift
.sheet(isPresented: $showingUpdate) {
    PixelPantryUpdateView()
}
```

Or use the AppKit window:

```swift
await PixelPantry.showUpdateWindowIfAvailable()
```

## Topics

### Essentials

- ``PixelPantry``
- ``Configuration``
- ``Update``

### Checking for Updates

- ``PixelPantry/checkForUpdates()``
- ``CheckResult``

### Downloading and Installing

- ``PixelPantry/downloadUpdate(_:progress:)``
- ``PixelPantry/installUpdate(from:)``

### User Interface

- ``PixelPantryUpdateView``
- ``PixelPantry/showUpdateWindowIfAvailable()``
- ``PixelPantry/showUpdateWindow(for:)``

### Error Handling

- ``PPError``
