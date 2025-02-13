//  BrowserUtil.swift
//  Browserino
//
//  Created by byt3m4st3r.
//

import AppKit
import Foundation
import SwiftUI

struct ChromeProfile: Codable, Identifiable {
    let id: String
    let name: String
    let path: String
}

class BrowserUtil {
    @AppStorage("directories") private static var directories: [Directory] = []
    @AppStorage("privateArgs") private static var privateArgs: [String: String] = [:]
    @AppStorage("enableLogging") private static var enableLogging: Bool = true

    static func log(_ message: String, items: [String] = []) {
        guard enableLogging else { return }
        print(message)
        items.forEach { print($0) }
    }

    static func toggleLogging() {
        enableLogging.toggle()
        log("\n🔄 Logging is now \(enableLogging ? "enabled" : "disabled")")
    }

    static func loadBrowsers() -> [URL] {
        // Convert directories to valid paths
        let validDirectories = directories.map { $0.directoryPath }

        guard let url = URL(string: "https:") else {
            return []
        }

        // Fetch all applications that can open the https scheme
        let urlsForApplications = NSWorkspace.shared.urlsForApplications(toOpen: url)

        // Filter the browsers to include only those in the specified browser search directories (/Applications default)
        var filteredUrlsForApplications = urlsForApplications.filter { urlsForApplication in
            validDirectories.contains { urlsForApplication.path.hasPrefix($0) }
        }

        // Remove Browserino from the browser list
        if let browserino = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "xyz.alexstrnik.Browserino") {
            if filteredUrlsForApplications.contains(browserino) {
                filteredUrlsForApplications.removeAll { $0 == browserino }
            }
        }

        // Always include Safari by adding it explicitly if not already present
        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            if !filteredUrlsForApplications.contains(safari) {
                filteredUrlsForApplications.append(safari)
            }
        }

        // Move Chrome to the end if it exists, as we'll expand it with profiles
        if let chromeIndex = filteredUrlsForApplications.firstIndex(where: { browser in
            guard let bundle = Bundle(url: browser) else { return false }
            return bundle.bundleIdentifier == "com.google.Chrome"
        }) {
            let chrome = filteredUrlsForApplications.remove(at: chromeIndex)
            filteredUrlsForApplications.append(chrome)
        }

        return filteredUrlsForApplications
    }

    static func getChromeProfiles() -> [ChromeProfile] {
        log("🔍 Getting Chrome profiles...")
        let fileManager = FileManager.default
        let userPath = fileManager.homeDirectoryForCurrentUser.path
        let chromePath = "\(userPath)/Library/Application Support/Google/Chrome"

        log("📁 Chrome path: \(chromePath)")

        guard fileManager.fileExists(atPath: chromePath) else {
            log("❌ Chrome directory not found")
            return []
        }

        let localStatePath = "\(chromePath)/Local State"
        log("📄 Local State path: \(localStatePath)")

        guard fileManager.fileExists(atPath: localStatePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: localStatePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = json["profile"] as? [String: Any],
              let profiles = info["info_cache"] as? [String: [String: Any]] else {
            log("❌ Failed to read or parse Chrome profile data")
            return []
        }

        let chromeProfiles = profiles.map { (id, profile) in
            ChromeProfile(
                id: id,
                name: profile["name"] as? String ?? "Unknown",
                path: "\(chromePath)/\(id)"
            )
        }

        log("✅ Found \(chromeProfiles.count) Chrome profiles:")
        chromeProfiles.forEach { profile in
            log("", items: [
                "  - Profile: \(profile.name) (ID: \(profile.id))",
                "    Path: \(profile.path)"
            ])
        }

        return chromeProfiles
    }

    static func openURL(_ urls: [URL], app: URL, isIncognito: Bool, chromeProfile: ChromeProfile? = nil) {
        log("\n🌐 Opening URLs...")
        log("", items: [
            "📱 App: \(app.path)",
            "🕶 Incognito: \(isIncognito)"
        ])

        if let profile = chromeProfile {
            log("👤 Chrome Profile:", items: [
                "  - Name: \(profile.name)",
                "  - ID: \(profile.id)",
                "  - Path: \(profile.path)"
            ])
        }

        guard let bundle = Bundle(url: app) else {
            log("❌ Failed to get bundle for app")
            return
        }
        log("📦 Bundle ID: \(bundle.bundleIdentifier ?? "unknown")")

        let configuration = NSWorkspace.OpenConfiguration()

        if bundle.bundleIdentifier == "com.google.Chrome" && chromeProfile != nil {
            configuration.createsNewApplicationInstance = true
            let args = ["--profile-directory=\(chromeProfile!.id)"] + urls.map(\.absoluteString)
            configuration.arguments = args
            log("🔧 Chrome configuration:", items: [
                "  - New instance: true",
                "  - Arguments: \(args)"
            ])
        } else if isIncognito, let privateArg = privateArgs[bundle.bundleIdentifier!] {
            configuration.createsNewApplicationInstance = true
            let args = [privateArg] + urls.map(\.absoluteString)
            configuration.arguments = args
            log("🔧 Incognito configuration:", items: [
                "  - New instance: true",
                "  - Arguments: \(args)"
            ])
        }

        log("🔗 Opening URLs:")
        urls.forEach { log("  - \($0.absoluteString)") }

        NSWorkspace.shared.open(
            isIncognito ? [] : urls,
            withApplicationAt: app,
            configuration: configuration
        )
        log("✅ Open command sent to system")
    }
}
