# Whear — Smart Closet iOS App
**ESE 3500 · University of Pennsylvania · Spring 2026**
Team: Jefferson Ding, Dimitris Deliakidis, Carly Googel

---

## Overview

Whear is a SwiftUI iOS app that connects to the hardware RFID closet system.
It tracks clothing inventory in real time, suggests outfits for occasions, and
recommends new items to fill wardrobe gaps.

**Architecture:** SwiftUI + MVVM · Firebase (Firestore + Storage + Auth) · ESP32 REST polling

---

## Project Structure

```
Whear/
├── WhearApp.swift                  App entry + Firebase init + UIAppearance
├── ContentView.swift               TabView shell + custom tab bar
├── Info.plist                      Permissions (Camera, Photos, NFC, Local Network)
│
├── Models/
│   ├── ClothingItem.swift          ClothingItem, ClothingStatus, ClothingCategory + mock data
│   ├── Outfit.swift                Outfit, OutfitItem, Occasion, ShopItem + mock data
│   └── RFIDTag.swift               RFIDTag, RFIDInventoryResponse (ESP32 JSON shape)
│
├── ViewModels/
│   └── AppViewModel.swift          Central state, Firebase listener, RFID trigger
│
├── Services/
│   ├── FirebaseService.swift       Firestore CRUD, Storage upload, real-time listener
│   └── RFIDService.swift           ESP32 HTTP polling (/inventory), manual scan, tag register
│
├── Extensions/
│   └── Color+Extensions.swift      Brand palette + hex init
│
└── Views/
    ├── Components/
    │   └── SharedComponents.swift  StatusBadge, ColorSwatch, WhearCard, WhearButton …
    ├── Home/
    │   ├── HomeView.swift          Stats, RFID status card, activity feed, most worn
    │   └── SettingsView.swift      RFID device URL config, connection test
    ├── Closet/
    │   ├── ClosetView.swift        Inventory list/grid, search, filters, alert badge, FAB
    │   ├── AddItemView.swift       Photo capture/picker, item form, color picker, tag scan
    │   ├── ItemDetailView.swift    Full item detail, status update, wear tracking
    │   └── AlertsView.swift        Missing + laundry alerts sheet
    ├── Outfits/
    │   └── OutfitsView.swift       Occasion filter, AI cards, favorites, most worn boards
    ├── Shop/
    │   └── ShopView.swift          Discover grid, complete-look cards, reason filters
    └── Onboarding/
        └── OnboardingView.swift    Welcome → Connect Tags → Done (shown once)
```

---

## Setup Instructions

### 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Product Name: `Whear`
4. Interface: **SwiftUI**, Language: **Swift**
5. Bundle Identifier: `com.yourteam.whear`
6. Save to a folder, then **delete** the auto-generated `ContentView.swift`
   and `[AppName]App.swift` files
7. Drag **all files from this folder** into the Xcode project navigator,
   keeping the folder structure

### 2. Add Firebase SDK (Swift Package Manager)

1. In Xcode: **File → Add Package Dependencies…**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: **Up to Next Major** from `11.0.0`
4. Add these products to the **Whear** target:
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseStorage`

### 3. Configure Firebase

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a project called **Whear**
3. Add an **iOS app** with bundle ID `com.yourteam.whear`
4. Download **`GoogleService-Info.plist`** and drag it into Xcode
   (add to target: ✓ Whear)
5. Enable in Firebase Console:
   - **Authentication → Anonymous** sign-in
   - **Firestore Database** (start in test mode, then apply `firestore.rules`)
   - **Storage** (apply `storage.rules`)

### 4. Configure NFC Capability (for tag scanning)

1. In Xcode → select the **Whear** target → **Signing & Capabilities**
2. Click **+ Capability** → add **Near Field Communication Tag Reading**
3. This requires an **Apple Developer account** (paid)

### 5. Connect to Your ESP32 RFID Reader

At runtime, open the app → **Home → Settings** (gear icon):
- Enter your ESP32's local IP: `http://192.168.1.42`
  or mDNS hostname: `http://whear.local`
- Tap **Save & Connect** — the app polls `/inventory` every 10 seconds

**Expected ESP32 JSON response** at `GET /inventory`:
```json
{
  "tags": [
    { "id": "A1F3", "rssi": -62.5, "lastSeen": "2026-04-07T21:00:00Z", "scanCount": 3 }
  ],
  "scanTime": "2026-04-07T21:00:00Z",
  "scanDuration": 1.2,
  "readerStatus": "ok"
}
```

---

## Feature Summary

| Tab      | Features |
|----------|----------|
| **Home** | Inventory stats, RFID live status, recent activity feed, missing alerts, most-worn items |
| **Closet** | Search + filter by status/category, list & grid view, swipe to update status/delete, pull-to-refresh (triggers RFID scan), alert badge for missing items, FAB to add item |
| **Add Item** | Camera capture or photo library picker, item name/brand/category, 15-color swatch picker, optional RFID tag association (NFC scan or manual entry) |
| **Outfits** | Occasion filter (Date Night / Work / Casual / Formal / Weekend), weather card, AI pick badges, match %, Use Today / Save actions, Favorites board, Most Worn ranking |
| **Shop** | Discover grid, Complete Your Look cards (pairs with closet items), filter by reason (Complete Look / Similar / Trending / Fills a Gap), save/wishlist items |

---

## Mock Data

The app ships with 8 clothing items and 4 outfits as mock data so it works
immediately without Firebase. Once Firebase is configured, real data from
Firestore takes over automatically via the real-time listener in `AppViewModel`.

---

## Swipe Actions (Closet List)

| Direction | Action |
|-----------|--------|
| Swipe left | Mark as Laundry · Delete |
| Swipe right | Mark as In Closet |

---

## RFID Sync Logic

1. App polls `GET /inventory` every 10 seconds (matches `SRS-01`)
2. Tags in the response → status set to **Closet** in Firestore
3. Items with registered `tagId` not seen for 3+ scan cycles are marked **Missing**
   by the ATmega firmware; the app reflects this via the Firestore real-time listener
4. New unregistered tags → user prompted to assign garment metadata via **Add Item**

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| firebase-ios-sdk | 11.x | Auth, Firestore, Storage |

No other third-party dependencies. Pure SwiftUI + UIKit bridges.

---

## TODO / Extensions

- [ ] CoreNFC `NFCTagReaderSession` for live NFC scanning in `TagScanView`
- [ ] `AsyncImage` with Firebase Storage URLs in item rows
- [ ] CloudKit sync as offline-first alternative
- [ ] Widget extension for closet stats on home screen
- [ ] AI outfit generation via Anthropic API call from app
- [ ] Wear tracking: increment `wearCount` when item moves Closet → Worn
