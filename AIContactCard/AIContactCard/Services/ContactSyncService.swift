//
//  ContactSyncService.swift
//  AIContactCard
//

import Contacts

@MainActor
@Observable
class ContactSyncService {
    var allContacts: [ContactSummary] = []
    var accessDenied: Bool = false
    var errorMessage: String?

    private let store = CNContactStore()

    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            do {
                let granted = try await store.requestAccess(for: .contacts)
                if !granted {
                    accessDenied = true
                    errorMessage = "Contacts access was not granted. Enable it in Settings > Privacy > Contacts."
                }
                return granted
            } catch {
                errorMessage = "Failed to request contacts access: \(error.localizedDescription)"
                return false
            }
        case .denied, .limited, .restricted:
            accessDenied = true
            errorMessage = "Contacts access is denied. Enable it in Settings > Privacy > Contacts."
            return false
        @unknown default:
            accessDenied = true
            errorMessage = "Unexpected contacts authorization status."
            return false
        }
    }

    func fetchAllContacts() {
        guard !accessDenied else { return }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var fetched: [ContactSummary] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let givenName = contact.givenName
                let familyName = contact.familyName

                guard !givenName.isEmpty || !familyName.isEmpty else { return }

                let fullName = [givenName, familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                let summary = ContactSummary(
                    identifier: contact.identifier,
                    fullName: fullName,
                    nickname: contact.nickname,
                    organization: contact.organizationName,
                    jobTitle: contact.jobTitle,
                    emails: contact.emailAddresses.map { $0.value as String },
                    phones: contact.phoneNumbers.map { $0.value.stringValue }
                )
                fetched.append(summary)
            }
            allContacts = fetched
        } catch {
            errorMessage = "Failed to fetch contacts: \(error.localizedDescription)"
        }
    }

    func updateContactNote(identifier: String, note: String) throws {
        let keysToFetch: [CNKeyDescriptor] = [CNContactNoteKey as CNKeyDescriptor]
        let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let mutableContact = contact.mutableCopy() as! CNMutableContact
        mutableContact.note = note
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)
        try store.execute(saveRequest)
    }

    func readContactNote(identifier: String) throws -> String {
        let keysToFetch: [CNKeyDescriptor] = [CNContactNoteKey as CNKeyDescriptor]
        let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        return contact.note
    }
}
