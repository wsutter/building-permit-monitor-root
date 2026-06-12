# Module Spec — `platform`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Infrastructure repository (not a Spring Boot app)
> Maps to PRD Epic F (infrastructure half).

## Purpose

Provide the local development infrastructure required to run the whole system: message broker, database, a Kafka UI, and topic-creation scripting. Contains no business logic.

## Provides

- **Apache Kafka** (KRaft mode) — container `bpm-kafka`, port `9092`.
- **PostgreSQL + PostGIS** — container `bpm-postgres`, port `5432` (`postgis/postgis:17-3.5`).
- **Conduktor Console** (Kafka UI) — container `bpm-conduktor-console`, port `8085`.
- **Conduktor PostgreSQL** — container `bpm-conduktor-postgres` (internal, Conduktor's own store).
- Kafka topic-creation script.

## Directory Structure

```
platform
├── compose
│   └── docker-compose.yml      # Kafka (KRaft), PostGIS, Conduktor + its Postgres
├── conduktor
│   └── platform-config.yaml    # Conduktor org/admin/cluster config
└── scripts
    └── create-topics.sh        # creates the 6 topics
```

## Operation

- Start: from `platform/compose`, `podman compose up -d` (or `docker compose up -d`). Status: `podman compose ps`.
- Create topics: from project root, `platform/scripts/create-topics.sh` — creates `building-permit.raw`, `.normalized`, `.enriched` and their `.dlq` variants, each **1 partition, replication factor 1, retention 7 days** (`retention.ms=604800000`), idempotently (`--if-not-exists`).
- PostgreSQL: `localhost:5432`, DB `building_permits`, user/pass `app`/`app`.
- Conduktor Console: `http://localhost:8085`. Local login per `platform/README.md`: `admin@studio-r2.local` / `Admin123!`.

## Networking Notes

- Host clients reach Kafka via `localhost:9092` (PLAINTEXT listener).
- In-network containers (Conduktor) reach Kafka via the internal listener `kafka:29092`.
- KRaft mode: no ZooKeeper; broker + controller roles in one node.

## Acceptance Criteria

- **AC-1:** *Given* `podman compose up -d`, *when* the stack starts, *then* Kafka (9092), PostGIS (5432), and Conduktor Console (8085) are reachable.
- **AC-2:** *Given* a running broker, *when* `create-topics.sh` runs, *then* all six topics exist with the specified partition/replication/retention settings, and re-running is a no-op.
- **AC-3:** *Given* the PostGIS container, *when* `SELECT PostGIS_Version();` runs, *then* a version is returned.

## Constraints

- **Local development only.** Credentials and config are insecure by design; production requires managed infrastructure and secrets.

## Out of Scope / Future

- Kubernetes manifests / Helm charts for GKE (Google Cloud `europe-west6`); `.env.example`; reset/seed scripts (`reset-local-stack.sh`); Schema Registry / Kafka Connect.
