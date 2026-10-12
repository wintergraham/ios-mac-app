// Copyright (c) 2026. Licensed under GPL-3.0-or-later.

import Foundation

public struct DomainInclusionSettings: Codable, Equatable, Sendable {
    public static let storageKey = "DomainInclusionSettings"
    public static let suggestedDomains = "chatgpt.com\napi.openai.com\nauth.openai.com\ncdn.oaistatic.com\nfiles.oaiusercontent.com"

    public var enabled: Bool
    public var domains: [String]

    public init(enabled: Bool = false, domains: [String] = []) {
        self.enabled = enabled
        self.domains = domains
    }

    public static func parse(_ text: String) throws -> [String] {
        let entries = text.split(whereSeparator: { $0.isWhitespace || $0 == "," })
        guard entries.count <= 64 else { throw ValidationError.tooManyDomains }
        var domains: [String] = []
        for entry in entries {
            var domain = entry.lowercased()
            if domain.hasSuffix(".") { domain.removeLast() }
            let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
            guard domain.utf8.count <= 253, labels.count >= 2,
                  labels.allSatisfy({ label in
                      !label.isEmpty && label.utf8.count <= 63 &&
                          label.first != "-" && label.last != "-" &&
                          label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
                  }),
                  labels.last?.utf8.contains(where: { (97...122).contains($0) }) == true else {
                throw ValidationError.invalidDomain(String(entry))
            }
            if !domains.contains(domain) { domains.append(domain) }
        }
        return domains
    }

    public static func load(from defaults: UserDefaults) throws -> Self {
        guard let value = defaults.object(forKey: storageKey) else { return Self() }
        guard let data = value as? Data else { throw ValidationError.corruptSettings }
        let settings = try JSONDecoder().decode(Self.self, from: data)
        let domains = try parse(settings.domains.joined(separator: "\n"))
        guard !settings.enabled || !domains.isEmpty else { throw ValidationError.emptyList }
        return Self(enabled: settings.enabled, domains: domains)
    }

    public func save(to defaults: UserDefaults) throws {
        let normalized = try Self.parse(domains.joined(separator: "\n"))
        guard !enabled || !normalized.isEmpty else { throw ValidationError.emptyList }
        defaults.set(try JSONEncoder().encode(Self(enabled: enabled, domains: normalized)), forKey: Self.storageKey)
    }

    public enum ValidationError: LocalizedError {
        case invalidDomain(String)
        case tooManyDomains
        case emptyList
        case corruptSettings

        public var errorDescription: String? {
            switch self {
            case let .invalidDomain(domain): "Invalid hostname: \(domain). Enter exact ASCII hostnames without URLs, ports, or wildcards."
            case .tooManyDomains: "Enter at most 64 hostnames."
            case .emptyList: "Add at least one hostname before enabling inclusion mode."
            case .corruptSettings: "Saved inclusion settings are invalid. Save a new list to replace them."
            }
        }
    }
}
