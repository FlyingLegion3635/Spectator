# Spectator

The Official FRC Scouting App for the Flying Legion 3635! Fully public to anyone to use and modify.

---

### Todo/Suggestions/Ideas list
- BYOBE (**B**ring **Y**our **O**wn **B**ack**e**nd)
    - Allow teams to link their own backend on the Official App to allow teams to manage their own data.
- Spectator Dashboard
    - A desktop/web dashboard to allow teams to visualize data they have collected and manage other aspects of their team's Scouting/Settings.
- Publish iOS/iPadOS/macOS App to the Apple App Store
    - We are currently working on this, but it is not yet possible as we are unable to confirm our Educational Account just yet!
- Publish to Google Play Store
    - We are currently working on this, but we aim to publish the app for Apple and Android at the same time.
- Fix the Windows App
    - Originally planned to never exist, but it is currently a work in progress.
- Docker Image/Docker-Compose
    - Easy way to run the app on a server via docker or docker-compose.
- Scouting Auto-Assignments
    - Feature to automatically assign students to teams they will be scouting in matches.
- Remake UI for Match Scouting
    - We are currently aiming to create a new UI for Match Scouting to allow collecting data while visualizing the field.
- Way to sort matches by team
- Way to get match times and current match number
- Way to get match results
- Better Search functionality (Search Events by name or team)
- Sign-in via other Platforms (Discord, Google, etc.)
- *working* Passkey Support
- Team Chat built-in to allow scouters to instantly talk to each other and get updates.
    - Much faster than platforms like Discord in spots with poor internet connections.
- Image capture/upload support for Pit Scouting


