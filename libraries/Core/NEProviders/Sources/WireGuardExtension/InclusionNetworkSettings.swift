// Copyright (c) 2026. Licensed under GPL-3.0-or-later.

import NetworkExtension

enum InclusionNetworkSettings {
    static func apply(addresses: [String], to settings: NEPacketTunnelNetworkSettings) {
        settings.dnsSettings = nil
        settings.ipv4Settings?.includedRoutes = addresses.filter { !$0.contains(":") }.map {
            NEIPv4Route(destinationAddress: $0, subnetMask: "255.255.255.255")
        } + [NEIPv4Route(destinationAddress: "10.2.0.1", subnetMask: "255.255.255.255")]
        settings.ipv4Settings?.excludedRoutes = []
        // The upstream peer accepts IPv4 only. Capture selected IPv6 destinations to drop them instead of leaking them.
        let ipv6 = NEIPv6Settings(addresses: ["fd00:7072:6f74::2"], networkPrefixLengths: [128])
        ipv6.includedRoutes = addresses.filter { $0.contains(":") }.map {
            NEIPv6Route(destinationAddress: $0, networkPrefixLength: 128)
        }
        settings.ipv6Settings = ipv6
    }
}
