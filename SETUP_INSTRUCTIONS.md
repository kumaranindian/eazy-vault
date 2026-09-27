# EazyVault Setup Instructions

Follow these steps to set up and run the EazyVault application.

## Prerequisites

Ensure you have the following installed:

- **Flutter SDK** (>=3.3.0): [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (comes with Flutter)
- **Node.js** (v16+): [Install Node.js](https://nodejs.org/)
- **Firebase CLI**: Install via npm
- **Git**: [Install Git](https://git-scm.com/)

## Step 1: Clone the Repository

```bash
git clone <repository-url>
cd eazyvault
```

## Step 2: Install Flutter Dependencies

```bash
flutter pub get
```

## Step 3: Firebase Setup

### 3.1 Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 3.2 Login to Firebase

```bash
firebase login
```

### 3.3 Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Ensure Dart global bin is in your PATH.

### 3.4 Configure Firebase

```bash
flutterfire configure
```

- Select or create a Firebase project named "EazyVault"
- Select platforms: **Web** (use spacebar to select)
- This will generate `lib/firebase_options.dart`

### 3.5 Enable Authentication

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** > **Sign-in method**
4. Enable **Email/Password**
5. Enable **Google Sign-In**
   - Add support email
   - Configure authorized domains

### 3.6 Create Firestore Database

1. Navigate to **Firestore Database**
2. Click **Create database**
3. Select **Production mode**
4. Choose a location (closest to your users)

### 3.7 Deploy Firestore Rules and Indexes

```bash
firebase deploy --only firestore
```

### 3.8 Enable Firebase Storage

1. Navigate to **Storage**
2. Click **Get started**
3. Use production mode
4. Choose same location as Firestore

### 3.9 Deploy Storage Rules

```bash
firebase deploy --only storage
```

## Step 4: Generate Code

Run code generation for Freezed, JSON serialization, and Riverpod:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

For development (watch mode):

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Step 5: Run the Application

### For Web (Chrome)

```bash
flutter run -d chrome
```

### For Web (Edge)

```bash
flutter run -d edge
```

### For Production Build

```bash
flutter build web --release
```

## Step 6: Deploy to Firebase Hosting (Optional)

### 6.1 Initialize Hosting

```bash
firebase init hosting
```

- Select existing project
- Public directory: `build/web`
- Configure as SPA: Yes
- Don't overwrite index.html

### 6.2 Build and Deploy

```bash
flutter build web --release
firebase deploy --only hosting
```

## Common Issues and Solutions

### Issue: `firebase_options.dart` not found

**Solution**: Run `flutterfire configure` to generate the file.

### Issue: Build runner errors

**Solution**: 
```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Authentication not working

**Solution**:
1. Verify Firebase Authentication is enabled
2. Check authorized domains in Firebase Console
3. Ensure `firebase_options.dart` is generated correctly

### Issue: Firestore permission denied

**Solution**:
1. Deploy Firestore rules: `firebase deploy --only firestore:rules`
2. Verify user is authenticated
3. Check security rules in Firebase Console

### Issue: Google Sign-In not working on web

**Solution**:
1. Add your domain to authorized domains in Firebase Console
2. For localhost, add `localhost` and `127.0.0.1`
3. Configure OAuth consent screen in Google Cloud Console

## Development Workflow

### 1. Start Code Generation (Watch Mode)

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

Keep this running in a separate terminal during development.

### 2. Run the App

```bash
flutter run -d chrome
```

### 3. Hot Reload

Press `r` in the terminal to hot reload changes.

### 4. Hot Restart

Press `R` in the terminal to hot restart the app.

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── config/             # App configuration
│   ├── constants/          # Constants
│   ├── theme/              # Theme and styling
│   ├── router/             # Navigation
│   ├── services/           # Services (Firebase, Logger)
│   ├── widgets/            # Reusable widgets
│   ├── utils/              # Utilities
│   ├── extensions/         # Dart extensions
│   ├── models/             # Core models
│   └── exceptions/         # Exception classes
└── features/               # Feature modules
    ├── authentication/     # Auth feature
    ├── dashboard/          # Dashboard feature
    ├── accounts/           # Accounts feature
    ├── categories/         # Categories feature
    ├── transactions/       # Transactions feature
    └── settings/           # Settings feature
```

Each feature follows Clean Architecture:
```
feature/
├── data/
│   ├── models/            # Data models
│   ├── datasources/       # Data sources
│   └── repositories/      # Repository implementations
├── domain/
│   └── repositories/      # Repository interfaces
└── presentation/
    ├── pages/             # UI pages
    ├── widgets/           # Feature widgets
    └── providers/         # State management
```

## Code Generation

This project uses code generation for:

- **Freezed**: Immutable models with unions
- **JSON Serializable**: JSON serialization
- **Riverpod Generator**: Provider generation

After modifying files with annotations, run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Testing

### Run All Tests

```bash
flutter test
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### View Coverage Report

```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Linting

The project uses `very_good_analysis` for strict linting.

### Check for Issues

```bash
flutter analyze
```

### Format Code

```bash
dart format .
```

## Environment Variables (Optional)

For different environments (dev, staging, prod), you can:

1. Create multiple Firebase projects
2. Run `flutterfire configure` for each
3. Use build flavors to switch between them

## Useful Commands

```bash
# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Check outdated packages
flutter pub outdated

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
flutter pub run build_runner watch --delete-conflicting-outputs

# Clean generated files
flutter pub run build_runner clean

# Run app in debug mode
flutter run -d chrome

# Run app in profile mode
flutter run -d chrome --profile

# Run app in release mode
flutter run -d chrome --release

# Build for web
flutter build web --release

# Deploy to Firebase
firebase deploy

# View Firebase logs
firebase functions:log
```

## Next Steps

After setup:

1. ✅ Verify Firebase connection
2. ✅ Test authentication flow
3. ✅ Create test account
4. ✅ Explore the dashboard
5. ✅ Add sample data

## Support

For issues:
- Check [Flutter Documentation](https://flutter.dev/docs)
- Check [Firebase Documentation](https://firebase.google.com/docs)
- Check [Riverpod Documentation](https://riverpod.dev/)
- Create an issue in the repository

---

**EazyVault** - Smart Finance Starts Here.
