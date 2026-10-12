// Copyright (c) 2026. Licensed under GPL-3.0-or-later.

import Darwin
import Foundation

enum InclusionAddressResolver {
    // shortcut: resolve at connection time; add DNS interception before promising wildcard or live DNS coverage.
    static func resolve(_ domains: [String]) throws -> [String] {
        var addresses = Set<String>()
        for domain in domains {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(domain, nil, &hints, &result)
            guard status == 0, let first = result else { throw ResolutionError(domain: domain) }
            defer { freeaddrinfo(first) }
            var current: UnsafeMutablePointer<addrinfo>? = first
            var found = false
            while let node = current {
                if node.pointee.ai_family == AF_INET || node.pointee.ai_family == AF_INET6 {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(node.pointee.ai_addr, node.pointee.ai_addrlen, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        addresses.insert(String(cString: host))
                        found = true
                    }
                }
                current = node.pointee.ai_next
            }
            guard found else { throw ResolutionError(domain: domain) }
        }
        guard !addresses.isEmpty else { throw ResolutionError(domain: "empty list") }
        return addresses.sorted()
    }

    struct ResolutionError: LocalizedError {
        let domain: String
        var errorDescription: String? { "Could not resolve \(domain). Inclusion mode will not fall back to a full tunnel." }
    }
}
