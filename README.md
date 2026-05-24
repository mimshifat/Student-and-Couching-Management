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
*   **Fast & Offline**: Built entirely on top of SQLite, ensuring lighting-fast performance without the need for an internet connection (except for Telegram backups).

## 🛠️ Tech Stack

*   **Framework**: [Flutter](https://flutter.dev/)
*   **State Management**: `provider`
*   **Database**: `sqflite` (SQLite)
*   **Background Tasks**: `workmanager`
*   **Networking**: `http` (for Telegram API)
*   **File Handling**: `file_picker`, `share_plus`

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

## 👨‍💻 Developed By

**Md Mim Shifat**
*   Email: mdshifat.official.05@gmail.com
