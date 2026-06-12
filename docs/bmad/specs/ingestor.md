# Module Spec — `ingestor`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Spring Boot microservice
> Pipeline entry point. Maps to PRD Epic A.

## Purpose

Read raw building-permit data from the external Canton ZH open-data source and publish new permits as raw Kafka events, skipping permits already seen.

## Responsibilities

- Poll the configured CSV source on a schedule.
- Parse each record and build a `BuildingPermitRawEvent`.
- Deduplicate against the raw-event registry before publishing.
- Publish new raw events to `building-permit.raw`.

## Behavior (current source)

- `BuildingPermitIngestor` runs on `@Scheduled(cron = "${app.building-permits.ingest-cron}")` (default `0 */1 * * * *`, i.e. every minute).
- Opens the `source-url` stream, reads records via `CsvBuildingPermitRecordReader`, prunes blank/null fields, and converts each payload to `BuildingPermitRawEvent` (Jackson `JsonMapper`).
- For each record, calls `rawEventRegistry.registerIfNew(event.id(), event.publicationNumber())`; publishes via `BuildingPermitRawProducer` only when new, otherwise logs a skip at `INFO`.
- `BuildingPermitRawProducer.send` → `kafkaTemplate.send(KafkaTopics.RAW, externalId, event)`.

## Configuration (`application.yml`)

- `app.building-permits.source-url`: `https://daten.statistik.zh.ch/ogd/daten/ressourcen/KTZH_00002982_00006183.csv`
- `app.building-permits.ingest-cron`: `0 */1 * * * *`
- Kafka producer: String key serializer + `JacksonJsonSerializer` value.
- Datasource configured (PostgreSQL `building_permits`), JPA `ddl-auto: validate`, Flyway disabled — used to reach the dedup registry.
- Actuator: `health, info, metrics`.

## Dependencies

- `contracts` (events, topics), Spring Kafka, OpenCSV/CSV parsing, Jackson.
- **`persistence` registry API** — imports `persistence.api.BuildingPermitRawEventRegistry` for dedup (a deliberate MVP coupling; see `backlog.md` for the decoupling option).

## Inputs / Outputs

- **Input:** Canton ZH OGD CSV (HTTP).
- **Output:** `building-permit.raw` (key = external id). Producer-only — no DLQ consumer config needed.

## Acceptance Criteria

- **AC-1:** *Given* the scheduled trigger, *when* the CSV is read, *then* one `BuildingPermitRawEvent` is created per parsable record with `externalId = id:publicationNumber`.
- **AC-2:** *Given* a permit already in the registry, *when* re-read, *then* it is not republished and a skip is logged.
- **AC-3:** *Given* a payload with blank/null fields, *when* converted, *then* those fields are pruned before publishing.

## Tests (present)

- `BuildingPermitRawProducerTest`, `CsvBuildingPermitRecordReaderTest`, `BuildingPermitIngestorTest`.

## Run

`mvn spring-boot:run -pl ingestor` (requires Kafka, PostgreSQL, and applied migrations).

## Out of Scope / Future

- GPKG ingestion, multiple/multi-canton sources, change-detection beyond new-vs-seen (e.g. updated permits), backoff/retry on source fetch failures.
