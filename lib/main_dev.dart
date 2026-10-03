import 'bootstrap.dart';
import 'firebase_options.dart';

/// Entry point pinned to the dev Firebase project (eazy-vault-dev).
/// Build with: flutter build web --release -t lib/main_dev.dart
void main() {
  bootstrap(firebaseOptions: DefaultFirebaseOptions.webDev);
}
