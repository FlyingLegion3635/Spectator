# Spectator
This is the Official Flying Legion scouting app. The front end should be done, just got to make tweaks as we go. Backend needs to be done.

### Running the App
Running the Webserver
```bash
flutter run \
  --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 \
  -d web-server \
  --web-port=8443
```
Running the App (Options provided to run the app to a different device)
```bash
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1
```
Device-Specific
```bash
# Running the app in iOS
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 -d ios
# Running the app in macOS
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 -d macos
# Running the app in Linux
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 -d linux
# Running the app in Windows
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 -d windows
```
### Running the Backend
**Running the Backend**
```bash
cd backend
npm install
npm run dev
```