//
//  PromptItem.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct PromptItem: View {
    var browser: URL
    var urls: [URL]
    var bundle: Bundle
    var shortcut: String?
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(bundle.infoDictionary!["CFBundleName"] as! String)
                    .font(
                        .system(size: 10, weight: .bold)
                    )
                
                Spacer()
                
                if let shortcut {
                    Text(shortcut)
                        .font(.caption)
                        .frame(minWidth: 4)
                        .opacity(0.5)
                        .padding(5)
                        .background(
                            Color.secondary.opacity(0.2)
                        )
                        .cornerRadius(4)
                }
                
                Spacer()
                    .frame(width: 8)
                
                Image(
                    nsImage: NSWorkspace.shared.icon(
                        forFile: bundle.bundlePath
                    )
                )
                .resizable()
                .frame(width: 22, height: 22)
            }
            .padding(8)
        }
        .if(shortcut != nil) {
            return $0.keyboardShortcut(
                KeyEquivalent(shortcut!.lowercased().first!),
                modifiers: [.shift]
            ).background {
                Button(action: action) {}
                    .opacity(0)
                    .keyboardShortcut(
                        KeyEquivalent(shortcut!.lowercased().first!),
                        modifiers: []
                    )
            }
        }
    }
}
