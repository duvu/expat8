## 1. Rename and Scaffold

- [x] 1.1 Rename the dashboard app/package/service identifiers from `web-admin` to `expat8-dashboard`
- [x] 1.2 Update the dashboard runtime config and app shell to use the new service name
- [x] 1.3 Add or update docs references so operators use `expat8-dashboard`

## 2. Dashboard Runtime

- [x] 2.1 Keep the server-side DB read helpers working under the renamed dashboard package
- [x] 2.2 Keep backend mutation requests signed with the existing app credential and admin token model
- [x] 2.3 Verify article list, article detail, and vocabulary review pages still render under the new name

## 3. Docker Deployment

- [x] 3.1 Add a Dockerfile for the dashboard service
- [x] 3.2 Extend root `docker-compose.yml` to start `expat8-dashboard` beside `expat8-backend` and PostgreSQL
- [x] 3.3 Add dashboard runtime environment variables for backend URL, database URL, and admin token

## 4. Validation and Rollout

- [x] 4.1 Build the dashboard image/app and confirm it starts successfully
- [x] 4.2 Validate the Compose stack starts backend and dashboard together
- [x] 4.3 Update the change checklist after deployment wiring is verified
