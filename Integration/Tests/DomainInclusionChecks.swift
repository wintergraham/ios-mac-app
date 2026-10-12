// Copyright (c) 2026. Licensed under GPL-3.0-or-later.

import Foundation
import NetworkExtension

@main
struct DomainInclusionChecks {
    static func main() throws {
        let parsed = try DomainInclusionSettings.parse("CHATGPT.com.\napi.openai.com,chatgpt.com")
        assert(parsed == ["chatgpt.com", "api.openai.com"])
        for invalid in ["https://chatgpt.com", "*.openai.com", "127.0.0.1", "chatgpt.com:443", ".openai.com", "a..com", "-a.com", "a-.com", "a.com.."] {
            do {
                _ = try DomainInclusionSettings.parse(invalid)
                fatalError("Accepted invalid hostname: \(invalid)")
            } catch {}
        }
        let suite = "DomainInclusionChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = DomainInclusionSettings(enabled: true, domains: ["chatgpt.com"])
        try settings.save(to: defaults)
        let restored = try DomainInclusionSettings.load(from: defaults)
        assert(restored == settings)
        do {
            try DomainInclusionSettings(enabled: true).save(to: defaults)
            fatalError("Enabled an empty inclusion list")
        } catch {}

        defaults.set("wrong storage type", forKey: DomainInclusionSettings.storageKey)
        do {
            _ = try DomainInclusionSettings.load(from: defaults)
            fatalError("Invalid storage type fell back to full-device routing")
        } catch {}
        defaults.set(Data("bad JSON".utf8), forKey: DomainInclusionSettings.storageKey)
        do {
            _ = try DomainInclusionSettings.load(from: defaults)
            fatalError("Corrupt settings fell back to full-device routing")
        } catch {}

        let network = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.2.0.2"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [.default()]
        ipv4.excludedRoutes = [.default()]
        network.ipv4Settings = ipv4
        network.dnsSettings = NEDNSSettings(servers: ["10.2.0.1"])
        InclusionNetworkSettings.apply(addresses: ["203.0.113.7", "2001:db8::7"], to: network)
        assert(network.dnsSettings == nil)
        assert(network.ipv4Settings?.includedRoutes?.map(\.destinationAddress) == ["203.0.113.7", "10.2.0.1"])
        assert(network.ipv4Settings?.includedRoutes?.allSatisfy { $0.destinationSubnetMask == "255.255.255.255" } == true)
        assert(network.ipv4Settings?.excludedRoutes?.isEmpty == true)
        assert(network.ipv6Settings?.includedRoutes?.map(\.destinationAddress) == ["2001:db8::7"])
        assert(network.ipv6Settings?.includedRoutes?.allSatisfy { $0.destinationNetworkPrefixLength == 128 } == true)
        do {
            _ = try InclusionAddressResolver.resolve([])
            fatalError("Resolved an empty inclusion list")
        } catch {}
        let localAddresses = try InclusionAddressResolver.resolve(["localhost"])
        assert(!localAddresses.isEmpty)
        do {
            _ = try InclusionAddressResolver.resolve(["proton-inclusion-test.invalid"])
            fatalError("Resolved a reserved invalid hostname")
        } catch {}
        print("Domain inclusion checks passed: validation, persistence, IPv4/IPv6 route policy, DNS and resolver failures.")
    }
}
