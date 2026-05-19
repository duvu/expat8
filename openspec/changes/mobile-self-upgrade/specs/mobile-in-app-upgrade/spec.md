## ADDED Requirements

### Requirement: Mobile provides a user-initiated version check
The mobile app SHALL provide a UI entry point accessible from the main navigation drawer that allows the learner to check whether a newer app version is available on the backend.

#### Scenario: User opens upgrade check from drawer
- **WHEN** the learner taps the "Check for updates" item in the navigation drawer
- **THEN** the app opens a screen that displays the current installed version and fetches the latest available version from the backend

#### Scenario: Newer version is available
- **WHEN** the backend returns a latest release whose version_code is greater than the app's compiled version_code
- **THEN** the screen shows the new version name, file size, and a "Download & Install" button

#### Scenario: App is already up to date
- **WHEN** the backend returns a latest release whose version_code is less than or equal to the app's compiled version_code
- **THEN** the screen shows a message indicating the app is already up to date and does not offer a download

#### Scenario: Backend unreachable during version check
- **WHEN** the version check request fails due to network error or backend unavailability
- **THEN** the screen shows an error message and a retry option without crashing

### Requirement: Mobile downloads and installs a new release APK
The mobile app SHALL download the APK binary from the backend and initiate the Android system package installer when the user confirms the upgrade action.

#### Scenario: User taps Download & Install
- **WHEN** the learner taps the download button for an available update
- **THEN** the app downloads the APK file from the backend release download endpoint, shows a progress indicator during download, and upon completion launches the Android package installer intent

#### Scenario: Download fails mid-transfer
- **WHEN** the APK download fails due to network interruption or server error
- **THEN** the app shows an error message indicating the download failed and allows the user to retry

#### Scenario: Install permission not granted
- **WHEN** the Android system does not grant the REQUEST_INSTALL_PACKAGES permission
- **THEN** the app shows a message explaining that install permission is required and offers to open the system settings for the user to grant it

### Requirement: Mobile displays current and available version information
The mobile app SHALL show the currently installed version (name and code) alongside the latest available version on the upgrade check screen.

#### Scenario: Version info displayed on upgrade screen
- **WHEN** the upgrade check screen loads successfully
- **THEN** the screen displays both "Current version: <version_name> (<version_code>)" and "Latest version: <version_name> (<version_code>)" or an up-to-date message
