import SwiftUI
import AppKit

/// SwiftUI view for displaying update information and controls
public struct PixelPantryUpdateView: View {
    @StateObject private var viewModel = UpdateViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // App icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            // Title based on state
            Group {
                switch viewModel.state {
                case .checking:
                    Text("Checking for Updates...")
                        .font(.headline)
                case .upToDate:
                    Text("You're Up to Date")
                        .font(.headline)
                case .updateAvailable:
                    Text("Update Available")
                        .font(.headline)
                case .downloading:
                    Text("Downloading Update...")
                        .font(.headline)
                case .installing:
                    Text("Installing Update...")
                        .font(.headline)
                case .error:
                    Text("Update Error")
                        .font(.headline)
                        .foregroundColor(.red)
                case .idle:
                    Text("Software Update")
                        .font(.headline)
                }
            }

            // Content based on state
            Group {
                switch viewModel.state {
                case .checking:
                    ProgressView()
                        .scaleEffect(0.8)

                case .upToDate:
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("Version \(PixelPantry.currentVersion)")
                            .foregroundColor(.secondary)
                    }

                case .updateAvailable:
                    if let update = viewModel.update {
                        updateDetails(update)
                    }

                case .downloading:
                    downloadProgress

                case .installing:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Installing... The app will restart automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                case .error(let message):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                case .idle:
                    EmptyView()
                }
            }

            Spacer()

            // Buttons
            buttonRow
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 300)
        .task {
            await viewModel.checkForUpdates()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func updateDetails(_ update: Update) -> some View {
        VStack(spacing: 16) {
            // Version info
            HStack {
                Text("Current:")
                    .foregroundColor(.secondary)
                Text(PixelPantry.currentVersion)

                Spacer()

                Text("New:")
                    .foregroundColor(.secondary)
                Text(update.version)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            // Release notes
            if !update.releaseNotes.isEmpty {
                ScrollView {
                    Text(update.releaseNotes)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
            }

            // File size
            HStack {
                Text("Download size:")
                    .foregroundColor(.secondary)
                Text(update.fileSizeFormatted)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var downloadProgress: some View {
        VStack(spacing: 12) {
            ProgressView(value: viewModel.downloadProgress)
                .progressViewStyle(.linear)

            Text("\(Int(viewModel.downloadProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var buttonRow: some View {
        HStack {
            switch viewModel.state {
            case .checking, .downloading, .installing:
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

            case .upToDate, .error:
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)

            case .updateAvailable:
                Button("Later") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Update Now") {
                    Task {
                        await viewModel.downloadAndInstall()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

            case .idle:
                Spacer()
                Button("Check for Updates") {
                    Task {
                        await viewModel.checkForUpdates()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - View Modifier

/// Modifier that automatically checks for updates and shows UI when available
public struct PixelPantryUpdateModifier: ViewModifier {
    @State private var showingUpdate = false
    @State private var update: Update?

    public init() {}

    public func body(content: Content) -> some View {
        content
            .task {
                let result = await PixelPantry.checkForUpdates()
                if case .available(let foundUpdate) = result {
                    update = foundUpdate
                    showingUpdate = true
                }
            }
            .sheet(isPresented: $showingUpdate) {
                PixelPantryUpdateView()
            }
    }
}

public extension View {
    /// Add automatic update checking to this view
    ///
    /// When the view appears, it will check for updates and show
    /// the update sheet if one is available.
    func pixelPantryUpdates() -> some View {
        modifier(PixelPantryUpdateModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct PixelPantryUpdateView_Previews: PreviewProvider {
    static var previews: some View {
        PixelPantryUpdateView()
    }
}
#endif
