## 1. Persist Active Learning Language

- [x] 1.1 Add a dedicated active-learning-language setting key in `mobile/lib/src/data/local_database.dart`
- [x] 1.2 Add repository helpers to load and save the active learning language through app settings
- [x] 1.3 Add or update tests in `mobile/test/local_database_test.dart` and `mobile/test/word_repository_test.dart` covering language preference persistence

## 2. Extend Learning Session State

- [x] 2.1 Expose the active learning language from `LearningSessionController` and load it before the initial proficiency fetch
- [x] 2.2 Add a controller method to change the active learning language, persist it, refresh proficiency, and reload the visible session card state
- [x] 2.3 Add or update tests in `mobile/test/learning_session_controller_test.dart` covering startup restore and language-switch reload behavior

## 3. Add Visible Language Selector UI

- [x] 3.1 Add a prominent language selector control to `mobile/lib/src/ui/learning_screen.dart` that displays the current learning language
- [x] 3.2 Implement the language-picker interaction with readable labels for supported languages and wire it to the controller's language-change method
- [x] 3.3 Add or update widget tests in `mobile/test/learning_screen_test.dart` covering selector visibility and language switching

## 4. Preserve Session Consistency After Switching

- [x] 4.1 Ensure proficiency labels and subsequent card/review requests use the newly selected language immediately after a switch
- [x] 4.2 Validate restored or selected language values against the supported-language list and fall back to the default when invalid
- [ ] 4.3 Run the relevant mobile test suite to verify persistence, controller, and learning-screen behavior end to end