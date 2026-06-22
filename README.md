# Building Permit Monitor

A real-time event-driven platform for collecting, processing, enriching, and storing building permit publications of the canton of Zurich.

The system continuously imports building permit data, transforms it into a standardized format, enriches it with geospatial information, and stores it in a searchable PostgreSQL/PostGIS database.

## Documentation

Detailed documentation is available in the [`docs`](docs/) directory.

Available resources include:

- Architecture diagrams
- Kafka event flow documentation
- Deployment guides
- Database design
- Module documentation
- Development notes

📚 See: [Project Documentation](docs/README.md)

## BMad Method

This project's planning and specification artifacts are produced and maintained with the [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD) — a structured, agent-assisted workflow for going from product intent to implementable specs. The BMad artifacts live under [`docs/bmad/`](docs/bmad/) and complement (rather than replace) the detailed engineering docs in [`docs/README.md`](docs/README.md).

### Where to find which artifact

| Artifact | Location | What it is |
| -------- | -------- | ---------- |
| Project Brief | [`docs/bmad/project-brief.md`](docs/bmad/project-brief.md) | Vision, goals, MVP scope, users, constraints |
| PRD | [`docs/bmad/prd.md`](docs/bmad/prd.md) | Functional & non-functional requirements, acceptance criteria |
| Architecture | [`docs/bmad/architecture.md`](docs/bmad/architecture.md) | System design, messaging/persistence design, key decisions |
| Coding Standards | [`docs/bmad/coding-standards.md`](docs/bmad/coding-standards.md) | Conventions every module follows |
| Module Specs | [`docs/bmad/specs/`](docs/bmad/specs/) | Per-module specs: `contracts`, `ingestor`, `normalizer`, `enricher`, `persistence`, `api`, `platform` |
| Backlog & Roadmap | [`docs/bmad/backlog.md`](docs/bmad/backlog.md) | Current-state snapshot, near-term work, tech debt, post-MVP roadmap |

### How to use them

- **Read in this order:** Project Brief → PRD → Architecture → the relevant Module Spec → Backlog. Each links to the others.
- **Source of truth for current state:** the `docs/bmad/` artifacts describe what is actually implemented; where they differ from the older design narrative in `docs/README.md`, the BMad artifacts take precedence (see Backlog item *T-02*).
- **Working a change?** Pick the matching Module Spec for context and acceptance criteria, then check the Backlog for related items.
- **BMad tooling** is installed locally under [`_bmad/`](_bmad/). The method's skills drive the workflow — for example, `bmad-help` (orientation and next step), `bmad-quick-dev` (intent → reviewable spec → code), and `bmad-prd` / `bmad-create-architecture` (create or update planning docs). Run each skill in a fresh context for best results.

## Architecture Overview

The application follows an event-driven microservice architecture based on Apache Kafka.

```text
┌─────────────┐
│  Ingestor   │
└──────┬──────┘
       │
       ▼
building-permit.raw
       │
       ▼
┌─────────────┐
│ Normalizer  │
└──────┬──────┘
       │
       ▼
building-permit.normalized
       │
       ▼
┌─────────────┐
│  Enricher   │
└──────┬──────┘
       │
       ▼
building-permit.enriched
       │
       ▼
┌─────────────┐
│ Persistence │
└──────┬──────┘
       │
       ▼
 PostgreSQL
   + PostGIS
```

## Modules

| Module        | Purpose                                                                     |
| ------------- | --------------------------------------------------------------------------- |
| `contracts`   | Shared event contracts, Kafka topics, consumer groups, common configuration |
| `ingestor`    | Imports building permit data and publishes raw events                       |
| `normalizer`  | Cleans and standardizes permit data                                         |
| `enricher`    | Adds geographic coordinates using Swiss GeoAdmin                            |
| `persistence` | Stores enriched permits in PostgreSQL/PostGIS                               |
| `api`         | Exposes stored permits through a REST query API                             |
| `platform`    | Local development infrastructure (Kafka, PostGIS, Conduktor) and scripts    |

## Event Flow

### Step 1 – Import

The Ingestor reads building permit publications from external sources (currently CSV files).

A `BuildingPermitRawEvent` is created for every imported record.

Published to:

```text
building-permit.raw
```

### Step 2 – Normalize

The Normalizer consumes raw events and converts source-specific data into a standardized domain model.

Published to:

```text
building-permit.normalized
```

### Step 3 – Enrich

The Enricher retrieves additional information from external services.

Current enrichment:

* Swiss GeoAdmin geocoding
* WGS84 coordinates

Published to:

```text
building-permit.enriched
```

### Step 4 – Persist

The Persistence service stores enriched permits in PostgreSQL.

Spatial queries are supported through PostGIS.

## Query API

Once permits are stored, the `api` service exposes them over REST. It is a read-only query layer over PostgreSQL/PostGIS and does not participate in the Kafka pipeline.

Endpoint:

