## MODIFIED Requirements

### Requirement: Backend image can be built with Docker
The backend SHALL provide Docker packaging that builds a runnable backend service image and supports tagged publication to `docker.x51.vn/x-ai/expat8-backend`.

#### Scenario: Backend image is built and tagged
- **WHEN** an operator builds backend image with a timestamp tag
- **THEN** Docker produces an image tagged as `docker.x51.vn/x-ai/expat8-backend:<YYYYMMDD.HHMM>`

#### Scenario: Tagged image is pushed to registry
- **WHEN** operator executes push for the tagged image
- **THEN** the registry stores the image and returns a valid digest for deployment tracking

### Requirement: Compose runs backend and PostgreSQL together
The deployment process SHALL recreate `expat8-backend` from `~/deployment/worker-z440` using the image tag updated in `docker-compose.yml`, instead of relying on local repository compose stack.

#### Scenario: Worker-z440 deploy is updated
- **WHEN** operator updates `~/deployment/worker-z440/docker-compose.yml` image tag for `expat8-backend`
- **THEN** `docker compose up -d --force-recreate expat8-backend` from that directory starts container with the new image tag

#### Scenario: Deployment verification passes
- **WHEN** backend redeploy finishes
- **THEN** `docker compose ps expat8-backend` shows healthy status and `curl` against `http://10.113.213.9:18787/health` returns success
