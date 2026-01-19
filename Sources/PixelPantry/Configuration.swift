import Foundation

/// Configuration for the PixelPantry SDK
public struct Configuration: Sendable {
    /// The app's bundle identifier registered with PixelPantry
    public let bundleId: String

    /// Public API key (starts with "pk_")
    public let appKey: String

    /// Private secret for request signing (starts with "sk_")
    public let appSecret: String

    /// Base URL for the PixelPantry API
    public let serverURL: URL

    /// Default PixelPantry server URL
    public static let defaultServerURL = URL(string: "https://pixelpantry.app")!

    /// Initialize a new configuration
    /// - Parameters:
    ///   - bundleId: The app's bundle identifier (e.g., "com.example.myapp")
    ///   - appKey: Public API key from PixelPantry
    ///   - appSecret: Private secret for signing requests
    ///   - serverURL: Custom server URL (defaults to production)
    public init(
        bundleId: String,
        appKey: String,
        appSecret: String,
        serverURL: URL = Configuration.defaultServerURL
    ) {
        self.bundleId = bundleId
        self.appKey = appKey
        self.appSecret = appSecret
        self.serverURL = serverURL
    }
}

/// Internal configuration storage
actor ConfigurationStorage {
    static let shared = ConfigurationStorage()

    private var configuration: Configuration?

    private init() {}

    func set(_ config: Configuration) {
        self.configuration = config
    }

    func get() -> Configuration? {
        return configuration
    }

    func require() throws -> Configuration {
        guard let config = configuration else {
            throw PPError.notConfigured
        }
        return config
    }
}
