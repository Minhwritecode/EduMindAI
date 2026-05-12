/// Pass at build/run time: `--dart-define=GEMINI_API_KEY=...` (required for AI Tutor, Notebook tools, Analyze).
const String geminiApiKeyIfConfigured = String.fromEnvironment('GEMINI_API_KEY');

/// Flask + MongoDB + ML API (see `app.py`). Android emulator: `http://10.0.2.2:5000`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:5000',
);

const String defaultUserId = String.fromEnvironment(
  'APP_USER_ID',
  defaultValue: 'local',
);
