# FinFloat Pro

**Digitronic Services** — offline fintech float management (Android)

100% offline · SQLite · koi server nahi · koi monthly fee nahi

---

## APK kaise banayein

1. Poora project GitHub repo mein upload karein
   (⚠️ **`.github` folder chhupa hota hai** — Windows mein "Hidden items" ON karein)
2. Repo → **Actions** → **Build APK** → **Run workflow**
3. ~10 min baad Summary page se **FinFloatPro-APK** download karein

Build verified on: **Flutter 3.27.4 · Dart 3.6.2 · JDK 17**

---

## Ye project kya karta hai

- **CMS collection** — party se cash pickup, payout − TDS
- **Shop services** — AEPS/UPI cashout, UPI Transfer, DMT, Recharge
- **Do cash box** — Mera Cash (CMS ka) + Counter Cash (staff ka), wallet ek hi
- **Company wallets** — ek company mein kai ID
- **Retailer funding** — Distributor ID se fund, 4 tarike se wapsi
- **Bank charges** — fixed ya percent, ye aapka LOSS hai
- **Net Profit** = Gross income − Bank charges
- **Hindi welcome awaaz** + rakam Hindi shabdon mein

---

## Zaroori technical notes

| Cheez | Kyun |
|---|---|
| `flutter_tts: 4.2.0` (pin, `^` nahi) | 4.2.5+ Kotlin 2.2.20 maangta hai → Flutter 3.27 ke Kotlin 1.8.22 se clash. 4.2.5 ka minSdk 24 bhi hai (hamara 23). |
| Workflow Kotlin → 1.9.24 | Template ka 1.8.22 naye plugins padh nahi paata |
| `TTS_SERVICE` in `<queries>` | Android 11+ par iske bina awaaz **chup-chaap** band rehti hai |
| `minSdk 23` | `flutter_secure_storage` ki zaroorat |
| `withValues` / `withOpacity` nahi | Flutter version ke saath naam badalte hain — `C.fade()` use karein |
| `DropdownButtonFormField` nahi | `value:` param naye versions mein toota — `InputDecorator + DropdownButton` |

---

## Tests

```bash
flutter test --concurrency=1     # 87 tests
```

| File | Kya check karta hai |
|---|---|
| `calc_test.dart` | Charges, CMS payout, shop services, net profit |
| `hindi_test.dart` | Hindi numbers (lakh/crore), greeting, 20k fuzz |
| `db_test.dart` | Asli SQLite — schema, masters, do cash box, retailer funding |
| `migration_test.dart` | v1→v3 upgrade, **purana data safe rehta hai** |
| `widget_test.dart` | MoneyHi, decimal input filter, theme |
| `screens_test.dart` | Banks/Companies/Accounts screens render |
| `retailer_ui_test.dart` | Retailer form + funding dropdown |

**Widget test likhte waqt dhyan rakhein:** `testWidgets` fake-time mein chalta hai —
sqflite ka koi bhi `await` us zone mein poora nahi hota. DB ka kaam hamesha
`runAsync()` ke andar karein (`pumpDb` helper dekhein), warna test hang ho jaata hai.

---

## Pehli baar setup (app mein)

1. **More → Companies** — RNFi, A2Z, Paynearby add karein
2. **More → Company IDs** — har company ki ID
   - A2Z Distributor par **"Kya aap retailer ko funding karte hain?"** → Haan
3. **More → Banks** — charge rule (Indian ₹12 fixed, Axis 0.5%)
4. **More → Service Rates** — AEPS, UPI, DMT ke payout/commission
5. **More → CMS Parties** — har party ka rate + TDS
6. **More → Retailers** — Shyam Mobile Shop waghera, Distributor ID se map karke