- Got a suggestion and want to help/tell us more about it?
    - Please open an issue on the [Issues](https://github.com/Flying-Legion-3635/Spectator/issues) tab. Thanks for your feedback to help this app become better!

---

## Getting Started (For Developers)
### Prerequisites
- Android Studio (Required for Android App Compiling/Testing) *Optional*
- Xcode (Required for iOS App Compiling/Testing) *Optional*
- Dart SDK
- Flutter SDK
- NPM or preferred package manager
- Node.js ```>=18.18.0```
- BlueAlliance API Key, can be found [https://thebluealliance.com/account](https://thebluealliance.com/account) under ```Read API Keys```.
- Server or Service to Host the Backend (Optionally the frontend as well)

#### Server Providers:
- (FREE) [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
    - **RECOMMENDED** Free | Ampere A1 | 24GB DDR3/4 | 4vCores arm64 CPU | 200GB Storage - Upgrading to a ``pay-as-you-go`` account type is required to keep the machine forever.
    - **Rating** | **★★★★☆** | Free and reliable, however complicated to setup and no way to recover if SSH key is lost.
- (PAID/CHEAP) [OVH Cloud](https://ovhcloud.com/) (USA: [OVH US](https://us.ovhcloud.com/))
    - $20/month | Kimsufi (KS-1) Intel Xeon-D 1520 | 32 GB DDR4 ECC | 2x2TB RAID 0 HDD or 2x480 RAID 0 SSD
    - Starting $4.20/month | VPS (VPS-1) 4vCore | 8GB DDR4/5 ECC | 75GB NVME SSD (Flexible, specific specs can be upgraded depending on needs)
    - **Rating** | **★★★☆☆** | Good Pricing for machines, support is poor and VPS servers cannot be recovered if SSH key is lost. (Dedicated Machines can be recovered). VPS servers are often overcrowded and may not be good performance-wise.
- (PAID/CHEAP) [Pyro.host](https://pyro.host?ref=2J41SCCC)
    - Starting $2/month | Eco Virtual Private Servers | 1vCore | 1GB DDR5 | 24GB NVME SSD
    - **RECOMMENDED** $4-6/month | Eco Virtual Private Servers | 2vCore | 2GB DDR5 | 48GB NVME SSD
        - Contact Support to see if they are willing to give more Storage.
    - **Rating** | **★★★★☆** | Pricing is a bit high, but performance is better than OVH's VPS servers and Oracle's Free tier. The support is good and they are willing to help or provide more fine turned specifications for your needs.
#### Static Web Hosting Providers:
- [Netlify](https://www.netlify.com/) - Free for Open Source Projects
- [Vercel](https://vercel.com/) - Free for Open Source Projects
- [Cloudflare Pages](https://pages.cloudflare.com/) - Domain Required **RECOMMENDED** (Faster loading times), if a server is being used, it is recommended that Cloudflare Argo Tunnels to be used to expose the webapp/backend to the internet.
- [GitHub Pages](https://pages.github.com/) - Free for Open Source Projects, Teams/Pro required for private repositories.

---

## Running/Building the App
### Running the Webserver
```bash
flutter run \
  --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1 \
  -d web-server \
  --web-port=8443
```
### Running the App (Options provided to run the app to a different device)
```bash
flutter run --dart-define=SPECTATOR_API_BASE_URL=http://localhost:4000/api/v1
```
### Running the app on specific Devices
These commands build and open the app on specific devices that you may have connected.
```bash
# Running the app in iOS (Can only be run if Xcode is installed)
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d ios
# Running the app in macOS
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d macos
# Running the app in Linux
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d linux
# Running the app in Windows
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d windows
# Running the app in Android (Can only be run with Android Studio)
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d android
# Running the app in Chrome (Chrome needs to be installed)
flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d chrome
```
### Compiling
These commands build the app for distribution. However, this is not generally required to do locally as pre-compiled distributions for all platforms will be available through Github Actions. Compiled versions will appear as artifacts in the Github Actions tab and in the releases tab.
```bash
# Building the app for iOS - Unsigned, use for sideloading (Can only be built if Xcode is installed)
flutter build ios --release --no-codesign --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for iOS - Signed, PAID DEVELOPER ACCOUNT REQUIRED (Can only be built if Xcode is installed)
flutter build ipa --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for macOS (Can only be built while using macOS)
flutter build macOS --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for Linux (Can only be built using Linux)
flutter build linux --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for Windows (Can only be built using Windows)
flutter build windows --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for Android (Can only be built with Android Studio)
flutter build apk --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
# Building the app for Static Web Hosting
flutter build web --release --dart-define=API_BASE_URL=${{API_BASE_URL}}
```
### Installing/Running on Apple Devices (iOS/iPadOS) without a Paid Developer Account
iOS/iPadOS users may have trouble sideloading the app if they have not done it before. An easy way to get the app on their iPhones or iPads is to plug the device into a Mac with Xcode open. After trusting both devices to each other, developer mode can be found in ```Privacy & Security``` > ```Developer Mode``` from which you can enable Developer Mode on the Apple Device. After a restart, re-plug the phone into the Mac, from which you can run the command ```flutter run --dart-define=SPECTATOR_API_BASE_URL=${{API_BASE_URL}} -d ios``` to load the app onto the device for 7 days. (This should be ideally done before competition).

If the provided steps do not work, you can also try [AltStore](https://altstore.io/) (Recomended), which can allow you to sideload apps without a paid developer account. Or [Sideloady](https://sideloadly.io/) to directly load it onto the device without a 3rd party app store.

**NOTE**: Apps expire 7 days after being sideloaded so matter the method, it is required to re-sideload the app before each competition. If a student is using AltStore, the app can be automatically renewed to work for 7 days from the renewal.

---

### Running the Backend
**Running the Backend**
```bash
cd backend
npm install
npm run dev
```

---

### Data Storage (SQL Migration Fork)
Data is stored depending on the backend .env configuration. To allow more flexibility, the backend can be configured to use a variety of different database options.

``DB_TYPE`` Supports ``firestore``, ``sql``, and ``mongo``. ``sql`` options include ``pg`` (PostgreSQL), ``mysql2`` (MySQL/MariaDB), ``better-sqlite3`` (SQLite), and ``tedious`` (MSSQL).
```dotenv
# ./backend/.env.example
DB_TYPE=firestore
```
Database Configuration, depending on what is set in ``DB_TYPE``, the following configuration will be used. ``better-sqlite3`` does not require any configuration besides that ``DB_CLIENT=better-sqlite3``.
```dotenv
# SQL Configuration (When DB_TYPE=sql)
# DB_CLIENT supports pg (PostgreSQL), mysql2 (MySQL/MariaDB), better-sqlite3, tedious (MSSQL)
DB_CLIENT=pg
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=spectator

# MongoDB Configuration (when DB_TYPE=mongo)
MONGO_URI=mongodb://localhost:27017
MONGO_DB_NAME=spectator

# Firestore Configuration (when DB_TYPE=firestore)
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=""
FIREBASE_DATABASE_URL=
```
**NOTE:** Firebase Studio is shutting down and will no longer be available. New users should use Google Antigravity (Not Recommended)

---

### License - <a href="./LICENSE.md">(Creative Commons) CC-BY-NC-SA</a>
This app is primarily created to help FRC teams have a base for their own Custom scouting app or learn more about our own scouting app. We do not mind any forks made by anyone, but please give credit to us! We ask that the app not be published for public use such as an App Store or any public means. Happy scouting :p

<img src="http://mirrors.creativecommons.org/presskit/buttons/88x31/svg/by-nc-sa.svg" alt="Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License Tag (SVG)">