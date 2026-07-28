# FinFloat Pro

**Digitronic Services** · Offline Fintech Float Management System

Ek Android app jo aapke poore din ka hisaab rakhta hai — CMS collection, shop services (AEPS/UPI/Transfer/Recharge), counter cash, company wallets, bank deposit charges, aur asli **net profit**.

**100% offline.** Koi server nahi, koi account nahi, koi monthly fee nahi. Saara data aapke phone mein SQLite database mein. Internet sirf Google Drive backup ke liye.

---

## Paisa kaise chalta hai

App ka poora logic isi par bana hai:

| Kaam | Counter Cash | Company Wallet |
|---|---|---|
| **CMS pickup** (customer cash deta) | **+** | **−** |
| **AEPS / UPI cashout** (customer ko cash dete) | **−** | **+** |
| **UPI Transfer / Recharge** | **+** | **−** |
| **CDM / Counter deposit** | **−** | **+** |

Isliye deposit karna padta hai — CMS se cash badhta hai par wallet khaali hota jaata hai.

```
Net Profit = CMS + Shop + Distributor + Manual payouts − Bank deposit charges
```

Bank charges seedha profit se minus hote hain, kyunki wo aapka loss hai.

---

## Features

**Auto mode (app khud calculate karta hai)**
- CMS party ka rate + TDS ek baar feed → har pickup auto
- AEPS/UPI: company payout + customer charge − TDS
- Round-off charge: ₹1500→₹20, ₹1800→₹20, ₹10000→₹100
- UPI Transfer: 1.5% round-off
- Recharge: commission %
- Bank deposit charge: fixed (₹12/txn) ya percent (0.5%)

**Manual mode (aap feed karte hain)**
- Doosre portal ka raat ka payout + TDS + extra income
- **Galat feed ho jaaye to agle din edit kar sakte hain**

**Dual ID support**
- Ek company mein kai ID — RNFi Distributor (auto mode, fund nahi) + Retailer (shop, saara fund)

**Day Start / Day Close**
- Subah: cash in hand + har wallet feed
- Raat: actual cash (difference laal/hara), wallets, poora profit breakup

**Baaki**
- 10 report types → PDF / Excel(CSV) / Print / Share
- Har entry par ⋮ menu → Edit / Delete
- PIN lock (4 ya 6 digit), background mein auto-lock
- Google Drive backup

---

## APK kaise banayein (kuch install nahi karna)

1. GitHub par free account banayein → naya **Public** repository
2. Is folder ki saari files upload karein (`.github` folder bhi — wo chhupa hota hai, File Explorer mein "Hidden items" on karein)
3. **Actions** tab → **Build APK** → **Run workflow**
4. 12-15 minute baad → **Artifacts** → **FinFloatPro-APK** download
5. ZIP kholein → `app-release.apk` phone mein bhejein → install

Ya apne computer par:
```bash
flutter pub get
flutter test          # 25 calculation tests
flutter build apk --release
```

---

## Pehli baar setup (5 minute)

App khulne par PIN banayein, phir **More** tab se:

1. **Companies** → RNFi, Paynearby... (Auto ya Manual mode chunein)
2. **Company IDs** → har company ki ID (Retailer = fund hota hai, Distributor = nahi)
3. **Banks & Charges** → bank + deposit charge rule ⚠️ *zaroori*
4. **Service Rates** → AEPS/UPI ka payout, TDS, charge % ⚠️ *zaroori*
5. **CMS tab** → CMS parties + unka rate/TDS

Rates khaali chhode gaye hain — aap apne actual numbers daalein. Ek baar feed karne ke baad sab auto.

---

## Backup — dono tareeke free

### One-tap (default, abhi kaam karega)
**More → Backup → Google Drive** — ZIP banti hai, share menu khulta hai, aap "Drive" tap karte hain. Koi setup nahi.

### Auto-sync (optional, ~20 min setup)
Roz apne aap upload karwana ho to:

1. [console.cloud.google.com](https://console.cloud.google.com) → free project banayein
2. **Google Drive API** enable karein
3. **OAuth client ID → Android** banayein, package name `com.digitronicservices.finfloat` aur apni SHA-1 key daalein:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   ```
4. `pubspec.yaml` mein `googleapis` + `google_sign_in` add karein aur `lib/services/backup.dart` mein upload function likhein (scope: `drive.appdata`)

Ye sab free hai. Na karein to bhi app poori tarah chalti hai — bas roz ek tap karna padega.

---

## Folder structure

```
lib/
├── main.dart              PIN screen + 7 tabs
├── logic/calc.dart        Saara calculation (pure Dart, testable)
├── data/
│   ├── db.dart            SQLite schema — 15 tables
│   └── repo.dart          Data access (UI kabhi SQL nahi likhta)
├── core/ui.dart           Theme + reusable widgets
├── services/
│   ├── pin.dart           Salted SHA-256 PIN
│   └── backup.dart        ZIP + share
└── screens/               Dashboard, Shop, CMS, Payout, Cash, Reports, More
test/calc_test.dart        25 tests
```

`calc.dart` mein koi Flutter import nahi hai — isliye saare calculation tests bina emulator ke chalte hain.

---

## Do zaroori baatein

**1. PIN bhool gaye to reset nahi hoga.** Koi server hi nahi hai jo reset kare. Kahin likh kar rakhein.

**2. App uninstall karne par PIN reset ho jaata hai.** Android security ke liye encrypted storage wipe kar deta hai, aur PIN backup mein jaata bhi nahi. Reinstall ke baad backup restore karenge to **saara data wapas aayega** — companies, entries, reports sab. Sirf naya PIN banana padega.

---

© Digitronic Services — FinFloat Pro v1.0.0
