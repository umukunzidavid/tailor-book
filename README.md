# Tailor Book

A Flutter mobile app for a tailor shop: client and order records that work fully offline, deadline reminders, busy-day warnings, and automatic backup to the tailor's own Google account.

## What it does

| Need | How the app handles it |
|---|---|
| Client record | Photo, name, phone and/or email (at least one is required), notes |
| Order record | Date received, deadline, photo of the cloth brought, photo + description of the model to sew, body measurements, extra details, price, advance paid, status |
| Measurements | 16 standard fields (cm) plus custom ones per order; "Copy from last order" for returning clients |
| Easy search | Orders tab: search name, phone, model or notes. Clients tab: name, phone (spaces ignored), email |
| Deadline reminders | Local notifications 2 days, 1 day and on the day; 1 day after a missed deadline |
| Too many orders on one date | Busy day = N or more unfinished orders on a date (default 3, adjustable). Busy days get earlier warnings (5 and 3 days before), a banner on the Orders tab, a "busy day" tag on each order, and a warning while choosing a deadline |
| Offline first | SQLite database and photos live on the phone; nothing needs internet |
| Backup / new phone | Zip of database + photos stored in the hidden app folder of the tailor's own Google Drive. Automatic after changes, when internet returns, and every 15 min as a retry. Restore from Settings after signing in on the new phone |

## Project layout

```
lib/
  main.dart                 app start, wires reminders + auto backup
  models.dart               Client, TailorOrder, date helpers, measurement fields
  db.dart                   SQLite, photo files, search queries, zip export/import
  notifier.dart             reminder scheduling (timezone Africa/Kigali)
  backup.dart               Google Drive backup/restore + automatic SyncService
  settings.dart             busy-day threshold, reminder hour
  widgets.dart              photo picker/viewer, helpers (call, WhatsApp)
  screens/                  home (orders + clients tabs), forms, details, settings
```

## Setup (about 20 minutes)

1. Install Flutter and Android Studio: https://docs.flutter.dev/get-started/install
2. Generate the Android/iOS folders in this directory:
   ```
   cd tailor_book
   flutter create --org rw.tailor --project-name tailor_book .
   flutter pub get
   ```
   (`flutter create .` keeps the `lib/` and `pubspec.yaml` already here.)

### Android changes

`android/app/build.gradle(.kts)`: raise `minSdk` to at least 21 and enable desugaring (required by the notifications plugin):

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
    defaultConfig { minSdk = 23 }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>` (above `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.CAMERA"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
</queries>
```

Inside `<application>` (so reminders survive a phone restart):

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
  </intent-filter>
</receiver>
```

### Google backup (one-time, done by you, the developer)

The tailor never sees any of this; they only tap "Sign in with Google".

1. Go to https://console.cloud.google.com and create a project.
2. Enable the **Google Drive API**.
3. Configure the **OAuth consent screen**; add the scope `.../auth/drive.appdata`. This scope is non-sensitive (the app can only see its own hidden folder, never the tailor's other files). While the app is in "Testing", add each tailor's Gmail as a test user; click **Publish app** to remove that limit.
4. Create an **OAuth client ID** of type *Android*, with package name `rw.tailor.tailor_book` (or whatever you chose) and the SHA-1 of your signing key:
   ```
   cd android && ./gradlew signingReport
   ```
   Add one client per key: the debug key for testing, and the release key (or Play App Signing key) for the published app.
5. Run it: `flutter run`. Build the APK to share: `flutter build apk --release`.

## Honest limitations / next steps

- This code was written without being able to compile it in my workspace (Flutter was not installed), so expect to fix a few small errors or package-version differences on first `flutter run`.
- Backup uploads one full zip each time. Fine for hundreds of photos; for thousands, switch to incremental backup (upload only new photos).
- Restore **replaces** local data with the backup (it does not merge). It asks for confirmation first.
- Single tailor / single Google account. Several staff sharing live data would need a real server database.
- Interface is English only; strings can be moved to Kinyarwanda/French with Flutter's `intl` localization.
- iPhone: the code is cross-platform, but notifications, Google sign-in and camera permissions need extra iOS setup and a Mac to build.
