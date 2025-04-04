//
//  EditRuleForm.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 02.12.2024.
//

import SwiftUI

struct EditRuleForm: View {
    @Binding var rule: Rule
    @Binding var isPresented: Bool

    @AppStorage("rules") private var rules: [Rule] = []

    var body: some View {
        RuleForm(
            rule: rule,
            onCancel: {
                isPresented.toggle()
            },
            onSave: {
                rule = $0
                isPresented.toggle()
            },
            onDelete: {
                rules.removeAll {
                    $0 == rule
                }
                isPresented.toggle()
            }
        )
    }
}

struct NewRuleForm: View {
    @Binding var isPresented: Bool

    @AppStorage("rules") private var rules: [Rule] = []

    var body: some View {
        RuleForm(
            rule: nil,
            onCancel: {
                isPresented.toggle()
            },
            onSave: {
                rules.append($0)
                isPresented.toggle()
            },
            onDelete: {
                isPresented.toggle()
            }
        )
    }
}

struct RuleForm: View {
    var rule: Rule?

    var onCancel: () -> Void
    var onSave: (Rule) -> Void
    var onDelete: () -> Void

    @State private var openWithPresented = false

    @State private var regex: String = ""
    @State private var testUrls: String = "https://github.com/AlexStrNik/Browserino\nhttps://x.com/alexstrnik"
    @State private var url: URL?
    @State private var selectedProfile: ChromeProfile?
    @State private var chromeProfiles: [ChromeProfile] = []

    private var isChrome: Bool {
        guard let bundle = url.map({ Bundle(url: $0)! }) else { return false }
        return bundle.bundleIdentifier == "com.google.Chrome"
    }
    
    private var isEdge: Bool {
        guard let bundle = url.map({ Bundle(url: $0)! }) else { return false }
        return bundle.bundleIdentifier == "com.microsoft.edgemac"
    }

    private var compiledRegex: Regex<AnyRegexOutput>? {
        return try? Regex(regex).ignoresCase()
    }

    private var attributtedText: AttributedString {
        var string = AttributedString(testUrls)
        guard let compiledRegex else {
            return string
        }

        for line in testUrls.split(separator: "\n") {
            if line.firstMatch(of: compiledRegex) != nil, let range = string.range(of: line) {
                string[range].foregroundColor = .red
            }
        }

        return string
    }

    var body: some View {
        Form {
            Section(
                header: Text("General")
                    .font(.headline)
            ) {
                TextField("Regex:", text: $regex)
                    .font(
                        .system(size: 14)
                    )

                LabeledContent("Test URLs:") {
                    TextEditor(text: $testUrls)
                        .font(
                            .system(size: 14)
                        )
                }

                Text(attributtedText)
                    .font(
                        .system(size: 14)
                    )
            }

            Spacer()
                .frame(height: 32)


            LabeledContent("Application:") {
                Button(action: {
                    openWithPresented.toggle()
                }) {
                    Text("Open with")
                }
                .fileImporter(
                    isPresented: $openWithPresented,
                    allowedContentTypes: [.application]
                ) {
                    if case .success(let url) = $0 {
                        self.url = url
                        // Reset selected profile when changing app
                        self.selectedProfile = nil
                        // Load Chrome profiles if Chrome is selected
                        if isChrome {
                            chromeProfiles = BrowserUtil.getChromeProfiles()
                        }
                        if isEdge {
                            chromeProfiles = BrowserUtil.getEdgeProfiles()
                        }
                    }
                }

                if let bundle = url.map({ Bundle(url: $0)! }) {
                    Text("\(bundle.infoDictionary!["CFBundleName"] as! String)")
                        .padding(.horizontal, 5)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if isChrome && !chromeProfiles.isEmpty {
                LabeledContent("Chrome Profile:") {
                    Picker("Profile", selection: $selectedProfile) {
                        Text("Default")
                            .tag(nil as ChromeProfile?)
                        ForEach(chromeProfiles) { profile in
                            Text(profile.name)
                                .tag(profile as ChromeProfile?)
                        }
                    }
                    .frame(width: 200)
                }
            }
            
            if isEdge && !chromeProfiles.isEmpty {
                LabeledContent("Edge Profile:") {
                    Picker("Profile", selection: $selectedProfile) {
                        Text("Default")
                            .tag(nil as ChromeProfile?)
                        ForEach(chromeProfiles) { profile in
                            Text(profile.name)
                                .tag(profile as ChromeProfile?)
                        }
                    }
                    .frame(width: 200)
                }
            }

            Spacer()
                .frame(height: 32)

            HStack {
                Button(role: .cancel, action: onCancel) {
                    Text("Cancel")
                }

                if rule != nil {
                    Button(role: .destructive, action: onDelete) {
                        Text("Delete")
                    }
                }

                Spacer()

                Button(action: {
                    guard let url else {
                        return
                    }

                    onSave(
                        Rule(
                            regex: regex,
                            app: url,
                            chromeProfile: selectedProfile
                        )
                    )
                }) {
                    Text("Save")
                }
                .disabled(compiledRegex == nil || url == nil)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(minWidth: 500)
        .onAppear {
            regex = rule?.regex ?? ""
            url = rule?.app
            selectedProfile = rule?.chromeProfile
            if isChrome {
                chromeProfiles = BrowserUtil.getChromeProfiles()
            }
            if isEdge {
                chromeProfiles = BrowserUtil.getEdgeProfiles()
            }
        }
    }
}
