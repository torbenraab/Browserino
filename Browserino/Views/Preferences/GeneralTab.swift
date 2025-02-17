//
//  GeneralTab.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct GeneralTab: View {
    @State private var isDefault = false
    @AppStorage("browsers") private var browsers: [BrowserItem] = []
    @AppStorage("rules") private var rules: [Rule] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [BrowserItem] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]
    @AppStorage("privateArgs") private var privateArgs: [String: String] = [:]

    func defaultBrowser() -> String? {
        guard let browserUrl = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https:")!) else {
            return nil
        }

        return Bundle(url: browserUrl)?.bundleIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 32) {
                Text("Default browser")
                    .font(.headline)
                    .frame(width: 200, alignment: .trailing)

                VStack(alignment: .leading) {
                    Button(action: {
                        NSWorkspace.shared.setDefaultApplication(
                            at: Bundle.main.bundleURL,
                            toOpenURLsWithScheme: "http"
                        ) { _ in
                            isDefault = defaultBrowser() == Bundle.main.bundleIdentifier
                        }
                    }) {
                        Text("Make default")
                    }
                    .disabled(isDefault)

                    Text("Make Browserino default browser to use it")
                        .font(.callout)
                        .opacity(0.5)
                }
            }

            HStack(alignment: .top, spacing: 32) {
                Text("Installed Browsers")
                    .font(.headline)
                    .frame(width: 200, alignment: .trailing)

                VStack(alignment: .leading) {
                    Button(action: {
                        BrowserUtil.log("\n🔄 Rescan triggered from GeneralTab")
                        browsers = BrowserUtil.loadBrowsers()
                        NotificationCenter.default.post(name: NSNotification.Name("RescanBrowsers"), object: nil)
                        BrowserUtil.log("✅ Notification posted")
                    }) {
                        Text("Rescan")
                    }

                    Text("Rescan list of installed browsers")
                        .font(.callout)
                        .opacity(0.5)
                }
            }

            HStack(alignment: .top, spacing: 32) {
                Text("System reset")
                    .font(.headline)
                    .frame(width: 200, alignment: .trailing)

                VStack(alignment: .leading) {
                    Button(action: {
                        let defaults = UserDefaults.standard
                        let dictionary = defaults.dictionaryRepresentation()
                        dictionary.keys.forEach { key in
                            defaults.removeObject(forKey: key)
                        }
                    }) {
                        Text("Reset")
                    }

                    Text("Reset all preferences")
                        .font(.callout)
                        .opacity(0.5)
                }
            }

            HStack(alignment: .top, spacing: 32) {
                Text("Import/Export")
                    .font(.headline)
                    .frame(width: 200, alignment: .trailing)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Button(action: exportSettings) {
                            Text("Export Settings")
                        }

                        Button(action: importSettings) {
                            Text("Import Settings")
                        }
                    }

                    Text("Export or import all settings including rules, shortcuts, and browser preferences")
                        .font(.callout)
                        .opacity(0.5)
                }
            }
        }
        .onAppear {
            isDefault = defaultBrowser() == Bundle.main.bundleIdentifier
        }
        .padding(20)
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "browserino_settings.json"

        if panel.runModal() == .OK {
            guard let url = panel.url else { return }

            var exportData: [String: Any] = [:]

            // Export rules
            print("Exporting rules...")
            print("Found \(rules.count) rules")
            exportData["rules"] = rules.map { rule -> [String: Any] in
                var ruleDict: [String: Any] = [
                    "regex": rule.regex,
                    "app": rule.app.path
                ]
                if let profile = rule.chromeProfile {
                    ruleDict["chromeProfile"] = [
                        "id": profile.id,
                        "name": profile.name,
                        "path": profile.path
                    ]
                }
                return ruleDict
            }
            print("Rules converted to dictionary")

            // Export browsers
            print("\nExporting browsers...")
            print("Found \(browsers.count) browsers")
            exportData["browsers"] = browsers.map { browser -> [String: Any] in
                var browserDict: [String: Any] = [
                    "id": browser.id,
                    "url": browser.url.path
                ]
                if let profile = browser.profile {
                    browserDict["profile"] = [
                        "id": profile.id,
                        "name": profile.name,
                        "path": profile.path
                    ]
                }
                return browserDict
            }
            print("Browsers converted to dictionary")

            // Export hidden browsers
            print("\nExporting hidden browsers...")
            print("Found \(hiddenBrowsers.count) hidden browsers")
            exportData["hiddenBrowsers"] = hiddenBrowsers.map { browser -> [String: Any] in
                var browserDict: [String: Any] = [
                    "id": browser.id,
                    "url": browser.url.path
                ]
                if let profile = browser.profile {
                    browserDict["profile"] = [
                        "id": profile.id,
                        "name": profile.name,
                        "path": profile.path
                    ]
                }
                return browserDict
            }
            print("Hidden browsers converted to dictionary")

            // Export other settings
            exportData["shortcuts"] = shortcuts
            exportData["privateArgs"] = privateArgs

            print("\nWriting to file...")
            if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) {
                do {
                    try jsonData.write(to: url)
                    print("Settings exported successfully")
                } catch {
                    print("Failed to write file: \(error)")
                }
            } else {
                print("Failed to create JSON data")
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            guard let url = panel.url else { return }

            print("Importing settings from: \(url.path)")

            guard let jsonData = try? Data(contentsOf: url) else {
                print("Failed to read file")
                return
            }

            guard let importedData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                print("Failed to parse JSON")
                return
            }

            // Import rules
            print("\nImporting rules...")
            if let rulesData = importedData["rules"] as? [[String: Any]] {
                print("Found \(rulesData.count) rules")
                let importedRules = rulesData.compactMap { ruleDict -> Rule? in
                    guard let regex = ruleDict["regex"] as? String,
                          let appPath = ruleDict["app"] as? String else {
                        print("Invalid rule data")
                        return nil
                    }

                    var chromeProfile: ChromeProfile? = nil
                    if let profileDict = ruleDict["chromeProfile"] as? [String: String],
                       let id = profileDict["id"],
                       let name = profileDict["name"],
                       let path = profileDict["path"] {
                        chromeProfile = ChromeProfile(id: id, name: name, path: path)
                    }

                    return Rule(
                        regex: regex,
                        app: URL(fileURLWithPath: appPath),
                        chromeProfile: chromeProfile
                    )
                }
                rules = importedRules
                print("Imported \(rules.count) rules")
            }

            // Import browsers
            print("\nImporting browsers...")
            if let browsersData = importedData["browsers"] as? [[String: Any]] {
                print("Found \(browsersData.count) browsers")
                let importedBrowsers = browsersData.compactMap { browserDict -> BrowserItem? in
                    guard let id = browserDict["id"] as? String,
                          let urlPath = browserDict["url"] as? String else {
                        print("Invalid browser data")
                        return nil
                    }

                    var chromeProfile: ChromeProfile? = nil
                    if let profileDict = browserDict["profile"] as? [String: String],
                       let id = profileDict["id"],
                       let name = profileDict["name"],
                       let path = profileDict["path"] {
                        chromeProfile = ChromeProfile(id: id, name: name, path: path)
                    }

                    return BrowserItem(
                        url: URL(fileURLWithPath: urlPath),
                        profile: chromeProfile
                    )
                }
                browsers = importedBrowsers
                print("Imported \(browsers.count) browsers")
            }

            // Import hidden browsers
            print("\nImporting hidden browsers...")
            if let hiddenBrowsersData = importedData["hiddenBrowsers"] as? [[String: Any]] {
                print("Found \(hiddenBrowsersData.count) hidden browsers")
                let importedHiddenBrowsers = hiddenBrowsersData.compactMap { browserDict -> BrowserItem? in
                    guard let id = browserDict["id"] as? String,
                          let urlPath = browserDict["url"] as? String else {
                        print("Invalid hidden browser data")
                        return nil
                    }

                    var chromeProfile: ChromeProfile? = nil
                    if let profileDict = browserDict["profile"] as? [String: String],
                       let id = profileDict["id"],
                       let name = profileDict["name"],
                       let path = profileDict["path"] {
                        chromeProfile = ChromeProfile(id: id, name: name, path: path)
                    }

                    return BrowserItem(
                        url: URL(fileURLWithPath: urlPath),
                        profile: chromeProfile
                    )
                }
                hiddenBrowsers = importedHiddenBrowsers
                print("Imported \(hiddenBrowsers.count) hidden browsers")
            }

            // Import other settings
            if let importedShortcuts = importedData["shortcuts"] as? [String: String] {
                shortcuts = importedShortcuts
                print("Imported shortcuts")
            }

            if let importedPrivateArgs = importedData["privateArgs"] as? [String: String] {
                privateArgs = importedPrivateArgs
                print("Imported private args")
            }

            print("\nSettings import completed")
        }
    }
}

#Preview {
    PreferencesView()
}
