# Getting Started with PixelPantry

Learn how to add automatic updates to your macOS application.

## Overview

This guide walks you through integrating PixelPantry into your macOS app to enable automatic update checking, downloading, and installation.

## Add the Package

Add PixelPantry to your project using Swift Package Manager:

**In Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/pixel-pantry/PixelPantry.git", from: "1.0.0")
]
```

**In Xcode:**

1. Go to File > Add Package Dependencies
2. Enter `https://github.com/pixel-pantry/PixelPantry.git`
3. Select version 1.0.0 or later

## Configure the SDK

Initialize PixelPantry with your app's credentials. Do this early in your app's lifecycle:

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

> Important: Keep your `appSecret` secure. Don't commit it to public repositories.

## Check for Updates on Launch

Add update checking to your main view:

```swift
struct ContentView: View {
    @State private var showingUpdateSheet = false

    var body: some View {
        VStack {
            Text("My App")
        }
        .task {
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

## Add a Manual Check Option

Let users check for updates from a menu:

```swift
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Task {
                        await PixelPantry.showUpdateWindowIfAvailable()
                    }
                }
            }
        }
    }
}
```

## Handle Updates Manually

For complete control over the update process:

```swift
func checkAndInstallUpdate() async {
    let result = await PixelPantry.checkForUpdates()

    guard case .available(let update) = result else {
        print("No update available")
        return
    }

    do {
        // Download with progress
        let fileURL = try await PixelPantry.downloadUpdate(update) { progress in
            print("Downloading: \(Int(progress * 100))%")
        }

        // Install and relaunch
        try await PixelPantry.installUpdate(from: fileURL)
    } catch {
        print("Update failed: \(error)")
    }
}
```

## Next Steps

- Learn about the ``Update`` model for accessing release notes and metadata
- Handle errors gracefully with ``PPError``
- Customize the update UI by building your own view using the SDK methods
