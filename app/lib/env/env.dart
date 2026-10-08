import 'package:envied/envied.dart';

part 'env.g.dart';

/// Build-time configuration, read from `app/.env`.
///
/// Create `app/.env` from `app/.env.example`, then regenerate:
/// ```
/// dart run build_runner build --delete-conflicting-outputs
/// ```
///
/// The generated `env.g.dart` holds the literal values and is NOT committed,
/// so a fresh clone has to run build_runner once before it will compile.
/// Every field has a default, so a missing `.env` still builds — it just
/// builds against the public endpoints.
///
/// Nothing here is a secret in a web build. The whole bundle ships to the
/// browser, so an RPC key in it is readable by anyone who opens devtools;
/// obfuscation would only make that marginally slower, not harder. Restrict
/// the key by domain at the provider instead — that is the control that
/// actually holds.
@Envied(path: '.env', obfuscate: true)
abstract class Env {
  /// NestJS backend base URL. Empty switches the app to in-memory fixtures.
  @EnviedField(varName: 'API_URL', defaultValue: 'https://api.formation.titalabs.xyz')
  static String apiUrl = _Env.apiUrl;

  /// Solana JSON-RPC endpoint.
  ///
  /// The public one rate-limits per origin, and a browser reaches that far
  /// sooner than the APK does — every balance read goes through here. Use a
  /// dedicated endpoint for anything player-facing.
  @EnviedField(
    varName: 'SOLANA_RPC_URL',
    defaultValue: 'https://api.mainnet-beta.solana.com',
  )
  static String solanaRpcUrl = _Env.solanaRpcUrl;

  /// Websocket endpoint, which has to be the same provider as the RPC above.
  @EnviedField(
    varName: 'SOLANA_WS_URL',
    defaultValue: 'wss://api.mainnet-beta.solana.com',
  )
  static String solanaWsUrl = _Env.solanaWsUrl;
}
