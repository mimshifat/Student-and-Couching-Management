# Coaching Management App

A comprehensive, offline-first Flutter application designed for teachers and coaching centers to manage students, fees, schedules, and exams seamlessly.

## 🚀 Features

*   **Student Management**: Add, edit, and track students. Call students or guardians with a single tap. View detailed student profiles including admission date, academic details, and status (Active/Previous).
*   **Batch Management**: Organize students into batches. Set default monthly fees for batches and manage enrollments.
*   **Fee Tracking**: Generate monthly fee records automatically. Record full or partial payments. See clear overviews of pending dues vs. collected amounts.
*   **Exams & Results**: Schedule exams for specific batches and record marks for each student. Keep track of academic performance.
*   **Routine/Schedule**: Create and manage weekly class routines (Day, Time, Subject, Teacher).
*   **Notes**: Keep quick notes with a built-in notepad feature.
*   **Advanced Dashboard**: Get an at-a-glance view of total active students, monthly collected fees, pending dues, and upcoming routines.
*   **Robust Backup System**:
    *   **Auto-Backup**: Automatically sends a daily backup of your entire database to your personal Telegram via a bot. Runs reliably in the background using `WorkManager`, even when the app is closed.
    *   **Local Export/Import**: Export your SQLite database locally or import a `.db` file to restore your data. Includes worst-case scenario handling (corrupted file detection and automatic original DB rollback).
*   **OTA (Over-The-Air) Updates**: Seamless in-app update mechanism via Firebase Firestore. Users get a prompt to download and install new versions directly from the app.
*   **License Security System**: Device-bound license activation via Firebase. Prevents unauthorized sharing with secure Android ID binding. Works entirely offline after a one-time activation.
*   **Fast & Offline**: Built entirely on top of SQLite, ensuring lighting-fast performance without the need for an internet connection (except for Telegram backups and initial license activation).

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/)
*   **State Management**: `provider`
*   **Database**: `sqflite` (SQLite)
*   **Background Tasks**: `workmanager`
*   **Networking**: `http` (for Telegram API)
*   **File Handling**: `file_picker`, `share_plus`
*   **Security & Licensing**: `firebase_core`, `cloud_firestore`, `flutter_secure_storage`, `android_id`

## 📦 Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/mimshifat/Student-and-Couching-Management.git
    cd Student-and-Couching-Management
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

## ⚙️ Telegram Backup Setup

To enable automated background backups to your Telegram:
1. Open Telegram and search for **BotFather**.
2. Create a new bot using `/newbot` and get your **Bot Token**.
3. Create a Private Channel or Group, and add your bot as an Administrator.
4. Get the **Chat ID** of that channel/group (You can use tools like `@RawDataBot` to find the Chat ID, which usually starts with `-100`).
5. Open the app, go to **Backup & Restore**, enter your Bot Token and Chat ID, and enable Auto-Backup.

## 🔄 OTA Updates Setup

To release a new update to your users automatically:
1. **Update Version:** Bump your version in `pubspec.yaml` (e.g. from `1.0.1` to `1.0.2`).
2. **Update Payload:** Open `payload.json` and update `latest_version`, `build_number`, and `release_notes`.
3. **Build the APK:** Run `flutter build apk --release`.
4. **Rename and Copy:** Go to `build/app/outputs/flutter-apk/`, rename `app-release.apk` to `app-update.bin`, and copy it to the `public/` folder.
5. **Upload to Firebase Hosting:** Run `firebase deploy --only hosting` to upload the APK.
6. **Update Firestore:** Run the automated PowerShell script to push your `payload.json` to Firestore. (Use the `Bypass` flag to avoid Windows execution policy errors):
   ```powershell
   powershell -ExecutionPolicy Bypass -Command ".\deploy_ota.ps1"
   ```
   
   *Troubleshooting Note*: If `firebase deploy` fails with "cannot be loaded because running scripts is disabled", run it via Command Prompt: `cmd.exe /c "firebase deploy --only hosting"`. If `deploy_ota.ps1` gives a token error, try running `cmd.exe /c "firebase projects:list"` to refresh your session!
   
Your users will automatically receive the update prompt the next time they open the app!

## 👨‍💻 Developed By

**Md Mim Shifat**
*   Email: mimshifat5@gmail.com
