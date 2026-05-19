## ADDED Requirements

### Requirement: Backend has ESLint configured
The backend SHALL have ESLint installed as a devDependency with a flat config file (`eslint.config.js`) that enforces baseline code quality rules.

#### Scenario: Running lint script
- **WHEN** a developer runs `npm run lint` in the backend directory
- **THEN** ESLint checks all `src/**/*.js` and `test/**/*.js` files and reports any violations

#### Scenario: Lint passes on current codebase
- **WHEN** ESLint is run after initial configuration
- **THEN** the existing codebase passes with zero errors (warnings are acceptable)

### Requirement: Backend has Prettier configured
The backend SHALL have Prettier installed as a devDependency with a configuration file that matches the existing code style (single quotes, no trailing semicolons policy if applicable).

#### Scenario: Running format check script
- **WHEN** a developer runs `npm run format:check` in the backend directory
- **THEN** Prettier reports which files (if any) do not match the configured style

#### Scenario: Running format fix script
- **WHEN** a developer runs `npm run format` in the backend directory
- **THEN** Prettier reformats all source and test files to match the configured style

### Requirement: Lint and format scripts are defined in package.json
The backend `package.json` SHALL include `lint`, `format`, and `format:check` scripts.

#### Scenario: Scripts are available
- **WHEN** a developer runs `npm run` in the backend directory
- **THEN** `lint`, `format`, and `format:check` are listed as available scripts
