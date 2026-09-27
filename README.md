# EazyVault

**Smart Finance Starts Here.**

A production-ready Personal Finance Management web application built with Flutter and Firebase.

## Features

- 📊 **Dashboard** - Real-time financial overview with charts and summaries
- 💰 **Account Management** - Track multiple accounts (Cash, Savings, Credit Cards, UPI)
- 📝 **Transaction Tracking** - Record income and expenses with detailed categorization
- 🏷️ **Category Management** - Organize transactions with customizable categories
- 🔍 **Search & Filter** - Advanced search and filtering capabilities
- 📱 **Responsive Design** - Optimized for mobile, tablet, and desktop
- 🔐 **Secure Authentication** - Google Sign-In and Email/Password authentication
- 🌙 **Dark Mode** - Full dark theme support

## Tech Stack

### Frontend
- Flutter 3.x
- Material Design 3
- Riverpod (State Management)
- Go Router (Navigation)
- Freezed (Immutable Models)
- FL Chart (Data Visualization)

### Backend
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Hosting
- Firebase Analytics
- Firebase Crashlytics

## Architecture

This project follows **Feature-First + Clean Architecture** principles:

```
lib/
├── core/
│   ├── config/
│   ├── constants/
│   ├── theme/
│   ├── router/
│   ├── services/
│   ├── widgets/
│   ├── utils/
│   └── extensions/
└── features/
    ├── authentication/
    ├── dashboard/
    ├── accounts/
    ├── categories/
    ├── transactions/
    └── settings/
```

Each feature follows a layered structure:
- **Data Layer** - Models, repositories, data sources
- **Domain Layer** - Business logic, entities, use cases
- **Presentation Layer** - UI, widgets, state management

## Getting Started

### Prerequisites

- Flutter SDK (>=3.3.0)
- Firebase CLI
- Node.js (for Firebase)
- Git

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd eazyvault
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
```bash
firebase login
flutterfire configure
```

4. Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

5. Run the application:
```bash
flutter run -d chrome
```

## Firebase Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project named "EazyVault"
3. Enable Google Analytics (optional)

### 2. Enable Authentication

1. Navigate to Authentication > Sign-in method
2. Enable **Email/Password**
3. Enable **Google Sign-In**

### 3. Create Firestore Database

1. Navigate to Firestore Database
2. Create database in production mode
3. Deploy security rules from `firestore.rules`

### 4. Configure Storage

1. Navigate to Storage
2. Get started with default rules
3. Deploy storage rules from `storage.rules`

### 5. Add Web App

1. Project Settings > Add app > Web
2. Register app with nickname "EazyVault Web"
3. Run `flutterfire configure` to generate `firebase_options.dart`

## Database Structure

```
users/{userId}/
├── profile/
├── settings/
├── accounts/{accountId}
├── categories/{categoryId}
└── transactions/{transactionId}
```

This user-scoped architecture:
- Simplifies security rules
- Scales to multi-tenant SaaS
- Isolates user data
- Supports future family sharing

## Code Generation

This project uses code generation for:
- Freezed models
- JSON serialization
- Riverpod providers

Run code generation:
```bash
# Watch mode (recommended during development)
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time build
flutter pub run build_runner build --delete-conflicting-outputs
```

## Testing

Run all tests:
```bash
flutter test
```

Run tests with coverage:
```bash
flutter test --coverage
```

## Deployment

### Deploy to Firebase Hosting

1. Build web app:
```bash
flutter build web --release
```

2. Deploy to Firebase:
```bash
firebase deploy --only hosting
```

## Project Standards

### Code Quality
- ✅ Strict linting with `very_good_analysis`
- ✅ Type-safe models with Freezed
- ✅ Repository pattern for data access
- ✅ Dependency injection with Riverpod
- ✅ Comprehensive error handling
- ✅ Centralized logging

### UI/UX
- ✅ Material Design 3
- ✅ Responsive layouts (mobile, tablet, desktop)
- ✅ Loading states with shimmer effects
- ✅ Empty states
- ✅ Error states with retry actions
- ✅ Confirmation dialogs
- ✅ Toast notifications

### Performance
- ✅ Firestore pagination
- ✅ Lazy loading
- ✅ Provider caching
- ✅ Minimal widget rebuilds
- ✅ Efficient state management

### Security
- ✅ Firebase Authentication
- ✅ User-scoped data access
- ✅ Firestore security rules
- ✅ Input validation
- ✅ Secure credential storage

## Contributing

This is a production-ready application following enterprise standards. All contributions must:
- Follow the existing architecture
- Include tests
- Pass all linting rules
- Include proper documentation
- Maintain type safety

## License

Copyright © 2026 EazyVault. All rights reserved.

## Support

For issues and questions, please create an issue in the repository.

---

**EazyVault** - Smart Finance Starts Here.
