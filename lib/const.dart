/// Gemini API key from `--dart-define=GEMINI_API_KEY=...` (overrides `.env` when non-empty).
const String geminiApiKeyIfConfigured = String.fromEnvironment('GEMINI_API_KEY');

/// Set in [main] after `dotenv.load`; use [effectiveGeminiApiKey] elsewhere.
String geminiApiKeyFromDotenv = '';

/// Resolved key: dart-define wins, else `GEMINI_API_KEY` from project-root `.env`.
String get effectiveGeminiApiKey => geminiApiKeyIfConfigured.isNotEmpty
    ? geminiApiKeyIfConfigured
    : geminiApiKeyFromDotenv.trim();

/// `flutter_gemini` defaults to `models/gemini-1.0-pro`, which is no longer available (404). Use a current model.
const String geminiGenerationModel = 'models/gemini-1.5-flash';

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
