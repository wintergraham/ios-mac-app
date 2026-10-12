# Install the inclusion fork on an iPhone

This branch adds Settings > VPN inclusion to Proton's iOS app. It is source code, not a signed installable IPA. A complete app build and physical-device routing test are still required before relying on it.

## What the mode does

- You enter up to 64 exact hostnames. It accepts ASCII names, one per line or separated by commas. It rejects URLs, ports, IP addresses, and wildcards.
- At connection time, the extension resolves every hostname using the phone's resolver. It replaces the default VPN route with the resulting IPv4 host routes.
- The upstream WireGuard configuration is IPv4-only. The fork installs host routes for resolved IPv6 addresses into the extension, where the IPv4-only peer cannot forward them. Those connections should fail and apps can fall back to IPv4. This needs verification on your iPhone.
- Unlisted destination IPs use the normal connection. Other sites sharing a listed IP can also use the VPN.
- DNS stays on your normal connection. Proton's internal control endpoint at `10.2.0.1` and the VPN transport itself remain necessary.
- Saving disconnects the VPN. Connect again to apply changes. Inclusion mode disables Kill Switch and uses the legacy WireGuard extension, including when the experimental ProTUN flag is enabled.
- An enabled empty list, malformed saved settings, or a DNS lookup failure prevents connection. It never substitutes a full-device route for those failures.

This is a snapshot of DNS results. New DNS addresses, cached answers that differ from the resolver's answers, app-specific DNS, and network changes can leave listed services outside the VPN. Reconnect to resolve the list again. Existing connections also need to be reopened. This mode does not provide continuous domain enforcement.

The OpenAI starter list is a small starting point. OpenAI documents wildcard domain families and additional services, which this implementation cannot automatically expand. Add the actual hostnames used by the features you need. Voice, authentication, uploads, and dynamic subdomains may need more entries. See [OpenAI's network guidance](https://help.openai.com/en/articles/9247338-network-recommendations-for-chatgpt-errors-on-web-and-apps).

## Build prerequisites

Xcode 27.0 is installed on the development Mac. The app targets iOS 17 or newer. A paid Apple Developer team is required for the VPN entitlements. Having a membership does not automatically configure signing on this Mac. At the initial check, `security find-identity -v -p codesigning` found no valid identities and `xcrun devicectl list devices` found no devices.

The following upstream dependencies need to be available before installation:

1. Public pinned submodules. This fork fixes their URLs and initializes them with:

   ```sh
   git submodule update --init --depth=1 external/protoncore external/apple-fusion external/wireguard-apple
   ```

2. Git LFS and the build tools listed in `Brewfile`. Use `brew bundle` after reviewing it.
3. Generated `ObfuscatedConstants.swift` files for the app and Swift packages. Proton's README describes a separate credentials repository. The public example alone does not supply the generated files or working configuration. Use legitimate build configuration you have access to; do not copy blank examples and assume authentication will work.
4. The current checkout also resolves `protunFFI.xcframework.zip` from `nexus.protontech.ch`. A direct connection to that host timed out here. Disabling the runtime ProTUN flag does not remove this build dependency. The workspace references an additional `external/swift-cargo` submodule with an internal relative URL. Its public mirror has not been identified.

These are upstream build prerequisites, separate from your Apple account. No signed IPA has been produced. The feature checks below do not certify a full app build.

The complete unsigned build was attempted with the `ProtonVPN-iOS` scheme. It failed during package resolution because downloading `protunFFI.xcframework.zip` timed out. It did not reach source compilation. The direct internal-binary-host probe also timed out after 15 seconds. This does not establish that the new integration compiles in the full dependency graph.

## Configure signing

1. Open `ProtonVPN.xcworkspace` in Xcode. Choose the `ProtonVPN-iOS` scheme.
2. Open Xcode Settings > Apple Accounts and select your existing paid developer account. In Signing & Capabilities, select your team and enable automatic signing for the app and embedded extensions.
3. Use unique bundle identifiers. For example, replace the iOS identifier prefix `ch.protonmail.vpn` with `com.yourname.protoninclusion`, preserving each extension's suffix. Update every build configuration, including the `.debug` identifiers.
4. Replace `group.ch.protonmail.vpn` with an App Group registered to your team. The entitlement files under `apps/ios` and `DomainConstants.AppGroups.main` in `libraries/Foundations/Domain/Sources/Domain/Constants.swift` must agree. Update `DomainConstants.BundleID.main` and the app's URL identifier too.
5. Replace `group.me.proton.protoncore.account` in the app entitlements with a group owned by your team or remove it if you do not use shared Proton accounts. Update any corresponding account-group configuration in ProtonCore.
6. Replace the keychain access group `prt.ProtonVPN` consistently in the app/extension entitlements and `libraries/Core/NEHelper/Sources/VPNShared/Authentication/VpnAuthenticationStorage.swift`. Keep `$(AppIdentifierPrefix)` in the entitlements. Keep the extension identifiers derived from the app identifier consistent.
7. Retain the packet-tunnel-provider Network Extension entitlement, the app's Personal VPN capability, and the shared App Group/keychain access. Resolve every signing error in Xcode before running.

## Install and enable

1. Connect and unlock your iPhone, then accept Trust This Computer.
2. Enable Settings > Privacy & Security > Developer Mode on the phone, restart if prompted, and confirm. See [Apple's Developer Mode instructions](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).
3. Select your iPhone as Xcode's run destination and press Run. Xcode can register the device and create signing assets with automatic signing. See [Apple's device installation guide](https://help.apple.com/xcode/mac/current/en.lproj/dev5a825a1ca.html).
4. Open the fork, use your existing Proton account, and accept the VPN configuration prompt. Disable other VPN configurations while testing this one.
5. Open Settings > VPN inclusion, enter your hostnames or use the starter list, enable Route only listed hosts, and tap Save and disconnect.
6. Connect to a Proton server. Close and reopen the applications you are testing.

## Verify before relying on it

Run the isolated source checks on the Mac:

```sh
bash Integration/Scripts/check_domain_inclusion.sh
```

They verify parser boundaries, persistence and corruption handling, DNS failures, removal of default routes, exact IPv4/IPv6 host routes, and removal of tunnel DNS settings. The new SwiftUI screen and routing helpers also passed isolated typechecking against the iOS SDK. This used a defaults shim for the screen, not the full app dependency graph.

On the phone, verify a listed IPv4 test destination reports the Proton egress address and an unlisted test destination reports the ordinary egress address. Verify listed IPv6 destinations cannot succeed directly, and IPv4 fallback works. Use server access logs or packet captures to establish this; the VPN status icon alone cannot prove selective routing. Test Wi-Fi, cellular, reconnection, DNS failures, and Kill Switch changes. Remove test hostnames afterwards.

If installation or routing validation fails, leave the fork disconnected. The source changes are available for review, but device-level behavior has not yet been validated.

## Sources

- [Proton's source and build prerequisites](https://github.com/ProtonVPN/ios-mac-app)
- [Apple's VPN routing API](https://developer.apple.com/documentation/networkextension/routing-your-vpn-network-traffic)
