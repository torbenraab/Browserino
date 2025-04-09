//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    @AppStorage("browsers") private var browsers: [BrowserItem] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [BrowserItem] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]
    @AppStorage("rules") private var rules: [Rule] = []
    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @FocusState private var focused: Bool

    let urls: [URL]

    private func isChrome(_ bundle: Bundle) -> Bool {
        return bundle.bundleIdentifier == "com.google.Chrome"
    }
    
    private func isEdge(_ bundle: Bundle) -> Bool {
        return bundle.bundleIdentifier == "com.microsoft.edgemac"
    }

    private func shortcutKey(for browser: BrowserItem, bundleId: String) -> String {
        if let profile = browser.profile {
            return "\(bundleId)_\(profile.id)"
        }
        return bundleId
    }

    private func checkRules() {
        BrowserUtil.log("\n🔍 Checking rules...")
        BrowserUtil.log("📝 Total rules: \(rules.count)")
        BrowserUtil.log("🌐 Available browsers: \(browsers.count)")
        browsers.forEach { browser in
            if let bundle = Bundle(url: browser.url),
               bundle.bundleIdentifier == "com.google.Chrome" {
                BrowserUtil.log("  - Chrome browser: \(browser.url.path)")
                if let profile = browser.profile {
                    BrowserUtil.log("    Profile: id=\(profile.id), name=\(profile.name)")
                } else {
                    BrowserUtil.log("    No profile")
                }
            }
        }

        // Check if any URL matches any rule
        for url in urls {
            let urlString = url.absoluteString
            BrowserUtil.log("\n🌐 Checking URL: \(urlString)")

            for rule in rules {
                BrowserUtil.log("\n⚡️ Testing rule: \(rule.regex)")
                BrowserUtil.log("  Browser: \(rule.app.path)")
                if let profile = rule.chromeProfile {
                    BrowserUtil.log("  Chrome Profile: id=\(profile.id), name=\(profile.name)")
                }

                do {
                    let regex = try Regex(rule.regex).ignoresCase()
                    if urlString.firstMatch(of: regex) != nil {
                        // Found a matching rule, open in the specified browser
                        if let bundle = Bundle(url: rule.app) {
                            BrowserUtil.log("\n✅ Rule matched:", items: [
                                "  URL: \(urlString)",
                                "  Regex: \(rule.regex)",
                                "  Browser: \(bundle.bundleIdentifier ?? "unknown")",
                                "  Profile: \(rule.chromeProfile?.name ?? "none")"
                            ])

                            // Check if this is Chrome and has a profile
                            if (isChrome(bundle) || isEdge(bundle)) && rule.chromeProfile != nil {
                                BrowserUtil.log("\n🔍 Looking for matching Chrome profile...")

                                // Find the matching browser with the correct Chrome profile
                                let matchingBrowser = browsers.first(where: { browser in
                                    guard let browserBundle = Bundle(url: browser.url),
                                          isChrome(bundle) || isEdge(bundle),
                                          let browserProfile = browser.profile else {
                                        BrowserUtil.log("❌ Skipping browser: No Chrome or no profile")
                                        return false
                                    }

                                    BrowserUtil.log("Comparing profiles:")
                                    BrowserUtil.log("  Rule profile: id=\(rule.chromeProfile!.id), name=\(rule.chromeProfile!.name)")
                                    BrowserUtil.log("  Browser profile: id=\(browserProfile.id), name=\(browserProfile.name)")

                                    let matches = browserProfile.id == rule.chromeProfile!.id
                                    BrowserUtil.log(matches ? "✅ Profiles match!" : "❌ Profiles don't match")
                                    return matches
                                })

                                if let matchingBrowser = matchingBrowser {
                                    BrowserUtil.log("✅ Found matching Chrome profile: \(matchingBrowser.profile?.name ?? "unknown")")
                                    BrowserUtil.openURL(
                                        urls,
                                        app: matchingBrowser.url,
                                        isIncognito: false,
                                        chromeProfile: matchingBrowser.profile
                                    )
                                } else {
                                    BrowserUtil.log("❌ No matching Chrome profile found, using default browser")
                                    BrowserUtil.openURL(
                                        urls,
                                        app: rule.app,
                                        isIncognito: false,
                                        chromeProfile: rule.chromeProfile
                                    )
                                }
                            } else {
                                // For non-Chrome browsers or Chrome without profile
                                BrowserUtil.log("📝 Using regular browser (non-Chrome or no profile)")
                                BrowserUtil.openURL(
                                    urls,
                                    app: rule.app,
                                    isIncognito: false,
                                    chromeProfile: rule.chromeProfile
                                )
                            }

                            DispatchQueue.main.async {
                                NSApplication.shared.hide(nil)
                            }
                            return
                        } else {
                            BrowserUtil.log("❌ Bundle not found for app: \(rule.app.path)")
                        }
                    } else {
                        BrowserUtil.log("❌ No match for regex: \(rule.regex)")
                    }
                } catch {
                    BrowserUtil.log("❌ Invalid regex pattern: \(rule.regex), Error: \(error.localizedDescription)")
                }
            }
        }
        BrowserUtil.log("📌 No matching rules found")
    }

    private func filterAppsForUrls() -> [App] {
        guard let firstUrlHost = urls.first?.host() else { return [] }
        return apps.filter { app in
            app.host == firstUrlHost && !browsers.contains(where: { $0.url == app.app })
        }
    }

    var appsForUrls: [App] {
        filterAppsForUrls()
    }

    var visibleBrowsers: [BrowserItem] {
        browsers.filter { !hiddenBrowsers.contains($0) }
    }

    @ViewBuilder
    private func appItemView(app: App, index: Int) -> some View {
        if let bundle = Bundle(url: app.app) {
            PromptItem(
                browser: app.app,
                urls: urls,
                bundle: bundle,
                shortcut: shortcuts[bundle.bundleIdentifier!]
            ) {
                selected = index  // Set selection on click
            }
            .id(index)
            .buttonStyle(
                SelectButtonStyle(
                    selected: selected == index
                )
            )
        } else {
            EmptyView()
        }
    }

    private func browserItemView(browser: BrowserItem, index: Int, baseIndex: Int) -> some View {
        Group {
            if let bundle = Bundle(url: browser.url) {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        selected = baseIndex + index

                        BrowserUtil.log("\n🖱 Button clicked:", items: [
                            "🌐 Browser: \(browser.url.path)",
                            "🔍 Is Chrome: \(isChrome(bundle))",
                            "👤 Profile: \(browser.profile?.name ?? "none")",
                            "🕶 Shift pressed: \(NSEvent.modifierFlags.contains(.shift))"
                        ])

                        BrowserUtil.openURL(
                            urls,
                            app: browser.url,
                            isIncognito: NSEvent.modifierFlags.contains(.shift),
                            chromeProfile: browser.profile
                        )

                        NSApplication.shared.hide(nil)
                    }) {
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
                                .resizable()
                                .frame(width: 32, height: 32)

                            if (isChrome(bundle) || isEdge(bundle)) && browser.profile != nil {
                                Text("\(bundle.infoDictionary!["CFBundleName"] as! String) (\(browser.profile!.name))")
                                    .font(.system(size: 14))
                            } else {
                                Text(bundle.infoDictionary!["CFBundleName"] as! String)
                                    .font(.system(size: 14))
                            }

                            Spacer()

                            if let shortcut = shortcuts[shortcutKey(for: browser, bundleId: bundle.bundleIdentifier!)] {
                                Text(shortcut)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(
                        SelectButtonStyle(
                            selected: selected == baseIndex + index
                        )
                    )
                    .id(baseIndex + index)
                }
            } else {
                EmptyView()
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                            appItemView(app: app, index: index)
                        }

                        ForEach(Array(visibleBrowsers.enumerated()), id: \.offset) { index, browser in
                            browserItemView(
                                browser: browser,
                                index: index,
                                baseIndex: appsForUrls.count
                            )
                        }
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($focused)
                .onKeyPress { press in
                    if press.key == .upArrow {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                        return .handled
                    }

                    if press.key == .downArrow {
                        selected = min(appsForUrls.count + visibleBrowsers.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                        return .handled
                    }

                    if press.key == .return {
                        if selected < appsForUrls.count {
                            let app = appsForUrls[selected]
                            BrowserUtil.openURL(urls, app: app.app, isIncognito: press.modifiers.contains(.shift))
                        } else {
                            let browser = visibleBrowsers[selected - appsForUrls.count]
                            BrowserUtil.openURL(
                                urls,
                                app: browser.url,
                                isIncognito: press.modifiers.contains(.shift),
                                chromeProfile: browser.profile
                            )
                        }
                        NSApplication.shared.hide(nil)
                        return .handled
                    }

                    // Check for shortcuts
                    let pressedKey = press.characters
                    if !pressedKey.isEmpty {
                        // First check app shortcuts
                        if let appIndex = appsForUrls.firstIndex(where: { app in
                            guard let bundle = Bundle(url: app.app) else { return false }
                            return shortcuts[bundle.bundleIdentifier!] == pressedKey
                        }) {
                            let app = appsForUrls[appIndex]
                            BrowserUtil.openURL(urls, app: app.app, isIncognito: press.modifiers.contains(.shift))
                            NSApplication.shared.hide(nil)
                            return .handled
                        }

                        // Then check browser shortcuts
                        if let browserIndex = visibleBrowsers.firstIndex(where: { browser in
                            guard let bundle = Bundle(url: browser.url) else { return false }
                            let key = shortcutKey(for: browser, bundleId: bundle.bundleIdentifier!)
                            return shortcuts[key] == pressedKey
                        }) {
                            let browser = visibleBrowsers[browserIndex]
                            BrowserUtil.openURL(
                                urls,
                                app: browser.url,
                                isIncognito: press.modifiers.contains(.shift),
                                chromeProfile: browser.profile
                            )
                            NSApplication.shared.hide(nil)
                            return .handled
                        }
                    }

                    return .ignored
                }
            }

            Divider()

            if let host = urls.first?.host() {
                Text(host)
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlurredView())
        .opacity(opacityAnimation)
        .edgesIgnoringSafeArea(.all)
        .task {
            // Check rules immediately when view appears
            BrowserUtil.log("\n🚀 PromptView appeared")
            focused.toggle()
            withAnimation(.interactiveSpring(duration: 0.3)) {
                opacityAnimation = 1
            }

            BrowserUtil.log("\n🔄 Starting rules check...")
            checkRules()
        }
    }
}

#Preview {
    PromptView(urls: [])
}
