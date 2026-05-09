<p align="center">
  <img src="assets/icon/icon.png" alt="FTP Manager" width="128" />
</p>

<h1 align="center">FTP Manager</h1>

<p align="center">
  A modern, cross-platform FTP client built with Flutter.<br/>
  Browse remote servers, preview media in-app, and manage multiple connections from a single, clean interface.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img alt="Dart" src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img alt="iOS" src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white" />
  <img alt="Android" src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" />
</p>

<p align="center">
  <img alt="Dart SDK" src="https://img.shields.io/badge/Dart_SDK-%5E3.9.2-0175C2?logo=dart&logoColor=white" />
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-iOS%20%7C%20Android-blueviolet" />
  <img alt="Material 3" src="https://img.shields.io/badge/Material_3-757575?logo=materialdesign&logoColor=white" />
  <img alt="State" src="https://img.shields.io/badge/storage-Hive-FFCA28" />
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green" />
  <img alt="PRs welcome" src="https://img.shields.io/badge/PRs-welcome-brightgreen" />
</p>

## Features

- **Multiple connections** — Save and switch between FTP server configurations, stored locally with [Hive](https://pub.dev/packages/hive).
- **File browser** — Navigate remote directories with smooth animations and a directory cache for snappy back-navigation.
- **In-app media** — Preview images and stream videos directly from the server without manually downloading first.
- **Downloads with progress** — Cancellable downloads with a live progress indicator.
- **Search, sort, filter** — Filter by name, sort by name/size/date, and toggle hidden files.
- **Multi-select** — Select multiple files for batch download or deletion, with a confirmation dialog before destructive actions.
- **Adaptive theming** — Light and dark themes with a glassy, gradient-driven UI that follows the system theme.

## Tech stack

- **Flutter** (Dart SDK ^3.9.2)
- [`ftpconnect`](https://pub.dev/packages/ftpconnect) — FTP protocol client
- [`hive`](https://pub.dev/packages/hive) / `hive_flutter` — local config storage
- [`file_picker`](https://pub.dev/packages/file_picker), [`path_provider`](https://pub.dev/packages/path_provider), [`permission_handler`](https://pub.dev/packages/permission_handler)
- [`video_player`](https://pub.dev/packages/video_player), [`percent_indicator`](https://pub.dev/packages/percent_indicator), [`flutter_animate`](https://pub.dev/packages/flutter_animate), [`google_fonts`](https://pub.dev/packages/google_fonts)

## Getting started

### Prerequisites

- Flutter SDK (Dart ^3.9.2)
- Xcode (for iOS) and/or Android Studio (for Android)

### Install

```bash
git clone <your-fork-url>
cd ftp_manager
flutter pub get
```

### Generate Hive adapters

The `Config` model uses generated Hive type adapters. If you change the model, regenerate them:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Run

```bash
flutter run                    # default device
flutter run -d ios             # iOS simulator/device
flutter run -d android         # Android emulator/device
```

### Build

```bash
flutter build apk --release    # Android
./build_ios.sh                 # iOS (see script for signing setup)
```

### App icons

Icons are generated from [`assets/icon/icon.png`](assets/icon/icon.png) via [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons):

```bash
dart run flutter_launcher_icons
```

## Project layout

```
lib/
├── main.dart              # App entrypoint, Hive bootstrap
├── home_page.dart         # Saved connections list
├── configs_list.dart      # Manage FTP configs
├── new_config.dart        # Add/edit a config
├── file_view.dart         # Remote directory browser
├── ftp_file.dart          # FTP entry wrapper
├── ftp_pool.dart          # Connection pooling
├── download_dialog.dart   # Download progress UI
├── image_viewer.dart      # In-app image preview
├── video_viewer.dart      # In-app video player
├── media_cache.dart       # Local media cache
├── theme/                 # Colors and theme data
├── types/                 # Hive models (Config + generated adapter)
└── widgets/               # Reusable UI (glass card, gradient scaffold, …)
```

## Notes

- Credentials are stored locally on-device via Hive. They are not encrypted at rest — treat the app as you would any local password manager and rely on device-level security (passcode, biometrics, full-disk encryption).
- The app is `publish_to: 'none'` and intended for personal use.
