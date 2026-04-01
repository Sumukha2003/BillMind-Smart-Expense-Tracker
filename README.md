# Bill Scanner + Expense Tracker
### Flutter App with OCR + Gemini AI

---

## Quick Start (3 Steps)

### Step 1 — Add your Gemini API Key
Open `.env` file and replace the placeholder:
```
GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE
```
Get a free API key at: https://aistudio.google.com/app/apikey

---

### Step 2 — Install dependencies
Open terminal in this folder and run:
```bash
flutter pub get
```

---

### Step 3 — Run the app
```bash
flutter run
```

---

## Project Structure
```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── expense.dart             # Expense data model
│   └── expense.g.dart           # Hive generated adapter
├── services/
│   ├── ocr_service.dart         # ML Kit OCR text extraction
│   └── gemini_service.dart      # Gemini AI bill parsing
├── providers/
│   └── expense_provider.dart    # Riverpod state management
├── screens/
│   ├── home_screen.dart         # Dashboard + charts
│   ├── scanner_screen.dart      # Camera + scan flow
│   ├── result_screen.dart       # Review + edit + save
│   └── history_screen.dart      # All expenses + filter
└── widgets/
    └── expense_card.dart        # Reusable expense list item
```

---

## Features
- Scan any bill with camera or gallery
- ML Kit OCR extracts raw text from image
- Gemini AI structures: merchant, amount, date, items, GST
- Edit fields before saving
- Category pie chart on dashboard
- Filter expenses by category
- Delete expenses
- Supports GST number, CGST, SGST extraction

---

## Packages Used
| Package | Purpose |
|---|---|
| `google_mlkit_text_recognition` | On-device OCR |
| `google_generative_ai` | Gemini AI parsing |
| `image_picker` | Camera & gallery |
| `hive_flutter` | Local database |
| `flutter_riverpod` | State management |
| `fl_chart` | Pie chart |
| `flutter_dotenv` | Secure API key |
| `uuid` | Unique expense IDs |
| `intl` | Date & currency formatting |

---

## Troubleshooting

**OCR not working?**
- Ensure good lighting when scanning
- Hold camera steady, ensure text is in focus

**Gemini returns wrong data?**
- Check your API key in `.env`
- Ensure internet connection is active
- Try a clearer image

**Build fails?**
```bash
flutter clean
flutter pub get
flutter run
```

---

## Android Requirements
- `minSdkVersion 21` or higher in `android/app/build.gradle`
- Camera permission granted on device

## iOS Requirements
- iOS 12.0 or higher
- Camera access granted in device settings
