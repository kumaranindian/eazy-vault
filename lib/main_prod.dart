import 'bootstrap.dart';
import 'firebase_options.dart';

/// Entry point pinned to the prod Firebase project (eazy-vault-prod).
/// Build with: flutter build web --release -t lib/main_prod.dart
void main() {
  bootstrap(firebaseOptions: DefaultFirebaseOptions.webProd);
}
