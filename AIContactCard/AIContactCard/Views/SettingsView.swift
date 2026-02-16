//
//  SettingsView.swift
//  AIContactCard
//

import SwiftUI

struct SettingsView: View {
    @Environment(CreditManager.self) private var creditManager
    @AppStorage("writeToContacts") private var writeToContacts = false

    var body: some View {
        Form {
            Section("Credits") {
                NavigationLink {
                    CreditsView()
                } label: {
                    LabeledContent("Balance", value: "\(creditManager.balance) credits")
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
