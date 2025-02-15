//
//  RulesTab.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

struct AddRule: View {
    @State private var addPresented = false

    var body: some View {
        HStack {
            Image(systemName: "plus")
                .font(.system(size: 14))
                .opacity(0)

            Text("Add a new rule by typing regex and selecting an app.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: 16)

            Button(action: {
                addPresented.toggle()
            }) {
                Text("Add new rule")
            }
            .sheet(isPresented: $addPresented) {
                NewRuleForm(
                    isPresented: $addPresented
                )
            }
        }
    }
}

struct RuleItem: View {
    @Binding var rule: Rule
    @State private var editPresented = false
    @State private var bundle: Bundle?

    private func isChrome(_ bundle: Bundle) -> Bool {
        return bundle.bundleIdentifier == "com.google.Chrome"
    }

    private func loadBundle() {
        bundle = Bundle(url: rule.app)
    }

    var body: some View {
        HStack {
            Button(action: {
                editPresented.toggle()
            }) {
                if let bundle = bundle {
                    Label(rule.regex, systemImage: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                } else {
                    Label(rule.regex, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let bundle = bundle {
                if let bundleName = bundle.infoDictionary?["CFBundleName"] as? String {
                    if isChrome(bundle) && rule.chromeProfile != nil {
                        Text("\(bundleName) (\(rule.chromeProfile!.name))")
                            .font(.system(size: 14))
                    } else {
                        Text(bundleName)
                            .font(.system(size: 14))
                    }

                    Spacer()
                        .frame(width: 8)

                    Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
                        .resizable()
                        .frame(width: 32, height: 32)
                }
            } else {
                Text("Invalid application: \(rule.app.path)")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .sheet(isPresented: $editPresented) {
            EditRuleForm(
                rule: $rule,
                isPresented: $editPresented
            )
        }
        .onAppear(perform: loadBundle)
        .onChange(of: rule) { _ in
            loadBundle()
        }
    }
}

struct RulesTab: View {
    @AppStorage("rules") private var rules: [Rule] = []

    var body: some View {
        VStack(alignment: .leading) {
            List {
                AddRule()

                ForEach(Array($rules.enumerated()), id: \.offset) { offset, rule in
                    RuleItem(
                        rule: rule
                    )
                }
            }

            Text("Type regex and choose app in which links will be opened without prompt")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.5))
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 20)
    }
}

#Preview {
    RulesTab()
}
