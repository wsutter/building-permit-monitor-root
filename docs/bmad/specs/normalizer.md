# Module Spec — `normalizer`

> BMAD spec · Date: 2026-06-12 · Status: draft · Type: Spring Boot microservice
> Maps to PRD Epic B.

## Purpose

Transform raw, source-specific permit records into a clean, stable internal domain model.

## Responsibilities

- Consume raw events, map them to the normalized schema.
- Classify into canonical category and status vocabularies.
- Compose a usable address and carry the municipality.
- Publish normalized events; route failures to the raw DLQ.

## Behavior (current source)

- `BuildingPermitNormalizer` (`@KafkaListener(topics = KafkaTopics.RAW, groupId = KafkaGroupIDs.NORMALIZER)`) maps each `BuildingPermitRawEvent` via `BuildingPermitRawEventMapper` and publishes `kafkaTemplate.send(KafkaTopics.NORMALIZED, permitId, normalizedEvent)`.
- `BuildingPermitCategoryClassifier` derives a `BuildingPermitCategory` from raw text (e.g. project description).
- The mapper standardizes fields: trims/normalizes text, maps source fields to domain fields, composes `address` as `street + number, ZIP + town`, sets `municipality`, `publishedDate`, `title`, `description`, and `permitId`/`source`/`externalId`.

## Domain Mapping Rules

- `category` ∈ `BuildingPermitCategory` (`UNKNOWN` when undecidable).
- `status` ∈ `BuildingPermitStatus` (`UNKNOWN` when undecidable).
- `address` is built for downstream geocoding; municipality is preserved as geocoding context.
- `permitId` / `externalId` derive from the raw `id:publicationNumber` business key.

## Configuration (`application.yml`)

- Kafka consumer group `normalizer`, String key deserializer + `JacksonJsonDeserializer`, trusted packages `ch.studior2.buildingpermitmonitor.*`.
- Kafka producer: String key + `JacksonJsonSerializer`.
- Imports the central `KafkaDlqConfiguration` from `contracts`.

## Inputs / Outputs

- **In:** `building-permit.raw` (group `normalizer`).
- **Out:** `building-permit.normalized` (key = `permitId`).
- **Error:** `building-permit.raw.dlq` (3 retries, 1 s backoff).

## Acceptance Criteria

- **AC-1:** *Given* a raw event, *when* normalized, *then* `category` and `status` are members of the canonical enums.
- **AC-2:** *Given* address fields in the raw record, *when* normalized, *then* `address` = `street + number, ZIP + town` and `municipality` is set.
- **AC-3:** *Given* a record that fails mapping, *when* processed, *then* it lands on `building-permit.raw.dlq` and the consumer continues.

## Tests (present)

- `BuildingPermitCategoryClassifierTest` (extend with mapper + listener tests as rules grow).

## Run

`mvn spring-boot:run -pl normalizer`.

## Out of Scope / Future

- Richer classification (ML-based), multi-source field mapping, status history.
