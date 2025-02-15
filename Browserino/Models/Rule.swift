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
