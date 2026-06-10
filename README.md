# Building Permit Monitor

A real-time event-driven platform for collecting, processing, enriching, and storing building permit publications of the canton of Zurich.

The system continuously imports building permit data, transforms it into a standardized format, enriches it with geospatial information, and stores it in a searchable PostgreSQL/PostGIS database.

## Documentation

Detailed documentation is available in the [`docs`](docs/) directory in German.

Available resources include:

- Architecture diagrams
- Kafka event flow documentation
- Deployment guides
- Database design
- Module documentation
- Development notes

📚 See: [Project Documentation](docs/README.md)

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
└── docs
```

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
