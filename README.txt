CANTEEN APP - PROFESSIONAL MOBILE UI UPDATE

Included:
- lib: polished Flutter source
- backend: latest backend source
- FIREBASE_PUSH_REQUIREMENTS.txt: files needed for closed-app push

Mobile improvements:
- Compact branded app header
- Premium canteen summary/switcher card
- Two-column dashboard KPI layout on phones
- Cleaner spacing, typography, colors and card shadows
- Five-item bottom navigation: Home, Orders, Menu, Pay Later and More
- Offices, History, Reports and Settings moved into a clean More panel
- Existing desktop sidebar and Super Admin navigation preserved

Installation:
1. Replace the lib and backend source folders.
2. Keep your existing backend .env.
3. Run npm install and npm run dev in backend.
4. Run flutter pub get from the Flutter project root.
5. Fully restart the application.

Closed-app push is not included yet because Firebase Android configuration was
not part of the uploaded files. See FIREBASE_PUSH_REQUIREMENTS.txt.
