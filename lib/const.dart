/// Gemini API key from `--dart-define=GEMINI_API_KEY=...` (overrides `.env` when non-empty).
const String geminiApiKeyIfConfigured = String.fromEnvironment('GEMINI_API_KEY');

/// Set in [main] after `dotenv.load`; use [effectiveGeminiApiKey] elsewhere.
String geminiApiKeyFromDotenv = '';

String _stripEnvQuotes(String value) {
  var v = value.trim();
  if (v.length >= 2) {
    final q = v[0];
    if ((q == '"' || q == "'") && v.endsWith(q)) {
      v = v.substring(1, v.length - 1).trim();
    }
  }
  return v;
}

/// Resolved key: dart-define wins, else `GEMINI_API_KEY` from project-root `.env`.
String get effectiveGeminiApiKey {
  final fromDefine = _stripEnvQuotes(geminiApiKeyIfConfigured);
  if (fromDefine.isNotEmpty) return fromDefine;
  return _stripEnvQuotes(geminiApiKeyFromDotenv);
}

/// Retired models (e.g. `gemini-1.5-flash`) return HTTP 404. Use `models/` prefix for flutter_gemini.
const String geminiGenerationModel = 'models/gemini-2.0-flash';

/// Flask + MongoDB + ML API (see `app.py`). Android emulator: `http://10.0.2.2:5000`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:5000',
);

const String defaultUserId = String.fromEnvironment(
  'APP_USER_ID',
  defaultValue: 'local',
);

/// Local placeholder image (no network required on macOS/desktop).
const String profileIconAsset = 'lib/assets/profile_icon.jpg';
