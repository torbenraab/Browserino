//
//  Rule.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import Foundation

struct Rule: Hashable, Codable {
    var regex: String
    var app: URL
    var chromeProfile: ChromeProfile?

    enum CodingKeys: String, CodingKey {
        case regex
        case app
        case chromeProfile
    }

    init(regex: String, app: URL, chromeProfile: ChromeProfile? = nil) {
        self.regex = regex
        self.app = app
        self.chromeProfile = chromeProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regex = try container.decode(String.self, forKey: .regex)
        let appPath = try container.decode(String.self, forKey: .app)
        app = URL(fileURLWithPath: appPath)
        chromeProfile = try container.decodeIfPresent(ChromeProfile.self, forKey: .chromeProfile)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(regex, forKey: .regex)
        try container.encode(app.path, forKey: .app)
        try container.encodeIfPresent(chromeProfile, forKey: .chromeProfile)
    }

    static func == (lhs: Rule, rhs: Rule) -> Bool {
        return lhs.regex == rhs.regex &&
               lhs.app.path == rhs.app.path &&
               lhs.chromeProfile?.id == rhs.chromeProfile?.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(regex)
        hasher.combine(app.path)
        hasher.combine(chromeProfile?.id)
    }
}
