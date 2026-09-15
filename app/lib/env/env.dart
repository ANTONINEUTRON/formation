import 'package:envied/envied.dart';

// part 'env.g.dart';

/// Environment variables loaded from .env file.
///
/// Create a `.env` file in the project root with the required variables.
/// See `.env.example` for the list of required variables.
///
/// After modifying, run:
/// ```
/// dart run build_runner build --delete-conflicting-outputs
/// ```
@Envied(path: '.env')
abstract class Env {
  // // Supabase
  // @EnviedField(varName: 'DB_URL')
  // static const String dbUrl = _Env.dbUrl;

  // @EnviedField(varName: 'DB_ANON_KEY')
  // static const String dbAnonKey = _Env.dbAnonKey;

  // // Google Auth
  // @EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID', defaultValue: '')
  // static const String googleWebClientId = _Env.googleWebClientId;

  // @EnviedField(varName: 'GOOGLE_IOS_CLIENT_ID', defaultValue: '')
  // static const String googleIosClientId = _Env.googleIosClientId;

  // // RevenueCat (Store flavor)
  // @EnviedField(varName: 'REVENUECAT_ANDROID_API_KEY', defaultValue: '')
  // static const String revenueCatAndroidApiKey = _Env.revenueCatAndroidApiKey;

  // @EnviedField(varName: 'REVENUECAT_IOS_API_KEY', defaultValue: '')
  // static const String revenueCatIosApiKey = _Env.revenueCatIosApiKey;
}
