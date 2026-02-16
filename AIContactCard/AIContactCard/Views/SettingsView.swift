//
//  SettingsView.swift
//  AIContactCard
//

import SwiftUI

struct SettingsView: View {
    @Environment(CreditManager.self) private var creditManager
    @AppStorage("writeToContacts") private var writeToContacts = false
    @AppStorage("useBYOK") private var useBYOK = false
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section {
                Toggle("Use your own API key", isOn: $useBYOK)
                if useBYOK {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: apiKey) {
                            if apiKey.isEmpty {
                                KeychainHelper.delete(key: "anthropicAPIKey")
                            } else {
                                KeychainHelper.save(key: "anthropicAPIKey", value: apiKey)
                            }
                        }
                }
            } header: {
                Text("API Mode")
            } footer: {
                if useBYOK {
                    Text("API calls are billed directly to your Anthropic account. Credits are not used.")
                } else {
                    Text("API calls use in-app credits.")
                }
            }

            if !useBYOK {
                Section("Credits") {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        LabeledContent("Balance", value: "\(creditManager.balance) credits")
                    }
                }
            }

            Section {
                Toggle("Write summaries to contacts", isOn: $writeToContacts)
            } header: {
                Text("Contacts")
            } footer: {
                Text("When enabled, you can save AI-generated summaries to linked Apple Contacts' notes field.")
            }

            Section("About") {
                LabeledContent("App", value: Bundle.main.appName)
                LabeledContent("Version", value: Bundle.main.appVersion)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            if useBYOK {
                apiKey = KeychainHelper.read(key: "anthropicAPIKey") ?? ""
            }
        }
    }
}

private extension Bundle {
    var appName: String {
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "AI Contact Card"
    }

    var appVersion: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(CreditManager())
}
