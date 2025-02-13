//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    @AppStorage("browsers") private var browsers: [URL] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [URL] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]
    @State private var chromeProfiles: [ChromeProfile] = []

    let urls: [URL]

    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @FocusState private var focused: Bool

    private func isChrome(_ bundle: Bundle) -> Bool {
        return bundle.bundleIdentifier == "com.google.Chrome"
    }

    private func filterAppsForUrls() -> [App] {
        guard let firstUrlHost = urls.first?.host() else { return [] }
        return apps.filter { app in
            app.host == firstUrlHost && !browsers.contains(app.app)
        }
    }

    var appsForUrls: [App] {
        filterAppsForUrls()
    }

    var visibleBrowsers: [URL] {
        browsers.filter { !hiddenBrowsers.contains($0) }
    }

    var visibleItems: [(URL, ChromeProfile?)] {
        var items: [(URL, ChromeProfile?)] = []

        for browser in visibleBrowsers {
            if let bundle = Bundle(url: browser), isChrome(bundle) {
                // Add Chrome profiles as separate items
                if chromeProfiles.isEmpty {
                    // If no profiles, add Chrome as is
                    items.append((browser, nil))
                } else {
                    // Add each Chrome profile
                    for profile in chromeProfiles {
                        items.append((browser, profile))
                    }
                }
            } else {
                // Add regular browser
                items.append((browser, nil))
            }
        }

        // Sort items to ensure Chrome profiles are grouped together
        items.sort { item1, item2 in
            guard let bundle1 = Bundle(url: item1.0),
                  let bundle2 = Bundle(url: item2.0) else {
                return false
            }

            let isChrome1 = isChrome(bundle1)
            let isChrome2 = isChrome(bundle2)

            if isChrome1 && isChrome2 {
                // Both are Chrome, sort by profile name
                let name1 = item1.1?.name ?? ""
                let name2 = item2.1?.name ?? ""
                return name1 < name2
            } else if isChrome1 != isChrome2 {
                // Put Chrome items first
                return isChrome1
            } else {
                // Sort other browsers by name
                let name1 = bundle1.infoDictionary?["CFBundleName"] as? String ?? ""
                let name2 = bundle2.infoDictionary?["CFBundleName"] as? String ?? ""
                return name1 < name2
            }
        }

        return items
    }

    func openUrlsInApp(app: App) {
        let urls = if app.schemeOverride.isEmpty {
            urls
        } else {
            urls.map {
                let url = NSURLComponents.init(
                    url: $0,
                    resolvingAgainstBaseURL: true
                )
                url!.scheme = app.schemeOverride

                return url!.url!
            }
        }

        BrowserUtil.openURL(
            urls,
            app: app.app,
            isIncognito: false
        )
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
                openUrlsInApp(app: app)
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

    @ViewBuilder
    private func browserItemView(browser: URL, profile: ChromeProfile?, index: Int, baseIndex: Int) -> some View {
        if let bundle = Bundle(url: browser) {
            let isChromeBrowser = isChrome(bundle)
            VStack(alignment: .leading, spacing: 0) {
                if !isChromeBrowser || profile != nil {  // Show only for non-Chrome or Chrome with profile
                    Button(action: {
                        selected = baseIndex + index  // Set selection on click

                        BrowserUtil.log("\n🖱 Button clicked:", items: [
                            "🌐 Browser: \(browser.path)",
                            "🔍 Is Chrome: \(isChromeBrowser)",
                            "👤 Profile: \(profile?.name ?? "none")",
                            "🕶 Shift pressed: \(NSEvent.modifierFlags.contains(.shift))"
                        ])

                        BrowserUtil.openURL(
                            urls,
                            app: browser,
                            isIncognito: NSEvent.modifierFlags.contains(.shift),
                            chromeProfile: profile
                        )
                    }) {
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
                                .resizable()
                                .frame(width: 32, height: 32)

                            if isChromeBrowser && profile != nil {
                                Text("\(bundle.infoDictionary!["CFBundleName"] as! String) (\(profile!.name))")
                                    .font(.system(size: 14))
                            } else {
                                Text(bundle.infoDictionary!["CFBundleName"] as! String)
                                    .font(.system(size: 14))
                            }

                            Spacer()

                            if let shortcut = shortcuts[bundle.bundleIdentifier!] {
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
            }
        } else {
            EmptyView()
        }
    }

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                            appItemView(app: app, index: index)
                        }

                        ForEach(Array(visibleItems.enumerated()), id: \.offset) { index, item in
                            browserItemView(
                                browser: item.0,
                                profile: item.1,
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
                    let totalItems = appsForUrls.count + visibleItems.count

                    if press.key == KeyEquivalent.upArrow {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                        return .handled
                    } else if press.key == KeyEquivalent.downArrow {
                        selected = min(totalItems - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                        return .handled
                    } else if press.key == KeyEquivalent.return {
                        BrowserUtil.log("\n⌨️ Return key pressed:", items: [
                            "📊 Selected index: \(selected)",
                            "🕶 Shift pressed: \(press.modifiers.contains(.shift))"
                        ])

                        if selected < appsForUrls.count {
                            BrowserUtil.log("📱 Opening app")
                            openUrlsInApp(app: appsForUrls[selected])
                        } else {
                            let browserIndex = selected - appsForUrls.count
                            let (browser, profile) = visibleItems[browserIndex]
                            let bundle = Bundle(url: browser)
                            let isChromeBrowser = bundle != nil && isChrome(bundle!)

                            BrowserUtil.log("🌐 Opening browser:", items: [
                                "  - Path: \(browser.path)",
                                "  - Is Chrome: \(isChromeBrowser)",
                                "  - Profile: \(profile?.name ?? "none")"
                            ])

                            if isChromeBrowser && profile != nil {
                                BrowserUtil.log("👤 Using Chrome profile:", items: [
                                    "  - Name: \(profile!.name)",
                                    "  - ID: \(profile!.id)",
                                    "  - Path: \(profile!.path)"
                                ])
                            }

                            BrowserUtil.openURL(
                                urls,
                                app: browser,
                                isIncognito: press.modifiers.contains(.shift),
                                chromeProfile: profile
                            )
                        }
                        return .handled
                    }

                    return .ignored
                }
                .onAppear {
                    focused.toggle()
                    BrowserUtil.log("\n🔄 Loading Chrome profiles...")
                    chromeProfiles = BrowserUtil.getChromeProfiles()
                    BrowserUtil.log("✅ Loaded \(chromeProfiles.count) Chrome profiles")
                    withAnimation(.interactiveSpring(duration: 0.3)) {
                        opacityAnimation = 1
                    }
                }
            }

            Divider()

            if let host = urls.first?.host() {
                Text(host)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlurredView())
        .opacity(opacityAnimation)
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    PromptView(urls: [])
}
