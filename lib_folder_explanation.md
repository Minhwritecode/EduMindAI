# EduMindAI `lib` Folder Structure Explanation

Here is a breakdown of all the files and directories inside the `lib` folder of your Flutter application based on their names and standard project structures:

## Root `lib` Files
- **`main.dart`**: The entry point of your Flutter application. It sets up the app, initializes global services (like Provider), and defines the initial routing.
- **`splash_screen.dart`**: The initial loading or branding screen shown to the user right after opening the app.
- **`login_page.dart`**: The UI screen handling user authentication (signing in).
- **`signup_page.dart`**: The UI screen handling new user registration.
- **`home_page_visual.dart`**: The main dashboard/home interface where users navigate after successfully logging in.
- **`const.dart`**: Contains constant values used throughout the app, such as predefined colors, text styles, or API keys.
- **`FadeInAnimation.dart`**: A reusable widget or helper class designed to create fade-in visual animations for other UI elements.
- **`gemini_helpers.dart`**: Utility functions dedicated to integrating and interacting with the Gemini AI API.
- **`ai_tutor.dart`**: The UI and logic for an interactive AI tutoring feature or chat interface.
- **`focus_mode_page.dart`**: A screen dedicated to helping users concentrate, potentially including features like a Pomodoro timer or a distraction-free layout.
- **`learning_style_page.dart`**: A questionnaire or input screen where users can assess their specific learning preferences.
- **`learning_style_result_page.dart`**: Displays the customized results and recommendations based on the user's learning style assessment.
- **`schedule_analyze_page.dart`**: A screen that likely analyzes a student's schedule to provide AI-driven time-management feedback.
- **`notebook_tool_screens.dart`**: The UI screens managing the "Notebook" feature, allowing users to view, edit, or interact with their AI-assisted notes.

## Subdirectories
### 1. `lib/state/`
- **`notebook_context_state.dart`**: A `ChangeNotifier` class used for global state management. It holds the shared `_notebookText` and `userId` so that different screens and tools can access and update the user's notebook content synchronously.

### 2. `lib/services/`
- **`notebook_mongo_sync.dart`**: The service layer responsible for handling backend operations, specifically syncing the local notebook data with a MongoDB database.

### 3. `lib/assets/`
- A folder typically reserved for storing local media, fonts, or configuration files that are bundled with the app (though usually, a root-level `assets` folder is used, some structures keep specific code-related assets here).
