## 1. Mobile exam flow

- [x] 1.1 Remove topic selection from the primary exam entry path and start exams directly from the active learning language
- [x] 1.2 Update `ExamQuestionScreen` so tapping a choice commits the answer and advances immediately
- [x] 1.3 Remove the Next button from the question UI and preserve final-question submission behavior
- [x] 1.4 Ensure the results screen is shown only after the final submit response resolves successfully

## 2. Backend exam generation

- [x] 2.1 Update exam session generation to work from the active language without requiring a topic from the UI flow
- [x] 2.2 Keep response payloads and scoring behavior consistent for the committed answer order
- [x] 2.3 Update backend exam tests for the language-scoped auto-advance flow

## 3. Contract and client updates

- [x] 3.1 Update `contracts/api.md` to reflect the new exam entry flow and any response wording changes
- [x] 3.2 Update the mobile API client and exam models if request or response fields change
- [x] 3.3 Update or add mobile widget tests for auto-advance, final submission, and results handoff

## 4. Verification

- [x] 4.1 Run `cd backend && npm test`
- [x] 4.2 Run `cd mobile && flutter test`
- [ ] 4.3 Manually verify on device that exams advance on answer tap and show results after the final submission
