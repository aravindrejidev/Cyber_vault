# Cyber Vault

Offline-first, zero-knowledge personal vault for **passwords**, **encrypted documents** (PDF / images) and **secure notes**. Flutter, Android.

## Build (GitHub Actions only - no local Flutter needed)

1. Push this folder to a GitHub repository (branch `main`).
2. Open the **Actions** tab -> **Build Android APK** (it also runs on every push).
3. When the run is green, open it and download the **cyber-vault-apk** artifact (a zip containing `app-release.apk`).
4. Install the APK (allow "install unknown apps" for your browser/file manager).

The workflow runs `flutter create` to generate the Android project, then copies `android_overlay/` on top of it (manifest, `MainActivity.kt`). Edit `android_overlay/` - never an `android/` folder.

The Flutter version is pinned in `.github/workflows/build.yml`.

## Security design

| Topic | Implementation |
| --- | --- |
| Master password | Never stored. Argon2id (19 MiB, 2 passes) derives a key-encryption key (KEK) in RAM. |
| Master key (MEK) | Random 256-bit key, stored only AES-256-GCM-wrapped by the KEK (`vault_header.json`). Wrong password = authentication failure. Changing the password re-wraps the MEK; data is not re-encrypted. |
| Sub-keys | HKDF-SHA256 derives separate keys for the database and for files. |
| Passwords / notes | SQLCipher (AES-256) database. |
| Documents | AES-256-GCM blobs in the app-private folder, bound to their record id. Viewed from memory only (images: `Image.memory`, PDFs: PDFium via `pdfrx`). No decrypted temp files. |
| Biometrics | Optional. The MEK is kept in `flutter_secure_storage` (Android Keystore) and released after a biometric check. Turning it off deletes the copy. |
| Screen protection | `FLAG_SECURE` set natively in `MainActivity.kt`: no screenshots, no screen recording, blank app-switcher preview. |
| Auto-lock | 30 s in the background, 3 min without touch/typing, or when the app is destroyed. Locking wipes the MEK, closes the database, clears the image cache, the clipboard and the file-picker cache, and closes every open page. |
| Clipboard | Copied passwords are cleared after 30 s (and on lock). |
| Backups | `allowBackup=false`: nothing is copied to cloud/ADB backups. |
| Brute force | Argon2id cost per guess + escalating lockout after 5 wrong attempts. |

## Limitations (be aware)

* If you forget the master password, the data cannot be recovered. There is no reset.
* Dart is garbage collected: key bytes are zeroed on lock, but copies made by the runtime cannot be guaranteed to be wiped. A rooted/compromised device is out of scope.
* Documents are limited to 25 MB each (they are processed in memory).
* While the picker is open the app does not auto-lock; the picker's cache copy is deleted right after import.
* The release APK is signed with the debug key (fine for personal use). Add your own keystore if you want a stable signature.