```text
GET /api/building-permits
```

Optional query parameters (applied with parameterized SQL):

| Parameter      | Description                          |
| -------------- | ------------------------------------ |
| `municipality` | Filter by municipality name          |
| `category`     | Filter by permit category            |

Results are ordered by publication date (newest first) and capped at 500 records.

Examples:

```bash
curl http://localhost:8080/api/building-permits
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
curl "http://localhost:8080/api/building-permits?category=RENOVATION"
```

## Kafka Topics

| Topic                        | Description                |
| ---------------------------- | -------------------------- |
| `building-permit.raw`        | Raw imported permit events |
| `building-permit.normalized` | Standardized permit events |
| `building-permit.enriched`   | Geocoded permit events     |

### Dead Letter Queues

| DLQ Topic                        | Consumer    |
| -------------------------------- | ----------- |
| `building-permit.raw.dlq`        | Normalizer  |
| `building-permit.normalized.dlq` | Enricher    |
| `building-permit.enriched.dlq`   | Persistence |

Failed messages are automatically routed to the corresponding Dead Letter Queue.

## Consumer Groups

Consumer groups are centrally defined in the `contracts` module.

```java
public final class KafkaGroupIDs {

    public static final String NORMALIZER = "normalizer";
    public static final String ENRICHER = "enricher";
    public static final String PERSISTENCE = "persistence";

    private KafkaGroupIDs() {}
}
```

## Technology Stack

### Backend

* Java 25
* Spring Boot 4
* Spring Kafka
* Spring Data JPA
* Spring WebFlux

### Messaging

* Apache Kafka

### Database

* PostgreSQL
* PostGIS
* Flyway

### Build

* Maven

### Documentation

* README.md
* Pandoc
* PlantUML

## Project Structure

```text
building-permit-monitor
├── contracts
├── ingestor
├── normalizer
├── enricher
├── persistence
├── api
├── platform
└── docs
```

## Git Flow & CI/CD

This project uses **Git Flow** for branch management and **GitHub Actions** for CI/CD automation.

### Branch Strategy

| Branch Type      | Purpose                                                                                     |
|------------------|---------------------------------------------------------------------------------------------|
| `main`           | Production-ready code. Always reflects the latest stable release.                          |
| `develop`        | Integration branch for features, releases, and hotfixes. Always deployable to staging.     |
| `feature/*`      | New functionality or improvements. Branched from `develop`, merged back via PR.            |
| `release/*`      | Preparation for a new production release. Branched from `develop`, merged to `main`.        |
| `hotfix/*`       | Critical production fixes. Branched from `main`, merged to `main` and `develop`.            |

### CI/CD Automation

GitHub Actions workflows run on every push/PR:
- **Feature branches**: Build, test, lint, and code coverage.
- **Release branches**: Build, test, lint, and deploy to staging.
- **Hotfix branches**: Build, test, lint, and deploy to production.
- **Main/Develop branches**: Build, test, lint, and deploy (production/staging).

Required status checks:
- Build (`mvn clean verify`).
- Lint (`mvn spotless:check`).
- Tests (100% pass).
- Code coverage (80% minimum via JaCoCo).

### Branch Protection

- **`main`**: Require PR review, status checks, signed commits, linear history.
- **`develop`**: Require PR review, status checks, signed commits.

### Getting Started with Git Flow

1. Initialize Git Flow:
   ```bash
git flow init -d
```
2. Create a feature branch:
   ```bash
git flow feature start 3-2-bounding-box-filter
```
3. Push the branch:
   ```bash
git push origin feature/3-2-bounding-box-filter
```
4. Create a PR to `develop` and merge after CI passes.

For more details, see [`docs/bmad/git-flow-ci-cd-spec.md`](docs/bmad/git-flow-ci-cd-spec.md).

## Running the System

### Start Infrastructure

Start Kafka and PostgreSQL.

### Run Database Migrations

```bash
mvn flyway:migrate -pl persistence
```

### Start Services

```bash
mvn spring-boot:run -pl normalizer
```

```bash
mvn spring-boot:run -pl enricher
```

```bash
mvn spring-boot:run -pl persistence
```

```bash
mvn spring-boot:run -pl api
```

### Import Data

```bash
mvn spring-boot:run -pl ingestor
```

## Geospatial Support

The Persistence module stores coordinates using PostGIS-compatible data types.

Example use cases:

* Find permits within a radius
* Display permits on a map
* Perform geographic clustering
* Regional building activity analysis

## Data Pipeline Benefits

* Loosely coupled services
* Independent deployments
* Scalable event processing
* Fault isolation through DLQs
* Easy integration of additional enrichment stages
* Full audit trail through Kafka events

## Future Enhancements

Possible future extensions:

* Additional data providers
* Reverse geocoding
* Permit categorization
* Machine learning classification
* REST API
* Interactive map frontend
* Notification services

## License

This project is licensed under the MIT License.
