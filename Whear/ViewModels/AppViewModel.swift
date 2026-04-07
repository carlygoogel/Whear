import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class AppViewModel: ObservableObject {

    @Published var items: [ClothingItem]      = ClothingItem.mockItems
    @Published var isLoading: Bool            = false
    @Published var alertCount: Int            = 0
    @Published var selectedTab: Int           = 0
    @Published var errorMessage: String?      = nil

    // Unregistered tag state
    /// Exactly one tag in scanner has no matching item → prompt the user to register it
    @Published var pendingRegistrationTagId: String?  = nil
    /// Multiple tags in scanner have no matching item → show an alert
    @Published var showMultipleUnregisteredAlert: Bool = false
    @Published var unregisteredTagIds: [String]        = []

    private var firestoreListener:  ListenerRegistration?
    private var scannerListener:    ListenerRegistration?
    private let firebase = FirebaseService.shared
    private let rfid     = RFIDService.shared

    // MARK: - Computed subsets

    var inCloset:  [ClothingItem] { items.filter { $0.status == .closet  } }
    var inLaundry: [ClothingItem] { items.filter { $0.status == .laundry } }
    var missing:   [ClothingItem] { items.filter { $0.status == .missing } }
    var worn:      [ClothingItem] { items.filter { $0.status == .worn    } }

    // MARK: - Init

    init() {
        alertCount = ClothingItem.mockItems.filter { $0.status == .missing }.count
        Task { await bootstrap() }
    }

    func bootstrap() async {
        do {
            try await firebase.signInAnonymouslyIfNeeded()
            startListeningToItems()
            startListeningToScanner()
            rfid.startPolling()
        } catch {
            errorMessage = "Setup error: \(error.localizedDescription)"
        }
    }

    // MARK: - Listeners

    /// Live updates to the items collection → refreshes the UI list.
    func startListeningToItems() {
        firestoreListener = firebase.listenToItems { [weak self] newItems in
            guard let self else { return }
            if !newItems.isEmpty { self.items = newItems }
            self.alertCount = newItems.filter { $0.status == .missing }.count
        }
    }

    /// Live updates to the scanner collection → triggers reconciliation whenever
    /// the ESP32 writes new scan results.
    func startListeningToScanner() {
        scannerListener = firebase.listenToScanner { [weak self] _ in
            guard let self else { return }
            Task { await self.runReconcile() }
        }
    }

    // MARK: - Reconciliation

    /// Compares scanner ↔ items and handles unregistered tags.
    func runReconcile() async {
        do {
            let result = try await firebase.reconcile()
            handleUnregistered(result.unregistered)
        } catch {
            errorMessage = "Sync error: \(error.localizedDescription)"
        }
    }

    private func handleUnregistered(_ tagIds: [String]) {
        unregisteredTagIds = tagIds
        pendingRegistrationTagId = nil
        showMultipleUnregisteredAlert = false

        switch tagIds.count {
        case 0:
            break
        case 1:
            // Prompt user to register this one new tag
            pendingRegistrationTagId = tagIds[0]
        default:
            // More than one unknown tag — show a generic alert
            showMultipleUnregisteredAlert = true
        }
    }

    // MARK: - RFID manual refresh

    func refreshFromRFID() async {
        await rfid.triggerManualScan()
    }

    // MARK: - Item mutations

    func addItem(_ item: ClothingItem, image: UIImage?) async {
        var newItem = item
        isLoading = true
        defer { isLoading = false }
        do {
            if let img = image {
                newItem.imageUrl = try await firebase.uploadImage(img, for: newItem.id)
            }
            try await firebase.saveItem(newItem)
            // After adding a tagged item, reconcile immediately so status is correct
            if newItem.tagId != nil { await runReconcile() }
        } catch {
            // Optimistic local fallback
            items.insert(newItem, at: 0)
        }
    }

    func updateStatus(_ item: ClothingItem, status: ClothingStatus) async {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].status = status
        try? await firebase.updateItemStatus(item, status: status)
    }

    func deleteItem(_ item: ClothingItem) async {
        items.removeAll { $0.id == item.id }
        do {
            try await firebase.deleteItem(item)
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            if let fresh = try? await firebase.fetchItems() { items = fresh }
        }
    }

    // MARK: - Tag registration flow

    /// Called after the user fills in item details for a pending unregistered tag.
    func registerPendingTag(for item: ClothingItem, image: UIImage?) async {
        await addItem(item, image: image)
        pendingRegistrationTagId = nil
    }

    /// Dismiss the pending registration without assigning (user chose to ignore).
    func dismissPendingTag() {
        pendingRegistrationTagId = nil
    }

    deinit {
        firestoreListener?.remove()
        scannerListener?.remove()
    }
}
