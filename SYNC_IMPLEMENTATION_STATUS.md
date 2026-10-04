# Coaching App: Cloud Sync Implementation Status

This document tracks the progress of migrating the offline SQLite coaching app to a Firebase-synced application. It is designed to provide context for the next developer or AI agent continuing the work.

## Overview of Requirements
- The app must remain **offline-first** (SQLite is the source of truth).
- 2 existing users will uninstall the old app, install the new one, log in, and **import their old database backups**.
- The imported database must automatically be assigned to the logged-in user.
- Changes are tracked via SQLite triggers (`sync_outbox`) and synced in the background.

---

## 🟢 Phase 1: Local Sync Foundation (COMPLETED)
**Goal:** Prepare SQLite to track offline changes.
- [x] DB migration v22 → v23 (`DatabaseHelper`).
- [x] Added `sync_map`, `sync_outbox`, `sync_meta` tables (`SyncSchema`).
- [x] Implemented SQLite `AFTER INSERT/UPDATE/DELETE` triggers for all 10 tables to populate the outbox.
- [x] Created deterministic `sync_id` generation for `fee_records` and `results` to prevent duplicates.
- [x] Added `applying_remote` flag to avoid re-uploading downloaded data.
- [x] Full unit test coverage (`sync_schema_test.dart`).

---

## 🟢 Phase 2: Firebase Setup + Login (COMPLETED)
**Goal:** Implement Authentication and assign local databases to user accounts.
- [x] Created `LoginScreen` (Email/Password & Google Sign-in).
- [x] Created `AuthGate` to protect the app.
- [x] Added `AuthProvider` using `firebase_auth` and `google_sign_in`.
- [x] Created `SessionManager` to bind the local database to the `uid` inside `sync_meta`.
- [x] **Import Logic Overhaul:** Modified `BackupRepositoryImpl.importDatabase` to:
  - Open the imported `.db` file using `DatabaseHelper` to ensure the v22→v23 upgrade runs immediately.
  - Check `owner_uid` inside `sync_meta` to strictly prevent a user from importing someone else's synced database.
  - Safely rollback the DB if the import or upgrade fails.
- [x] Wrote basic `firestore.rules` (User can only read/write their own UID folder).
- [x] Generated `firebase_options.dart`, initialized Firebase in `main.dart`.

---

## 🟢 Phase 3: Upload Sync (COMPLETED)
**Goal:** Upload the `sync_outbox` to Firestore in the background.
- [x] Write Row ↔ Firestore Document mappers for all tables (`SyncMapper`).
- [x] Build `SyncEngine`: reads outbox → batched writes (≤500) → cleans up outbox on success.
- [x] Implement tombstone records for deleted rows.
- [x] Setup `WorkManager` for background periodic syncs.
- [x] Implement quota safety (pause sync on `resource-exhausted`).

---

## 🟢 Phase 4: Restore + Single Active Device (COMPLETED)
**Goal:** Allow users to restore data from the cloud on a fresh install and lock out secondary devices.
- [x] Download user data from Firestore and insert into SQLite in foreign-key order (`SyncRestore`).
- [x] Recompute dependent data like `paid_amount` from `fee_transactions`.
- [x] Implement Session Claim (`sessionId`, `device`) inside `SessionManager`.
- [x] Build device-lock banner (only one phone can edit data at a time to prevent complex merge conflicts) via `SessionLockWrapper`.

---

## 🟢 Phase 5: Security Hardening & Release (COMPLETED)
**Goal:** Production readiness.
- [x] Finalize `firestore.rules` (field validation, session checks).
- [x] Configure Firebase App Check (Play Integrity).
- [x] ProGuard / Release configuration.
