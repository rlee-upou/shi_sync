SHI Sync - Android Build Guide

SHI Sync is a Flutter-based mobile application designed to bridge health telemetry data (Steps, Exercise Minutes, etc.) from mobile devices to the Smart Health Index (SHI) cloud database. This guide provides instructions on how to build the application into an Android Package (APK).

Prerequisites
Before you begin, ensure you have the following installed on your development machine:
- Flutter SDK: Install Flutter (Version ^3.10.1 as per project constraints).
- Android Studio: For the Android SDK, Command-line Tools, and Build Tools.
- Java Development Kit (JDK): Version 11 or 17 is recommended.
- Git: For version control.

Project Setup
Clone the Repository

  git clone [https://github.com/rlee-upou/shi_sync.git]
  cd rlee-upou/shi_sync

Install Dependencies:

  flutter pub get

Configure Environment Variables
The application uses flutter_dotenv to manage Supabase credentials. Create a .env file in the root directory:

  touch .env

Open .env and add your specific project keys:

  SUPABASE_URL=[https://your-project-id.supabase.co](https://your-project-id.supabase.co)
  SUPABASE_ANON_KEY=your-anon-public-key

Note: Ensure the .env file is listed in the assets section of your pubspec.yaml.

Building the APK
To generate a release build that is optimized for performance and minimized in size, run:

  flutter build apk --release

Build Variants
Standard APK: flutter build apk --release (Generates one large file for all architectures).
Split APKs: flutter build apk --split-per-abi (Reduces file size by creating separate APKs for different processor types).

Output Location
Once the build is complete, you can find the APK file here:
build/app/outputs/flutter-apk/app-release.apk

Signing the APK for Deployment
To deploy to the Google Play Store, the APK must be digitally signed with a keystore.

Generate a Keystore
If you don't have one, generate a new keystore file using the keytool command:

  keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

Create a key.properties File
Create a file named key.properties in the android/ folder (this file should be ignored by git). Add the following references:

  storePassword=your-keystore-password
  keyPassword=your-key-password
  keyAlias=upload
  storeFile=/Users/your-username/upload-keystore.jks

Verify Gradle Configuration
Ensure android/app/build.gradle is configured to use these properties for the signingConfigs and buildTypes sections.

Build the Signed APK

  flutter build apk --release

Permissions & Security

This app requires access to sensitive health data. Ensure the following are correctly configured before deployment:
Health Connect: The app is configured to interface with the Android Health Connect API.
Internet: Required for syncing data to the Supabase PostgreSQL backend via SSL/TLS.
Storage: Used for local resident ID persistence via SharedPreferences.

Troubleshooting
Build Failure (SDK Version): If you encounter an error regarding compileSdkVersion, ensure your Android SDK is up to date in Android Studio.
Missing Credentials: If the app crashes on launch, verify that the .env file is present and correctly formatted.
ProGuard/R8: If the release build behaves differently than the debug build, check the android/app/build.gradle for obfuscation settings.

Developed as part of the Smart Health Index (SHI) System.
## Flutter documentations

For help with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
