// Copyright (c) 2026. Licensed under GPL-3.0-or-later.

import Domain
import SwiftUI

struct DomainInclusionView: View {
    let onSave: @MainActor (DomainInclusionSettings) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var enabled = false
    @State private var domains = ""
    @State private var error: String?
    @State private var saving = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Toggle("Route only listed hosts", isOn: $enabled)
            } footer: {
                Text("Other destination IPs use your normal connection. Sites sharing a listed IP also use the VPN.")
            }
            Section("Exact hostnames") {
                TextEditor(text: $domains)
                    .frame(minHeight: 180)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityLabel("VPN inclusion hostnames, one per line")
                Button("Use OpenAI starter list") {
                    domains = DomainInclusionSettings.suggestedDomains
                }
            }
            Section {
                Text("Enter one hostname per line. Subdomains need their own entries. Wildcards and URLs are not supported.")
                Text("Addresses resolve when you connect. Reconnect after a network change or if a service stops working. New DNS addresses may bypass the VPN until you reconnect.")
                Text("Listed IPv4 addresses use Proton. Listed IPv6 addresses are blocked because this WireGuard configuration supports IPv4 only. Apps can fall back to IPv4.")
                Text("DNS uses your normal resolver. Kill Switch is disabled and the legacy WireGuard engine is used while inclusion mode is enabled. Proton control traffic also uses the tunnel.")
            }
            Section {
                Button(saving ? "Saving…" : "Save and disconnect") { save() }
                    .disabled(saving || !loaded)
            } footer: {
                Text("Saving disconnects the VPN. Connect again to apply this list.")
            }
        }
        .navigationTitle("VPN inclusion")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(saving)
        .task { load() }
        .alert("Could not save inclusion settings", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func load() {
        do {
            let settings = try DomainInclusionSettings.load(from: .domainUserDefaults)
            enabled = settings.enabled
            domains = settings.domains.joined(separator: "\n")
            loaded = true
        } catch {
            self.error = error.localizedDescription
            loaded = true
        }
    }

    private func save() {
        saving = true
        Task { @MainActor in
            defer { saving = false }
            do {
                let settings = DomainInclusionSettings(enabled: enabled, domains: try DomainInclusionSettings.parse(domains))
                guard !enabled || !settings.domains.isEmpty else { throw DomainInclusionSettings.ValidationError.emptyList }
                try await onSave(settings)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
