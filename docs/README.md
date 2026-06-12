# building-permit-monitor

A Kafka-based streaming application by Studio r2 for processing public building permit and GIS data.

## Project Goal

This project builds a small but realistic event streaming prototype. The application reads public building permit data, detects new or changed permit applications, publishes them as Kafka events, normalizes the data, stores it in PostGIS, and exposes it via a REST API and a reusable Angular map module.

The project is well suited as a private portfolio project on GitHub because it combines several relevant topics:

- Kafka and event streaming
- Spring Boot 4 and Java 25
- public data sources
- geodata and PostGIS
- REST API design
- reusable Angular map module
- Podman and Container Compose
- future extensibility toward a Risk Analyzer and Housing Market Stream

## MVP Scope

The first MVP deliberately uses only Canton of Zurich as the initial data source. The project name remains generic so that additional cantons and data sources can be added later.

### Included in the MVP

The MVP should be capable of:

1. Periodically loading building permit data from Canton of Zurich.
2. Writing raw data as events to Kafka.
3. Normalizing data.
4. Storing events in PostGIS.
5. Providing a REST API.
6. Displaying building permits via an embeddable Angular map module.
7. Detecting new or changed entries.

### Not Included in the MVP

The following topics are deliberately planned for later expansion stages:

- full parcel analysis
- building zone analysis
- noise and flood risk
- real estate price analysis
- machine learning
- multi-canton data integration
- production-ready user management
- complex event schemas with Avro or Protobuf

## Public Data Source

### Primary Data Source

For the MVP we use the public dataset:

- Name: Baugesuche im Kanton Zürich
- Publisher: Statistisches Amt Kanton Zürich
- Portal: https://datenkatalog.statistik.zh.ch/
- Search term: `Baugesuche im Kanton Zürich`
- Formats: CSV, HTML, GPKG

The dataset contains building projects applied for in Canton of Zurich. For the initial phase, CSV is the simplest format because it can be loaded and parsed directly with Java. For later GIS evaluations, GPKG is interesting because it can contain geometries and spatial information in a more structured way.

### Why CSV First?

CSV makes sense at the start because:

- it can be read easily with Java
- no GDAL dependency is required
- the Kafka ingestor can be implemented more quickly
- the data model can be stabilized first

### Why GPKG Later?

GPKG, i.e. GeoPackage, is better suited for GIS because:

- geometries can be included directly
- spatial data is modeled more cleanly
- import into PostGIS can be automated more easily
- more complex spatial queries become possible

## Target Architecture

The application is deliberately built as a microservice architecture from the very beginning. For the MVP this is somewhat more involved than a modular monolith, but it has an important advantage: each service can later be published as its own GitHub project, documented, tested, and developed further.

The services do not communicate directly via synchronous REST calls, but primarily via Kafka events. This keeps the architecture loosely coupled and close to real-world event streaming systems.

The following PlantUML diagram shows the target architecture with data pipeline, read model, API, and the integration of the reusable Angular library module into the Studio-r2 web app.

![Target Architecture](docs/architecture/target-architecture.png)

```text
Open Data CSV / GPKG
        |
        v
ingestor
        |
        v
Kafka topic: building-permit.raw
        |
        v
normalizer
        |
        v
Kafka topic: building-permit.normalized
        |
        v
enricher
        |
        v
Kafka topic: building-permit.enriched
        |
        v
persistence
        |
        v
PostGIS
        |
        v
api
        |
        v
studio-r2 Web-App
        |
        v
web Angular Library
```

The following system context diagram shows the most important external actors, data sources, and system boundaries.

![System Context](docs/architecture/system-context.png)

### Microservice Decomposition

The first sensible decomposition looks like this:

```text
platform
    local infrastructure, Podman Compose, Kubernetes manifests, documentation

contracts
    shared event classes, DTOs, JSON schemas, test fixtures

ingestor
    reads external data sources and publishes raw events

normalizer
    normalizes raw events into a stable domain format

enricher
    adds geospatial data, coordinates, and later risk or zoning data

persistence
    stores enriched events in PostgreSQL/PostGIS

api
    provides data for the frontend and external clients

web
    Angular 19+ library with Leaflet map components, integrated as a dependency into the Studio r2 web app
```

The following container and microservice diagram makes this decomposition concrete.

![Microservice Architecture](docs/architecture/microservice-architecture.png)

### Why Microservices for This Project?

Microservices make sense here because the project naturally consists of a data pipeline. Each step has a clear responsibility:

- Ingestion: fetch data
- Normalization: clean data at the domain level
- Enrichment: extend data geographically
- Persistence: store data
- API: deliver data
- Web: visualize data

This enables small, focused repositories. A recruiter or reviewer can therefore examine individual parts selectively — for example, just the Kafka ingestor or just the PostGIS API.

### Key Architecture Principle

Each microservice should be independently testable locally, while cooperating in the overall system via Kafka and Podman Compose.

This means:

- each service has its own `README.md`
- each service has its own Maven or npm project
- each service has its own tests
- each service can be built as a container
- the platform starts all services together
- the domain events are centrally located in `contracts`

## Target Tech Stack

The project runs under the startup/brand `Studio r2`. The public website is:

```text
https://www.studio-r2.ch
```

The target tech stack is deliberately modern. Not every component needs to be production-ready from the start for the MVP. However, the architecture should be prepared so that the application can later be cleanly extended toward Kubernetes and Google Cloud.

### Backend

- Java 25
- Maven 3.9+
- Spring Boot 4
- Spring for Apache Kafka
- Spring Data JPA
- Spring WebFlux, if reactive HTTP clients or streaming endpoints become useful
- Flyway for database migrations
- Jackson for JSON
- Apache Commons CSV for CSV parsing

### Messaging

- Apache Kafka in KRaft mode
- no ZooKeeper dependency
- topics for raw, normalized, enriched, and dead letter events

### Database

- PostgreSQL
- PostGIS extension
- Flyway migrations
- JPA entities for domain tables
- Hibernate Spatial for PostGIS geometries
- JTS (`org.locationtech.jts`) for `Point` and other geometry types
- native SQL only where PostGIS-specific queries would be less clear with JPA/JPQL

### Frontend

- npm
- Angular 19+
- Angular Library Package rather than a standalone app
- Leaflet for map visualization
- integration as a dependency into the existing Studio-r2 web app

### Local Infrastructure

- Podman
- podman compose or docker-compose-compatible Compose files
- Kafka in KRaft mode
- PostgreSQL/PostGIS
- Conduktor Console as a local Kafka UI

### Deployment Target

- Kubernetes
- Google Cloud
- target region for production-like deployment: `europe-west6` Zurich

For the MVP, a local Compose environment with Podman is sufficient. Kubernetes and Google Cloud will be prepared first, but do not necessarily need to be operated in production in the first step.

### Java Package Naming and Maven Coordinates

The Maven GroupID is identical for all Java modules:

```text
ch.studio-r2.building-permit-monitor
```

This GroupID describes the domain affiliation of the artifacts. Since Java packages and Java 9 module names may not contain hyphens, we use a Java-compatible spelling for them:

```text
ch.studior2.buildingpermitmonitor
```

Each microservice receives its own package beneath this base package:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

Example for the ingestor:

```text
ch.studior2.buildingpermitmonitor.ingestor.BuildingPermitIngestorApplication
ch.studior2.buildingpermitmonitor.ingestor.config
ch.studior2.buildingpermitmonitor.ingestor.kafka
ch.studior2.buildingpermitmonitor.ingestor.source
ch.studior2.buildingpermitmonitor.ingestor.service
```

Example for the API:

```text
ch.studior2.buildingpermitmonitor.api.BuildingPermitApiApplication
ch.studior2.buildingpermitmonitor.api.controller
ch.studior2.buildingpermitmonitor.api.repository
ch.studior2.buildingpermitmonitor.api.model
ch.studior2.buildingpermitmonitor.api.dto
```

### Java 9 Module Strategy

The Java services are structured as Java 9 modules. Each Maven project therefore contains its own `module-info.java`. The module names follow the Java packages and deliberately avoid hyphens.

Recommended module names:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

The Maven GroupID remains:

```text
ch.studio-r2.building-permit-monitor
```

Example for `contracts/src/main/java/module-info.java`:

```java
module ch.studior2.buildingpermitmonitor.contracts {
    requires com.fasterxml.jackson.annotation;

    exports ch.studior2.buildingpermitmonitor.contracts.config;
    exports ch.studior2.buildingpermitmonitor.contracts.event;
    exports ch.studior2.buildingpermitmonitor.contracts.model;
    exports ch.studior2.buildingpermitmonitor.contracts.topic;
}
```

Example for `ingestor/src/main/java/module-info.java`:

```java
module ch.studior2.buildingpermitmonitor.ingestor {
    requires spring.boot;
    requires spring.boot.autoconfigure;
    requires spring.context;
    requires spring.kafka;
    requires org.apache.commons.csv;

    requires ch.studior2.buildingpermitmonitor.contracts;

    opens ch.studior2.buildingpermitmonitor.ingestor to spring.core, spring.beans, spring.context;
}
```

Example for `api/src/main/java/module-info.java`:

```java
module ch.studior2.buildingpermitmonitor.api {
    requires spring.boot;
    requires spring.boot.autoconfigure;
    requires spring.web;
    requires spring.jdbc;
    requires java.sql;

    requires ch.studior2.buildingpermitmonitor.contracts;

    opens ch.studior2.buildingpermitmonitor.api to spring.core, spring.beans, spring.context;
    exports ch.studior2.buildingpermitmonitor.api.dto;
}
```

Note: Spring Boot works with Java modules, but requires targeted `opens` directives for reflection. For this reason, only the Spring component packages are opened, while domain DTOs and event classes are explicitly exported.
## Repository Structure

Since individual microservices are intended to be published separately on GitHub at a later stage, it is advisable not to create a single large repository as the sole structure. A better approach is a combination of multiple service repositories plus a platform repository.

### Recommended GitHub Repositories

```text
studio-r2-building-permit-monitor/
|-- platform
|-- contracts
|-- ingestor
|-- normalizer
|-- enricher
|-- persistence
|-- api
`-- web
```

Here, `platform` is the repository that brings everything together. The other repositories can be presented individually.

### Repository: platform

This repository contains no domain-specific business logic. It describes and starts the overall system.

```text
platform/
|-- README.md
|-- .gitignore
|-- compose/
|   |-- docker-compose.yml
|   `-- .env.example
|-- k8s/
|   |-- kafka/
|   |-- postgres/
|   |-- ingestor/
|   |-- normalizer/
|   |-- enricher/
|   |-- persistence/
|   |-- api/
|   `-- web/
|-- docs/
|   |-- architecture.md
|   |-- data-source.md
|   |-- local-development.md
|   |-- deployment-google-cloud.md
|   `-- event-model.md
`-- scripts/
    |-- create-topics.sh
    `-- reset-local-stack.sh
```

This repository is ideal as the main link in a portfolio.

### Repository: contracts

This repository contains shared event definitions and test data. This means event classes do not need to be copied into every service.

```text
contracts/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- src/
|   |-- main/
|   |   |-- java/
|   |   |   |-- module-info.java
|   |   |   `-- ch/studior2/buildingpermitmonitor/contracts/
|   |   |       |-- config/
|   |   |       |-- event/
|   |   |       |-- model/
|   |   |       `-- topic/
|   |   `-- resources/
|   |       `-- schemas/
|   `-- test/
|       `-- java/
`-- examples/
    |-- raw-building-permit-event.json
    |-- normalized-building-permit-event.json
    `-- enriched-building-permit-event.json
```

Maven coordinates:

```xml
<groupId>ch.studio-r2.building-permit-monitor</groupId>
<artifactId>contracts</artifactId>
<version>0.1.0-SNAPSHOT</version>
```

### Repository: ingestor

```text
ingestor/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- Containerfile
|-- src/
|   |-- main/
|   |   |-- java/
|   |   |   |-- module-info.java
|   |   |   `-- ch/studior2/buildingpermitmonitor/ingestor/
|   |   |       |-- BuildingPermitIngestorApplication.java
|   |   |       |-- config/
|   |   |       |-- kafka/
|   |   |       |-- source/
|   |   |       `-- service/
|   |   `-- resources/
|   |       `-- application.yml
|   `-- test/
`-- docs/
    `-- data-source-kt-zh.md
```

Responsibilities:

- Poll data source
- Download CSV
- Detect new or changed entries
- Write raw events to Kafka

### Repository: normalizer

```text
normalizer/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- Containerfile
|-- src/
|   |-- main/
|   |   `-- java/
|   |       |-- module-info.java
|   |       `-- ch/studior2/buildingpermitmonitor/normalizer/
|   |           |-- BuildingPermitNormalizerApplication.java
|   |           |-- kafka/
|   |           |-- mapper/
|   |           `-- service/
|   `-- test/
```

Responsibilities:

- Consume raw events
- Unify fields
- Normalize categories and status values
- Publish normalized events

### Repository: enricher

```text
enricher/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- Containerfile
|-- src/
|   |-- main/
|   |   `-- java/
|   |       |-- module-info.java
|   |       `-- ch/studior2/buildingpermitmonitor/enricher/
|   |           |-- BuildingPermitEnricherApplication.java
|   |           |-- geocoding/
|   |           |-- kafka/
|   |           `-- service/
|   `-- test/
```

Responsibilities:

- Geocode addresses
- Add coordinates
- Later add zones, noise, flood risk, or proximity to public transport
- Publish enriched events

### Repository: persistence

```text
persistence/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- Containerfile
|-- src/
|   |-- main/
|   |   |-- java/
|   |   |   |-- module-info.java
|   |   |   `-- ch/studior2/buildingpermitmonitor/persistence/
|   |   |       |-- BuildingPermitPersistenceApplication.java
|   |   |       |-- entity/
|   |   |       |-- kafka/
|   |   |       |-- repository/
|   |   |       `-- service/
|   |   `-- resources/
|   |       |-- application.yml
|   |       `-- db/migration/
|   `-- test/
```

Responsibilities:

- Consume enriched events
- Store idempotently in PostgreSQL/PostGIS
- Manage Flyway migrations

### Repository: api

```text
api/
|-- README.md
|-- .gitignore
|-- pom.xml
|-- spotless.xml
|-- Containerfile
|-- src/
|   |-- main/
|   |   `-- java/
|   |       |-- module-info.java
|   |       `-- ch/studior2/buildingpermitmonitor/api/
|   |           |-- BuildingPermitApiApplication.java
|   |           |-- controller/
|   |           |-- dto/
|   |           |-- repository/
|   |           `-- service/
|   `-- test/
```

Responsibilities:

- Provide REST API for the map and external clients
- Filter by municipality, date, category, and bounding box
- Later add streaming endpoints with WebFlux or Server-Sent Events

### Repository: web

```text
web/
|-- README.md
|-- .gitignore
|-- .prettierrc
|-- package.json
|-- ng-package.json
|-- angular.json
|-- projects/
|   `-- building-permit-map/
|       |-- ng-package.json
|       `-- src/
|           |-- public-api.ts
|           `-- lib/
|               |-- building-permit-map.component.ts
|               |-- building-permit-map.service.ts
|               |-- building-permit-map.config.ts
|               `-- model/
`-- dist/
```

Responsibilities:

- Angular 19+ library package rather than a standalone application
- Leaflet map components for building permits
- API client, configuration, and TypeScript models
- Filters and detail popups as reusable components
- Integration as an npm dependency into the existing Studio-r2 web app

### When Separate Repositories Make Sense

Not every microservice needs to be public immediately. For the start, these four repositories are sufficient:

```text
platform
contracts
ingestor
api
```

After that, `normalizer`, `enricher`, `persistence`, and `web` can follow.
## Local Development Environment

### Prerequisites

The following should be installed:

- Java 25
- Maven 3.9+
- npm
- Podman
- podman compose or podman-compose
- optional Angular CLI
- optional psql

Verify:

```bash
java --version
mvn --version
podman --version
podman compose version
```

## Container Compose with Podman

For the MVP we start Kafka, PostGIS, and Conduktor Console locally with Podman. The file is intentionally kept as `docker-compose.yml`, because Compose files are understood by both Docker and Podman. Conduktor replaces the simple Kafka UI and serves as a more convenient interface for topics, consumer groups, messages, and later schema registry or Kafka Connect.

File: `docker-compose.yml`

```yaml
services:
  kafka:
    image: apache/kafka:4.1.0
    container_name: bpm-kafka
    ports:
      - '9092:9092'
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_LISTENERS: PLAINTEXT://:9092,INTERNAL://:29092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092,INTERNAL://kafka:29092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,INTERNAL:PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
    networks:
      - bpm-network

  postgres:
    image: postgis/postgis:17-3.5
    container_name: bpm-postgres
    ports:
      - '5432:5432'
    environment:
      POSTGRES_DB: building_permits
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - bpm-network

  conduktor-postgres:
    image: postgres:16
    container_name: bpm-conduktor-postgres
    environment:
      POSTGRES_DB: conduktor
      POSTGRES_USER: conduktor
      POSTGRES_PASSWORD: change_me
      POSTGRES_HOST_AUTH_METHOD: scram-sha-256
    volumes:
      - conduktor-postgres-data:/var/lib/postgresql/data
    networks:
      - bpm-network

  conduktor-console:
    image: conduktor/conduktor-console:1.45.1
    container_name: bpm-conduktor-console
    ports:
      - '8085:8080'
    volumes:
      - conduktor-data:/var/conduktor
      - ./conduktor/platform-config.yaml:/opt/conduktor/platform-config.yaml:ro
    environment:
      CDK_IN_CONF_FILE: /opt/conduktor/platform-config.yaml
    depends_on:
      - kafka
      - conduktor-postgres
    networks:
      - bpm-network

volumes:
  postgres-data:
  conduktor-postgres-data:
  conduktor-data:

networks:
  bpm-network:
    driver: bridge
```

File: `conduktor/platform-config.yaml`

```yaml
organization:
  name: building-permit-monitor

admin:
  email: admin@studio-r2.ch
  password: admin

database:
  url: postgresql://conduktor:change_me@conduktor-postgres:5432/conduktor

auth:
  local-users:
    - email: user@studio-r2.ch
      password: user

kafka:
  clusters:
    - id: local
      name: local
      bootstrapServers: kafka:29092
```

The internal Kafka listener `kafka:29092` is important. The host continues to use `localhost:9092`, but Conduktor itself runs within the Compose network and must therefore reach Kafka via the service name `kafka`.

Start:

```bash
podman compose up -d
```

Check status:

```bash
podman compose ps
```

The local deployment with Podman Compose looks as follows.

![Local Podman Compose Deployment](docs/architecture/local-podman-compose-deployment.png)

Open Conduktor Console:

```text
http://localhost:8085
```

Login for the local development environment:

```text
admin@studio-r2.ch / admin
```

Test PostgreSQL:

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

Within psql:

```sql
SELECT PostGIS_Version();
```

## Explanation of the Key Kafka and Conduktor Configurations

### Kafka Listener Configuration

```yaml
KAFKA_LISTENERS: PLAINTEXT://:9092,INTERNAL://:29092,CONTROLLER://:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092,INTERNAL://kafka:29092
```

- `PLAINTEXT://:9092`
  - Access from the host system.

- `INTERNAL://:29092`
  - Internal listener for containers within the Compose network.

- `CONTROLLER://:9093`
  - Internal KRaft controller listener.

### KRaft Mode

```yaml
KAFKA_PROCESS_ROLES: broker,controller
KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
```

This configuration runs Kafka without ZooKeeper.

### Why Two PostgreSQL Containers?

- `postgres`
  - Application database with PostGIS.

- `conduktor-postgres`
  - Separate database for the Conduktor Console.

### Kafka Cluster Definition

```yaml
kafka:
  clusters:
    - id: local
      name: local
      bootstrapServers: kafka:29092
```

Conduktor uses `kafka:29092` because the connection is made within the Compose network.

### Verify the PostgreSQL Connection

```bash
podman exec -it bpm-conduktor-postgres   psql -U conduktor -d conduktor -c '\l'
```

## Kafka Topics

For the MVP we use the following topics:

```text
building-permit.raw
building-permit.normalized
building-permit.enriched
building-permit.raw.dlq
building-permit.normalized.dlq
building-permit.enriched.dlq
```

The following may be added later:

```text
building-permit.statistics.daily
building-permit.statistics.municipality
building-permit.alerts
```

The following Kafka event flow shows how Raw, Normalized, and Enriched events travel through the pipeline.

![Kafka Event Flow](docs/architecture/kafka-event-flow.png)

Create topics manually:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.raw \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.normalized \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.enriched \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.raw.dlq \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.normalized.dlq \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic building-permit.enriched.dlq \
  --partitions 1 \
  --replication-factor 1 \
  --config retention.ms=604800000
```

List topics:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

### Dead-Letter Topics and Central Error Handling

The DLQ topics are not used directly by Kafka. They become active only when the Spring Kafka consumers use a shared `DefaultErrorHandler`. This configuration resides in the `contracts` module and can be imported by `normalizer`, `enricher`, and `persistence`.

Routing is based on the original input topic:

```text
building-permit.raw        -> building-permit.raw.dlq
building-permit.normalized -> building-permit.normalized.dlq
building-permit.enriched   -> building-permit.enriched.dlq
```

This keeps it visible at which processing step an event failed. The `exception` parameter of the topic resolver is intentionally not used yet; for the MVP, routing via `record.topic()` is sufficient.

Example in the `contracts` module:

```java
package ch.studior2.buildingpermitmonitor.contracts.config;

import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import java.util.Map;
import org.apache.kafka.common.TopicPartition;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaDlqConfiguration {

    private static final Map<String, String> DLQ_BY_SOURCE_TOPIC = Map.of(
            KafkaTopics.RAW, KafkaTopics.RAW_DLQ,
            KafkaTopics.NORMALIZED, KafkaTopics.NORMALIZED_DLQ,
            KafkaTopics.ENRICHED, KafkaTopics.ENRICHED_DLQ);

    @Bean
    public DefaultErrorHandler kafkaErrorHandler(KafkaTemplate<Object, Object> kafkaTemplate) {
        DeadLetterPublishingRecoverer recoverer = new DeadLetterPublishingRecoverer(
                kafkaTemplate,
                (record, ignored) -> new TopicPartition(
                        DLQ_BY_SOURCE_TOPIC.getOrDefault(record.topic(), record.topic() + ".dlq"),
                        record.partition()));

        return new DefaultErrorHandler(recoverer, new FixedBackOff(1_000L, 3));
    }
}
```

If the package structure of the services does not automatically scan the `contracts` configuration, it is explicitly imported in the Kafka-consuming services:

```java
@Import(KafkaDlqConfiguration.class)
@SpringBootApplication
public class BuildingPermitNormalizerApplication {
    public static void main(String[] args) {
        SpringApplication.run(BuildingPermitNormalizerApplication.class, args);
    }
}
```

The same principle applies to `enricher` and `persistence`. The `ingestor` only produces Raw events and does not require this consumer DLQ configuration.
## Creating the Spring Boot Microservices

This section deliberately replaces the idea of a single `backend` project. The target architecture consists of several small Spring Boot applications that communicate with one another via Kafka. Only `contracts` is a shared Java library. `platform` contains the local infrastructure and is not a Spring Boot application.

### Module Overview

| Module        | Type                        | Spring Boot? | Responsibility                                                                  |
| ------------- | --------------------------- | -----------: | ------------------------------------------------------------------------------- |
| `platform`    | Infrastructure repository   |           No | Podman Compose, Kafka, PostGIS, Conduktor, scripts, documentation               |
| `contracts`   | Java library                |           No | Shared event classes, DTOs, topic constants, JSON schemas                       |
| `ingestor`    | Microservice                |          Yes | Load external data source and publish raw events                                |
| `normalizer`  | Microservice                |          Yes | Consume raw events and normalize them according to the domain model             |
| `enricher`    | Microservice                |          Yes | Add geodata, coordinates, and future risk data                                  |
| `persistence` | Microservice                |          Yes | Consume enriched events and write them to PostGIS                               |
| `api`         | Microservice                |          Yes | Provide REST API for the frontend and external clients                          |
| `web`         | Angular library             |           No | Reusable map module for integration into the studio-r2 web app                  |

### Communication Principle

The services do not call one another synchronously via REST. The domain pipeline runs primarily asynchronously over Kafka.

```text
ingestor
    -> Kafka topic: building-permit.raw

normalizer
    consumes building-permit.raw
    -> Kafka topic: building-permit.normalized

enricher
    consumes building-permit.normalized
    -> Kafka topic: building-permit.enriched

persistence
    consumes building-permit.enriched
    -> PostgreSQL/PostGIS

api
    reads PostgreSQL/PostGIS
    -> REST API

web
    calls REST API
    -> map view
```

This keeps each service small, testable, and independently deployable. Kafka forms the integration layer; PostgreSQL/PostGIS is the query and read model for the API.

### Current Event Flow Including DLQs

```text
Open Data CSV
    |
    v
ingestor
    |
    v
building-permit.raw
    |
    v
normalizer  -- error --> building-permit.raw.dlq
    |
    v
building-permit.normalized
    |
    v
enricher    -- error --> building-permit.normalized.dlq
    |
    v
building-permit.enriched
    |
    v
persistence -- error --> building-permit.enriched.dlq
    |
    v
PostgreSQL/PostGIS
    |
    v
api
    |
    v
web Angular Library
```

The DLQ mapping is defined centrally in the `contracts` module via `KafkaDlqConfiguration`.

### Common Maven Conventions

All Java repositories use the same groupId:

```xml
<groupId>ch.studio-r2.building-permit-monitor</groupId>
```

The artifactIds correspond to the repository names:

```text
contracts
ingestor
normalizer
enricher
persistence
api
```

Java packages do not use hyphens:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

## Shared Root Parent `pom.xml`

A central root parent `pom.xml` is recommended for the entire multi-module project.  
All Java modules inherit from it and thereby use identical versions, plugin configurations, build rules, and testing standards.

Advantages:

- central management of Java and Spring versions
- central management of JUnit 6
- identical Maven plugin versions across all services
- shared Spotless formatting
- central JaCoCo configuration
- shared Surefire/Failsafe configuration
- reproducible builds
- simplified GitHub Actions pipelines
- consistent build quality across all microservices

Recommended structure:

```text
building-permit-monitor/
|-- pom.xml
|-- contracts/
|   `-- pom.xml
|-- ingestor/
|   `-- pom.xml
|-- normalizer/
|   `-- pom.xml
|-- enricher/
|   `-- pom.xml
|-- persistence/
|   `-- pom.xml
`-- api/
    `-- pom.xml
```

### Root Parent `pom.xml`

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="
            http://maven.apache.org/POM/4.0.0
            https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>root</artifactId>
    <version>0.1.0-SNAPSHOT</version>

    <packaging>pom</packaging>

    <name>root</name>

    <!-- ========================================================= -->
    <!-- MODULES                                                   -->
    <!-- ========================================================= -->
    <modules>
        <module>contracts</module>
        <module>ingestor</module>
        <module>normalizer</module>
        <module>enricher</module>
        <module>persistence</module>
        <module>api</module>
    </modules>

    <!-- ========================================================= -->
    <!-- PROPERTIES                                                -->
    <!-- ========================================================= -->
    <properties>
        <!-- Java -->
        <java.version>25</java.version>
        <maven.compiler.release>${java.version}</maven.compiler.release>
        <!-- Encoding -->
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <!-- Spring -->
        <spring.boot.version>4.0.6</spring.boot.version>
        <!-- JUnit -->
        <junit.version>6.0.3</junit.version>
        <!-- Plugins -->
        <maven.compiler.plugin.version>3.14.1</maven.compiler.plugin.version>
        <maven.surefire.plugin.version>3.5.4</maven.surefire.plugin.version>
        <maven.failsafe.plugin.version>3.5.4</maven.failsafe.plugin.version>
        <!-- Coverage -->
        <jacoco.version>0.8.13</jacoco.version>
        <!-- Formatting -->
        <spotless.version>2.46.1</spotless.version>
    </properties>

    <!-- ========================================================= -->
    <!-- DEPENDENCY MANAGEMENT                                     -->
    <!-- ========================================================= -->
    <dependencyManagement>
        <dependencies>
            <!-- Spring Boot -->
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring.boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <!-- JUnit 6 -->
            <dependency>
                <groupId>org.junit</groupId>
                <artifactId>junit-bom</artifactId>
                <version>${junit.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <!-- ========================================================= -->
    <!-- COMMON DEPENDENCIES                                       -->
    <!-- ========================================================= -->
    <dependencies>
        <!-- JUnit -->
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
        <!-- Assertions -->
        <dependency>
            <groupId>org.assertj</groupId>
            <artifactId>assertj-core</artifactId>
            <scope>test</scope>
        </dependency>
        <!-- Mockito -->
        <dependency>
            <groupId>org.mockito</groupId>
            <artifactId>mockito-junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <!-- ========================================================= -->
    <!-- BUILD                                                     -->
    <!-- ========================================================= -->
    <build>
        <!-- ========================================================= -->
        <!-- Plugin Management                                         -->
        <!-- ========================================================= -->
        <pluginManagement>
            <plugins>
                <!-- Compiler -->
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>${maven.compiler.plugin.version}</version>
                    <configuration>
                        <release>${java.version}</release>
                        <compilerArgs>
                            <arg>-parameters</arg>
                        </compilerArgs>
                    </configuration>
                </plugin>
                <!-- Unit Tests -->
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-surefire-plugin</artifactId>
                    <version>${maven.surefire.plugin.version}</version>
                    <configuration>
                        <useModulePath>true</useModulePath>
                        <includes>
                            <include>**/*Test.java</include>
                        </includes>
                    </configuration>
                </plugin>
                <!-- Integration Tests -->
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-failsafe-plugin</artifactId>
                    <version>${maven.failsafe.plugin.version}</version>
                    <configuration>
                        <useModulePath>true</useModulePath>
                        <includes>
                            <include>**/*IT.java</include>
                        </includes>
                    </configuration>
                </plugin>
                <!-- JaCoCo -->
                <plugin>
                    <groupId>org.jacoco</groupId>
                    <artifactId>jacoco-maven-plugin</artifactId>
                    <version>${jacoco.version}</version>
                    <executions>
                        <execution>
                            <goals>
                                <goal>prepare-agent</goal>
                            </goals>
                        </execution>
                        <execution>
                            <id>report</id>
                            <phase>verify</phase>
                            <goals>
                                <goal>report</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
                <!-- Spotless -->
                <plugin>
                    <groupId>com.diffplug.spotless</groupId>
                    <artifactId>spotless-maven-plugin</artifactId>
                    <version>${spotless.version}</version>
                    <configuration>
                        <java>
                            <removeUnusedImports />
                            <importOrder />
                            <formatAnnotations />
                            <palantirJavaFormat>
                                <version>2.72.0</version>
                            </palantirJavaFormat>
                        </java>
                    </configuration>
                </plugin>
                <!-- Spring Boot -->
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>
</project>
```

### Example of a Submodule

Example `ingestor/pom.xml`:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="
            http://maven.apache.org/POM/4.0.0
            https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>ch.studio-r2.building-permit-monitor</groupId>
        <artifactId>building-permit-monitor-parent</artifactId>
        <version>0.1.0-SNAPSHOT</version>
    </parent>

    <artifactId>ingestor</artifactId>

    <dependencies>

        <dependency>
            <groupId>ch.studio-r2.building-permit-monitor</groupId>
            <artifactId>contracts</artifactId>
            <version>${project.version}</version>
        </dependency>

        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka</artifactId>
        </dependency>

    </dependencies>

</project>
```

### Building the Entire Project

The entire project can then be built centrally:

```bash
mvn clean verify
```

Build only a single module:

```bash
mvn -pl ingestor clean verify
```

Build including all dependent modules:

```bash
mvn -pl api -am clean verify
```

### Automatic Code Formatting

Spotless can be used centrally:

```bash
mvn spotless:apply
```

Check only:

```bash
mvn spotless:check
```

### Testing

All unit tests:

```bash
mvn test
```

All tests including integration tests:

```bash
mvn verify
```

### Extended Spotless Configuration

For consistent formatting across all Java modules, `Spotless` is used centrally.  
The configuration combines:

- Google Java Format
- automatic import cleanup
- consistent import ordering
- annotation formatting
- POM sorting
- removal of trailing whitespace
- enforced newline at end of file
- Javadoc formatting

Recommended central configuration in the root parent `pom.xml`:

```xml
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>${spotless.version}</version>

    <configuration>

        <!-- ================================================= -->
        <!-- JAVA                                              -->
        <!-- ================================================= -->

        <java>

            <!-- Google Java Format -->
            <googleJavaFormat>
                <version>1.27.0</version>
                <style>GOOGLE</style>
                <reflowLongStrings>true</reflowLongStrings>
                <formatJavadoc>true</formatJavadoc>
            </googleJavaFormat>

            <!-- Common cleanup -->
            <removeUnusedImports />

            <!-- Import ordering -->
            <importOrder />

            <!-- Annotation formatting -->
            <formatAnnotations />

            <!-- Whitespace -->
            <trimTrailingWhitespace />

            <endWithNewline />

        </java>

        <!-- ================================================= -->
        <!-- POM.XML                                           -->
        <!-- ================================================= -->

        <pom>

            <sortPom>
                <expandEmptyElements>false</expandEmptyElements>
            </sortPom>

        </pom>

    </configuration>

    <!-- ===================================================== -->
    <!-- EXECUTIONS                                            -->
    <!-- ===================================================== -->

    <executions>

        <!-- Verify formatting during build -->
        <execution>
            <id>spotless-check</id>

            <phase>verify</phase>

            <goals>
                <goal>check</goal>
            </goals>
        </execution>

    </executions>

</plugin>
```

#### Run Formatting Locally

Automatic formatting:

```bash
mvn spotless:apply
```

Check only:

```bash
mvn spotless:check
```

#### CI/CD

In GitHub Actions, it is typically sufficient to check only:

```bash
mvn spotless:check
```

This prevents unexpected automatic changes during the build.
## Common Development Standards for All Modules

### Log4J2 Configuration and Setup

All Spring Boot services should log consistently via SLF4J. Log4J2 is used as the concrete logging implementation. This keeps the classes independent of the logging implementation, while format, log level, and appenders can be configured centrally.

Key principle:

```text
Application Code -> SLF4J API -> Log4J2 Runtime
```

The Java classes therefore use `org.slf4j.Logger` and `org.slf4j.LoggerFactory`. Log4J2 is only configured via Maven and `log4j2-spring.xml`.

#### Maven Configuration

In each Spring Boot service, the default logging starter is excluded and `spring-boot-starter-log4j2` is added.

Example for a Spring Boot module:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-logging</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-log4j2</artifactId>
</dependency>
```

If a module uses other Spring Boot starters, for example `spring-boot-starter-web`, `spring-boot-starter-actuator`, or `spring-boot-starter-data-jpa`, `spring-boot-starter-logging` is likewise excluded there if it is pulled in transitively.

#### `log4j2-spring.xml`

File:

```text
src/main/resources/log4j2-spring.xml
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration status="WARN">
    <Properties>
        <Property name="LOG_PATTERN">
            %d{yyyy-MM-dd HH:mm:ss.SSS} %-5level [%t] %logger{36} - %msg%n
        </Property>
    </Properties>

    <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
            <PatternLayout pattern="${LOG_PATTERN}" />
        </Console>
    </Appenders>

    <Loggers>
        <Logger name="ch.studior2.buildingpermitmonitor" level="INFO" additivity="false">
            <AppenderRef ref="Console" />
        </Logger>

        <Logger name="org.apache.kafka" level="WARN" />
        <Logger name="org.springframework.kafka" level="INFO" />
        <Logger name="org.hibernate.SQL" level="WARN" />

        <Root level="INFO">
            <AppenderRef ref="Console" />
        </Root>
    </Loggers>
</Configuration>
```

#### Usage in Code

Service classes define a static logger:

```java
private static final Logger LOG = LoggerFactory.getLogger(MyService.class);
```

Business-relevant events are then logged:

```java
LOG.info("Skipping duplicate raw event: {}:{}", event.id(), event.publicationNumber());
```

Expected business states are normally fine at `INFO`. Technical errors that prevent processing belong at `ERROR`. Very detailed diagnostic information belongs at `DEBUG`.

### `.gitignore`

The Java modules `contracts`, `ingestor`, `normalizer`, `enricher`, `persistence`, and `api` each receive their own `.gitignore`. This prevents IDE files, build artifacts, local logs, or temporary files from being accidentally committed to the repository.

File: `.gitignore`

```gitignore
# Maven build output
target/

# IntelliJ IDEA
.idea/
*.iml
*.iws
*.ipr
out/

# Eclipse / Spring Tools
.classpath
.project
.settings/
.springBeans
.sts4-cache/

# VS Code
.vscode/

# Java / JVM
*.class
*.log
*.pid
*.hprof
hs_err_pid*
replay_pid*

# Test reports and coverage
surefire-reports/
failsafe-reports/
jacoco.exec
coverage/

# Local environment files
.env
.env.*
!.env.example
application-local.yml
application-local.yaml

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.swp
*.swo
```

The same file can be used for `platform`. In addition, local Compose data, generated logs, and temporary volumes should be excluded:

```gitignore
# Local compose / Podman artefacts
compose/.env
compose/.env.local
logs/
volumes/
.tmp/
```

For `web`, Node, Angular, and library build artifacts are additionally ignored:

```gitignore
node_modules/
dist/
build/
.angular/
.cache/
coverage/
.env
.env.*
!.env.example
```

### Code Formatting

For Java modules, `spotless-maven-plugin` is recommended. Spotless is deliberately pragmatic: it runs locally via Maven, works in CI, and can enforce IntelliJ-formatted files independently of personal IDE settings.

Recommended commands:

```text
mvn spotless:apply
mvn spotless:check
```

- `spotless:apply` formats the code locally.
- `spotless:check` verifies during the build that everything is correctly formatted.
- In GitHub Actions, `spotless:check` should run before `mvn verify`.

#### Maven Configuration for All Java Modules

The following plugin block is added to all Java `pom.xml` files. For Spring Boot services it is placed inside `<build><plugins>...</plugins></build>`.

```xml
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>2.46.1</version>
    <configuration>
        <java>
            <googleJavaFormat>
                <version>1.27.0</version>
                <style>GOOGLE</style>
                <reflowLongStrings>true</reflowLongStrings>
                <formatJavadoc>true</formatJavadoc>
            </googleJavaFormat>
            <removeUnusedImports />
            <trimTrailingWhitespace />
            <endWithNewline />
        </java>
        <pom>
            <sortPom>
                <expandEmptyElements>false</expandEmptyElements>
            </sortPom>
        </pom>
    </configuration>
    <executions>
        <execution>
            <goals>
                <goal>check</goal>
            </goals>
            <phase>verify</phase>
        </execution>
    </executions>
</plugin>
```

Optionally, a central `spotless.xml` file can also be placed per Java module if import ordering, license headers, or project-specific formatting rules are to be added later.

#### Frontend Formatting for `web`

For Angular, `prettier` is recommended.

File: `.prettierrc`

```json
{
  "singleQuote": true,
  "semi": true,
  "printWidth": 100,
  "trailingComma": "all"
}
```

Additional npm scripts:

```json
{
  "scripts": {
    "format": "prettier --write .",
    "format:check": "prettier --check ."
  },
  "devDependencies": {
    "prettier": "^3.5.3"
  }
}
```

### Common JUnit 6 Configuration

All Java modules are tested with JUnit 6. JUnit 6 continues to use the Jupiter programming model with `@Test`, `@ParameterizedTest`, `@MethodSource`, `@DisplayName`, `@Nested`, `Arguments.arguments(...)`, and `Named.named(...)`.

The following test dependency is added to all Java modules:

```xml
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>6.0.3</version>
    <scope>test</scope>
</dependency>
```

The Surefire plugin version should be set explicitly for Maven:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.5.4</version>
</plugin>
```

For Spring Boot services, `spring-boot-starter-test` remains useful in addition. It is important that JUnit versions remain consistent. The cleanest approach is dependency management via Spring Boot or, if necessary, via the JUnit BOM.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

Test conventions:

- Test classes end with `Test`.
- Business-case variants are preferably written as `@ParameterizedTest`.
- Data sources have descriptive names, for example `classifyBuildingPermitDescriptions()`.
- Every test has a `@DisplayName`.
- Where multiple business groups exist, `@Nested` is used.
- Test cases use `arguments(named("Description", value), expected)` wherever possible.

## Test Strategy and Example Tests per Module

The following tests are intentionally simple but meaningful. They first test pure logic, mappers, DTOs, topic constants, and SQL/query construction. External infrastructure such as Kafka, PostgreSQL, or HTTP is mocked in the first step or moved to integration tests.

### `contracts`: Event and Topic Tests

File:

```text
KafkaTopicsTest.java
```

```java
package ch.studior2.buildingpermitmonitor.contracts.topic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.util.function.Supplier;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("KafkaTopics")
class KafkaTopicsTest {

    @Nested
    @DisplayName("topic names")
    class TopicNames {

        @ParameterizedTest(name = "{0} -> {1}")
        @MethodSource("topicNames")
        @DisplayName("should expose stable Kafka topic names")
        void shouldExposeStableKafkaTopicNames(Supplier<String> topicSupplier, String expectedTopicName) {
            assertEquals(expectedTopicName, topicSupplier.get());
        }

        static Stream<Arguments> topicNames() {
            return Stream.of(
                    arguments(named("raw topic", (Supplier<String>) () -> KafkaTopics.RAW), "building-permit.raw"),
                    arguments(named("normalized topic", (Supplier<String>) () -> KafkaTopics.NORMALIZED), "building-permit.normalized"),
                    arguments(named("enriched topic", (Supplier<String>) () -> KafkaTopics.ENRICHED), "building-permit.enriched"),
                    arguments(named("raw dead letter topic", (Supplier<String>) () -> KafkaTopics.RAW_DLQ), "building-permit.raw.dlq"),
                    arguments(named("normalized dead letter topic", (Supplier<String>) () -> KafkaTopics.NORMALIZED_DLQ), "building-permit.normalized.dlq"),
                    arguments(named("enriched dead letter topic", (Supplier<String>) () -> KafkaTopics.ENRICHED_DLQ), "building-permit.enriched.dlq"));
        }
    }
}
```

File:

```text
BuildingPermitEventTest.java
```

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("Building permit contract events")
class BuildingPermitEventTest {

    @Nested
    @DisplayName("raw events")
    class RawEvents {

        @ParameterizedTest(name = "{0}")
        @MethodSource("rawEvents")
        @DisplayName("should keep source, external id and payload unchanged")
        void shouldKeepRawEventValues(BuildingPermitRawEvent event, String expectedExternalId) {
            assertEquals("kt-zh", event.source());
            assertEquals(expectedExternalId, event.externalId());
            assertEquals("Thalwil", event.payload().get("gemeinde"));
        }

        static Stream<Arguments> rawEvents() {
            return Stream.of(arguments(
                    named("raw event from Kanton Zürich", new BuildingPermitRawEvent(
                            "kt-zh",
                            "123456",
                            Instant.parse("2026-05-17T18:30:00Z"),
                            Map.of("gemeinde", "Thalwil"))),
                    "123456"));
        }
    }

    @Nested
    @DisplayName("normalized events")
    class NormalizedEvents {

        @ParameterizedTest(name = "{0}")
        @MethodSource("normalizedEvents")
        @DisplayName("should keep stable permit id")
        void shouldKeepStablePermitId(BuildingPermitNormalizedEvent event, String expectedPermitId) {
            assertEquals(expectedPermitId, event.permitId());
            assertEquals(LocalDate.of(2026, 5, 17), event.publishedDate());
        }

        static Stream<Arguments> normalizedEvents() {
            return Stream.of(arguments(
                    named("normalized renovation event", new BuildingPermitNormalizedEvent(
                            "kt-zh:123456",
                            "kt-zh",
                            "123456",
                            "Umbau Wohnung",
                            "Umbau Wohnung, Balkoninstandsetzung",
                            "RENOVATION",
                            "SUBMITTED",
                            "Thalwil",
                            LocalDate.of(2026, 5, 17),
                            "Eisenbahnstrasse 27, 8800 Thalwil")),
                    "kt-zh:123456"));
        }
    }
}
```

### `ingestor`: External-ID and Payload Tests

To make the ingestor easily testable, ID resolution should be extracted into a small class.

File:

```text
ExternalIdResolver.java
```

```java
package ch.studior2.buildingpermitmonitor.ingestor.service;

import java.util.Map;

public class ExternalIdResolver {

    public String determineExternalId(Map<String, String> payload) {
        String explicitId = firstNonBlank(
                payload.get("id"),
                payload.get("ID"),
                payload.get("geschaeftsnummer"),
                payload.get("Geschäftsnummer"));

        if (explicitId != null) {
            return explicitId;
        }

        return Integer.toHexString(payload.toString().hashCode());
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) {
                return value.trim();
            }
        }
        return null;
    }
}
```

File:

```text
ExternalIdResolverTest.java
```

```java
package ch.studior2.buildingpermitmonitor.ingestor.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("ExternalIdResolver")
class ExternalIdResolverTest {

    private final ExternalIdResolver resolver = new ExternalIdResolver();

    @Nested
    @DisplayName("explicit identifiers")
    class ExplicitIdentifiers {

        @ParameterizedTest(name = "{0}")
        @MethodSource("payloadsWithExplicitIds")
        @DisplayName("should prefer an explicit source identifier")
        void shouldPreferExplicitSourceIdentifier(Map<String, String> payload, String expectedExternalId) {
            assertEquals(expectedExternalId, resolver.determineExternalId(payload));
        }

        static Stream<Arguments> payloadsWithExplicitIds() {
            return Stream.of(
                    arguments(named("lowercase id", Map.of("id", "123456")), "123456"),
                    arguments(named("uppercase ID", Map.of("ID", "ABC-42")), "ABC-42"),
                    arguments(named("German business number", Map.of("Geschäftsnummer", "BG-2026-1")), "BG-2026-1"));
        }
    }

    @Nested
    @DisplayName("fallback identifiers")
    class FallbackIdentifiers {

        @ParameterizedTest(name = "{0}")
        @MethodSource("payloadsWithoutExplicitIds")
        @DisplayName("should create a deterministic fallback identifier")
        void shouldCreateDeterministicFallbackIdentifier(Map<String, String> payload) {
            String first = resolver.determineExternalId(payload);
            String second = resolver.determineExternalId(payload);

            assertFalse(first.isBlank());
            assertEquals(first, second);
        }

        static Stream<Arguments> payloadsWithoutExplicitIds() {
            return Stream.of(arguments(named("payload without id", Map.of(
                    "gemeinde", "Thalwil",
                    "adresse", "Eisenbahnstrasse 27",
                    "bauvorhaben", "Umbau Wohnung"))));
        }
    }
}
```

### `normalizer`: Testing Classification and Mapping

The mapping logic is moved into a dedicated mapper. This keeps the normalizer small and delegates the business transformation to `BuildingPermitRawEventMapper`.

File:

```text
BuildingPermitRawEventMapper.java
```

```java
package ch.studior2.buildingpermitmonitor.normalizer.mapper;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitNormalizedEvent;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.model.BuildingPermitStatus;
import org.springframework.stereotype.Component;

@Component
public class BuildingPermitRawEventMapper {

  private static final String SOURCE = "kt-zh";

  private final BuildingPermitCategoryClassifier classifier;

  public BuildingPermitRawEventMapper(BuildingPermitCategoryClassifier classifier) {
    this.classifier = classifier;
  }

  public BuildingPermitNormalizedEvent map(BuildingPermitRawEvent rawEvent) {
    String description = rawEvent.projectDescription();
    String address = formatAddress(rawEvent);

    return new BuildingPermitNormalizedEvent(
        rawEvent.externalId(),
        SOURCE,
        rawEvent.externalId(),
        shorten(description, 120),
        description,
        classifier.classify(description).name(),
        BuildingPermitStatus.SUBMITTED.name(),
        rawEvent.municipalityName(),
        rawEvent.publicationDate(),
        address);
  }

  private String formatAddress(BuildingPermitRawEvent rawEvent) {
    return firstNonBlank(
        joinAddressParts(
            rawEvent.projectLocationAddressStreet(),
            rawEvent.projectLocationAddressHouseNumber(),
            rawEvent.projectLocationAddressSwissZipCode(),
            rawEvent.projectLocationAddressTown()));
  }

  private String joinAddressParts(String street, String houseNumber, Integer zipCode, String town) {
    String streetAndHouseNumber = joinNonBlank(" ", street, houseNumber);

    String zipCodeAndTown =
        joinNonBlank(" ", zipCode == null ? null : String.valueOf(zipCode), town);

    return joinNonBlank(", ", streetAndHouseNumber, zipCodeAndTown);
  }

  private String firstNonBlank(String... values) {
    for (String value : values) {
      if (value != null && !value.isBlank()) {
        return value.trim();
      }
    }
    return null;
  }

  private String joinNonBlank(String delimiter, String... values) {
    StringBuilder result = new StringBuilder();

    for (String value : values) {
      if (value != null && !value.isBlank()) {
        if (!result.isEmpty()) {
          result.append(delimiter);
        }
        result.append(value.trim());
      }
    }

    return result.isEmpty() ? null : result.toString();
  }

  private String shorten(String value, int maxLength) {
    if (value == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength - 3) + "...";
  }
}
```

File:

```text
BuildingPermitMapperTest.java
```

```java
package ch.studior2.buildingpermitmonitor.normalizer.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitNormalizedEvent;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import java.time.Instant;
import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("BuildingPermitMapper")
class BuildingPermitMapperTest {

    private final BuildingPermitMapper mapper = new BuildingPermitMapper();

    @Nested
    @DisplayName("classification")
    class Classification {

        @ParameterizedTest(name = "{0} -> {1}")
        @MethodSource("descriptions")
        @DisplayName("should classify building permit descriptions")
        void shouldClassifyBuildingPermitDescriptions(String description, String expectedCategory) {
            assertEquals(expectedCategory, mapper.classify(description));
        }

        static Stream<Arguments> descriptions() {
            return Stream.of(
                    arguments(named("new building", "Neubau Mehrfamilienhaus"), "NEW_BUILDING"),
                    arguments(named("renovation", "Umbau Wohnung"), "RENOVATION"),
                    arguments(named("demolition", "Rückbau Garage"), "DEMOLITION"),
                    arguments(named("refurbishment", "Sanierung Fassade"), "REFURBISHMENT"),
                    arguments(named("unknown", null), "UNKNOWN"),
                    arguments(named("other", "Nutzungsänderung Ladenlokal"), "OTHER"));
        }
    }

    @Nested
    @DisplayName("mapping")
    class Mapping {

        @ParameterizedTest(name = "{0}")
        @MethodSource("rawEvents")
        @DisplayName("should map raw event to normalized event")
        void shouldMapRawEventToNormalizedEvent(BuildingPermitRawEvent rawEvent) {
            BuildingPermitNormalizedEvent normalized = mapper.map(rawEvent);

            assertEquals("kt-zh:123456", normalized.permitId());
            assertEquals("Thalwil", normalized.municipality());
            assertEquals("RENOVATION", normalized.category());
            assertNull(normalized.publishedDate());
        }

        static Stream<Arguments> rawEvents() {
            return Stream.of(arguments(named("raw renovation event", new BuildingPermitRawEvent(
                    "kt-zh",
                    "123456",
                    Instant.parse("2026-05-17T18:30:00Z"),
                    Map.of(
                            "Gemeinde", "Thalwil",
                            "Bauvorhaben", "Umbau Wohnung",
                            "Adresse", "Eisenbahnstrasse 27")))));
        }
    }
}
```

### `enricher`: Testing the Coordinate Fallback

For the enricher, the coordinate logic is extracted into a separate class.

File:

```text
MunicipalityCoordinateResolver.java
```

```java
package ch.studior2.buildingpermitmonitor.enricher.service;

public class MunicipalityCoordinateResolver {

    public Coordinates approximateCoordinates(String municipality) {
        if ("Zürich".equalsIgnoreCase(municipality)) {
            return new Coordinates(47.3769, 8.5417);
        }
        if ("Winterthur".equalsIgnoreCase(municipality)) {
            return new Coordinates(47.4988, 8.7237);
        }
        if ("Thalwil".equalsIgnoreCase(municipality)) {
            return new Coordinates(47.2918, 8.5631);
        }
        return new Coordinates(null, null);
    }

    public record Coordinates(Double latitude, Double longitude) {
    }
}
```

File:

```text
MunicipalityCoordinateResolverTest.java
```

```java
package ch.studior2.buildingpermitmonitor.enricher.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("MunicipalityCoordinateResolver")
class MunicipalityCoordinateResolverTest {

    private final MunicipalityCoordinateResolver resolver = new MunicipalityCoordinateResolver();

    @Nested
    @DisplayName("known municipalities")
    class KnownMunicipalities {

        @ParameterizedTest(name = "{0}")
        @MethodSource("knownMunicipalities")
        @DisplayName("should return approximate municipality coordinates")
        void shouldReturnApproximateMunicipalityCoordinates(
                String municipality, Double expectedLatitude, Double expectedLongitude) {
            MunicipalityCoordinateResolver.Coordinates coordinates = resolver.approximateCoordinates(municipality);

            assertEquals(expectedLatitude, coordinates.latitude());
            assertEquals(expectedLongitude, coordinates.longitude());
        }

        static Stream<Arguments> knownMunicipalities() {
            return Stream.of(
                    arguments(named("Zürich", "Zürich"), 47.3769, 8.5417),
                    arguments(named("Winterthur", "Winterthur"), 47.4988, 8.7237),
                    arguments(named("Thalwil", "Thalwil"), 47.2918, 8.5631));
        }
    }

    @Nested
    @DisplayName("unknown municipalities")
    class UnknownMunicipalities {

        @ParameterizedTest(name = "{0}")
        @MethodSource("unknownMunicipalities")
        @DisplayName("should return empty coordinates for unknown municipalities")
        void shouldReturnEmptyCoordinatesForUnknownMunicipalities(String municipality) {
            MunicipalityCoordinateResolver.Coordinates coordinates = resolver.approximateCoordinates(municipality);

            assertNull(coordinates.latitude());
            assertNull(coordinates.longitude());
        }

        static Stream<Arguments> unknownMunicipalities() {
            return Stream.of(
                    arguments(named("unknown municipality", "Unbekannt")),
                    arguments(named("null municipality", null)));
        }
    }
}
```

### `persistence`: UUID and SQL Parameter Tests

To make the persistence service testable without a real database, UUID generation should be extracted into a separate class.

File:

```text
PermitIdFactory.java
```

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

public class PermitIdFactory {

    public UUID fromPermitId(String permitId) {
        return UUID.nameUUIDFromBytes(permitId.getBytes(StandardCharsets.UTF_8));
    }
}
```

File:

```text
PermitIdFactoryTest.java
```

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("PermitIdFactory")
class PermitIdFactoryTest {

    private final PermitIdFactory factory = new PermitIdFactory();

    @Nested
    @DisplayName("stable UUIDs")
    class StableUuids {

        @ParameterizedTest(name = "{0}")
        @MethodSource("permitIds")
        @DisplayName("should create deterministic UUIDs from permit ids")
        void shouldCreateDeterministicUuidsFromPermitIds(String permitId) {
            UUID first = factory.fromPermitId(permitId);
            UUID second = factory.fromPermitId(permitId);

            assertEquals(first, second);
        }

        static Stream<Arguments> permitIds() {
            return Stream.of(
                    arguments(named("Kanton Zürich permit", "kt-zh:123456")),
                    arguments(named("Thalwil sample permit", "kt-zh:thalwil-2026-0001")));
        }
    }
}
```

### `api`: Testing Query Parameters and DTO Mapping

The current controller builds SQL directly in the controller. For clean tests, the query construction should be moved into a small class. Using `NamedParameterJdbcTemplate` later would be even better; for the MVP this intermediate solution remains comprehensible.

File:

```text
BuildingPermitQueryBuilder.java
```

```java
package ch.studior2.buildingpermitmonitor.api.repository;

public class BuildingPermitQueryBuilder {

    public String buildFindSql(String municipality, String category) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, title, description, category, status, municipality,
                       published_date, address, latitude, longitude
                FROM building_permits
                WHERE 1 = 1
                """);

        if (municipality != null && !municipality.isBlank()) {
            sql.append(" AND municipality = '").append(escapeSqlLiteral(municipality)).append("'");
        }

        if (category != null && !category.isBlank()) {
            sql.append(" AND category = '").append(escapeSqlLiteral(category)).append("'");
        }

        sql.append(" ORDER BY published_date DESC NULLS LAST, updated_at DESC LIMIT 500");
        return sql.toString();
    }

    String escapeSqlLiteral(String value) {
        return value.replace("'", "''");
    }
}
```

File:

```text
BuildingPermitQueryBuilderTest.java
```

```java
package ch.studior2.buildingpermitmonitor.api.repository;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.params.provider.Arguments.arguments;
import static org.junit.jupiter.api.Named.named;

import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

@DisplayName("BuildingPermitQueryBuilder")
class BuildingPermitQueryBuilderTest {

    private final BuildingPermitQueryBuilder queryBuilder = new BuildingPermitQueryBuilder();

    @Nested
    @DisplayName("filters")
    class Filters {

        @ParameterizedTest(name = "{0}")
        @MethodSource("filters")
        @DisplayName("should include requested filters")
        void shouldIncludeRequestedFilters(String municipality, String category, String expectedSqlPart) {
            String sql = queryBuilder.buildFindSql(municipality, category);

            assertTrue(sql.contains(expectedSqlPart));
        }

        static Stream<Arguments> filters() {
            return Stream.of(
                    arguments(named("municipality filter", "Thalwil"), null, "municipality = 'Thalwil'"),
                    arguments(null, named("category filter", "RENOVATION"), "category = 'RENOVATION'"),
                    arguments(named("escaped municipality", "O'Brian"), null, "municipality = 'O''Brian'"));
        }
    }
}
```

### Spring Boot Application Smoke Tests

For Spring Boot services, a very simple context test can additionally be included. This test does not need to be parameterized because it only verifies that the Spring context starts. The business logic nonetheless remains in parameterized unit tests.

Example for `api`:

```java
package ch.studior2.buildingpermitmonitor.api;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
@DisplayName("BuildingPermitApiApplication")
class BuildingPermitApiApplicationTest {

    @Test
    @DisplayName("should load Spring application context")
    void shouldLoadSpringApplicationContext() {
    }
}
```

For `ingestor`, `normalizer`, `enricher`, and `persistence`, the same smoke test is created with the respective application class.
## Step-by-Step Guide: Platform Repository

The platform repository starts the local infrastructure. It contains no business Java logic.

### Step 1: Create the repository

```bash
mkdir platform
cd platform
git init
```

### Step 2: Create the directory structure

```bash
mkdir -p compose conduktor scripts docs k8s
```

Recommended structure:

```text
platform/
|-- README.md
|-- compose/
|   `-- docker-compose.yml
|-- conduktor/
|   `-- platform-config.yaml
|-- scripts/
|   |-- create-topics.sh
|   `-- reset-local-stack.sh
|-- docs/
`-- k8s/
```

### Step 3: Add the Compose file

The file `compose/docker-compose.yml` contains Kafka, PostGIS, Conduktor Console, and the Conduktor database. For local development the filename is deliberately kept Docker-compatible, even when the environment is started with Podman.

```bash
podman compose -f compose/docker-compose.yml up -d
```

### Step 4: Add the Conduktor configuration

The file `conduktor/platform-config.yaml` defines the local Conduktor login, the internal Conduktor database, and the Kafka cluster.

Important:

```yaml
bootstrapServers: kafka:29092
```

Conduktor runs inside the Compose network and must therefore not use `localhost:9092`. `localhost:9092` is intended only for access from the host system.

### Step 5: Create the Kafka topics

Script `scripts/create-topics.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

KAFKA_CONTAINER="bpm-kafka"
BOOTSTRAP_SERVER="localhost:9092"

for topic in \
  building-permit.raw \
  building-permit.normalized \
  building-permit.enriched \
  building-permit.raw.dlq \
  building-permit.normalized.dlq \
  building-permit.enriched.dlq
do
  podman exec -it "${KAFKA_CONTAINER}" /opt/kafka/bin/kafka-topics.sh     --bootstrap-server "${BOOTSTRAP_SERVER}"     --create     --if-not-exists     --topic "${topic}"     --partitions 1     --replication-factor 1     --config retention.ms=604800000
 done
```

Make it executable:

```bash
chmod +x scripts/create-topics.sh
./scripts/create-topics.sh
```

### Step 6: Verify the infrastructure

```bash
podman compose -f compose/docker-compose.yml ps
```

Check Kafka topics:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh   --bootstrap-server localhost:9092   --list
```

Check PostGIS:

```bash
podman exec -it bpm-postgres psql -U app -d building_permits   -c 'SELECT PostGIS_Version();'
```

Open Conduktor:

```text
http://localhost:8085
```

## Step-by-Step Guide: contracts Library

`contracts` is not a Spring Boot application. It is a plain Maven Java project used as a dependency by all microservices.

### Step 1: Create the project

```bash
mkdir contracts
cd contracts
git init
mkdir -p src/main/java/ch/studior2/buildingpermitmonitor/contracts/{config,event,model,topic}
mkdir -p src/main/resources/schemas
mkdir -p examples
```

### Step 2: Create `pom.xml`

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.release>25</maven.compiler.release>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-annotations</artifactId>
            <version>2.20</version>
        </dependency>
    </dependencies>
</project>
```

### Step 3: Create the event classes

Raw Event:

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.Instant;
import java.util.Map;

public record BuildingPermitRawEvent(
        String source,
        String externalId,
        Instant fetchedAt,
        Map<String, String> payload
) {
}
```

Normalized Event:

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.LocalDate;

public record BuildingPermitNormalizedEvent(
        String permitId,
        String source,
        String externalId,
        String title,
        String description,
        String category,
        String status,
        String municipality,
        LocalDate publishedDate,
        String address
) {
}
```

Enriched Event:

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.LocalDate;

public record BuildingPermitEnrichedEvent(
    String permitId,
    String source,
    String externalId,
    String title,
    String description,
    String category,
    String status,
    String municipality,
    LocalDate publishedDate,
    String address,
    Double latitude,
    Double longitude,
    String geocodingProvider,
    String geocodingQuality) {}
```

`latitude` and `longitude` are stored in the WGS84 coordinate system (`EPSG:4326`). This maps directly to Leaflet and can be stored in PostGIS as `geometry(Point, 4326)`. The order matters: in the Java event, `latitude` comes first semantically, followed by `longitude`; however, in PostGIS the point is created with `ST_MakePoint(longitude, latitude)`.

### Step 4: Create the topic constants

```java
package ch.studior2.buildingpermitmonitor.contracts.topic;

public final class KafkaTopics {

    private KafkaTopics() {
    }

    public static final String RAW = "building-permit.raw";
    public static final String NORMALIZED = "building-permit.normalized";
    public static final String ENRICHED = "building-permit.enriched";
    public static final String RAW_DLQ = "building-permit.raw.dlq";
    public static final String NORMALIZED_DLQ = "building-permit.normalized.dlq";
    public static final String ENRICHED_DLQ = "building-permit.enriched.dlq";
}
```

### Step 5: Create the consumer-group constants

The Kafka consumer group IDs are also defined centrally in the `contracts` module. This eliminates string literals from the `@KafkaListener` annotations in the services.

```java
package ch.studior2.buildingpermitmonitor.contracts.group;

public final class KafkaGroupIDs {

    public static final String PERSISTENCE = "persistence";
    public static final String NORMALIZER = "normalizer";
    public static final String ENRICHER = "enricher";

    private KafkaGroupIDs() {
    }
}
```

Example:

```java
@KafkaListener(topics = KafkaTopics.RAW, groupId = KafkaGroupIDs.NORMALIZER)
```

### Step 6: Install the library locally

```bash
mvn clean install
```

The Spring Boot services can then use this dependency:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
</dependency>
```

## Step-by-Step Guide: Ingestor Service

`ingestor` is a standalone Spring Boot application. It loads the external CSV or GPKG data source and publishes raw events to Kafka.

### Step 1: Generate the Spring Boot project

Using Spring Initializr:

```text
Project: Maven
Language: Java
Spring Boot: 4.x
Java: 25
Group: ch.studio-r2.building-permit-monitor
Artifact: ingestor
Packaging: Jar
```

Dependencies:

```text
Spring for Apache Kafka
Validation
Actuator
```

Additionally in `pom.xml`:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
</dependency>

<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-csv</artifactId>
    <version>1.14.0</version>
</dependency>
```

### Step 2: Create the package structure

```text
src/main/java/ch/studior2/buildingpermitmonitor/ingestor/
|-- BuildingPermitIngestorApplication.java
|-- config/
|-- kafka/
|-- source/
`-- service/
```

### Step 3: Create the application class

```java
package ch.studior2.buildingpermitmonitor.ingestor;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class BuildingPermitIngestorApplication {

    public static void main(String[] args) {
        SpringApplication.run(BuildingPermitIngestorApplication.class, args);
    }
}
```

### Step 4: Configure `application.yml`

File: `src/main/resources/application.yml`

```yaml
spring:
  application:
    name: ingestor

  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer

app:
  building-permits:
    source-url: 'https://example.com/replace-with-real-csv-url.csv'
    ingest-cron: '0 */15 * * * *'

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

### Step 5: Implement the Kafka producer

```java
package ch.studior2.buildingpermitmonitor.ingestor.kafka;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class BuildingPermitRawProducer {

    private final KafkaTemplate<String, BuildingPermitRawEvent> kafkaTemplate;

    public BuildingPermitRawProducer(KafkaTemplate<String, BuildingPermitRawEvent> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void send(BuildingPermitRawEvent event) {
        kafkaTemplate.send(KafkaTopics.RAW, event.externalId(), event);
    }
}
```

### Step 6: Implement the CSV ingestor

The ingestor reads the CSV file and publishes one raw event per record. The stable external ID must be cleanly replaced after analysing the actual CSV header.

```java
package ch.studior2.buildingpermitmonitor.ingestor.service;

import static java.util.stream.Collectors.toMap;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.ingestor.kafka.BuildingPermitRawProducer;
import ch.studior2.buildingpermitmonitor.ingestor.source.CsvBuildingPermitRecordReader;
import ch.studior2.buildingpermitmonitor.persistence.api.BuildingPermitRawEventRegistry;
import java.io.InputStreamReader;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

@Service
public class BuildingPermitIngestor {

  private static final Logger LOG = LoggerFactory.getLogger(BuildingPermitIngestor.class);

  private final BuildingPermitRawProducer producer;
  private final CsvBuildingPermitRecordReader recordReader;
  private final BuildingPermitRawEventRegistry rawEventRegistry;
  private final JsonMapper jsonMapper;
  private final String sourceUrl;

  public BuildingPermitIngestor(
      BuildingPermitRawProducer producer,
      CsvBuildingPermitRecordReader recordReader,
      BuildingPermitRawEventRegistry rawEventRegistry,
      JsonMapper jsonMapper,
      @Value("${app.building-permits.source-url}") String sourceUrl) {
    this.producer = producer;
    this.recordReader = recordReader;
    this.rawEventRegistry = rawEventRegistry;
    this.jsonMapper = jsonMapper;
    this.sourceUrl = sourceUrl;
  }

  @Scheduled(cron = "${app.building-permits.ingest-cron}")
  public void ingest() throws Exception {
    try (var inputStream = URI.create(sourceUrl).toURL().openStream();
        var reader = new InputStreamReader(inputStream, StandardCharsets.UTF_8)) {

      for (var payload : recordReader.read(reader)) {
        BuildingPermitRawEvent event =
            jsonMapper.convertValue(prune(payload), BuildingPermitRawEvent.class);

        if (rawEventRegistry.registerIfNew(event.id(), event.publicationNumber())) {
          producer.send(event);
        } else {
          LOG.info("Skipping duplicate raw event: {}:{}", event.id(), event.publicationNumber());
        }
      }
    }
  }

  private static Map<String, String> prune(Map<String, String> payload) {
    return payload.entrySet().stream()
        .filter(entry -> entry.getValue() != null && !entry.getValue().isBlank())
        .collect(toMap(Map.Entry::getKey, Map.Entry::getValue));
  }
}
```

### Step 7: Start and test locally

```bash
mvn spring-boot:run
```

Observe raw events:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server localhost:9092   --topic building-permit.raw   --from-beginning
```

## Step-by-Step Guide: Normalizer Service

`normalizer` consumes raw events and produces a stable business schema.

### Step 1: Generate the Spring Boot project

```text
Project: Maven
Language: Java
Spring Boot: 4.x
Java: 25
Group: ch.studio-r2.building-permit-monitor
Artifact: normalizer
Packaging: Jar
```

Dependencies:

```text
Spring for Apache Kafka
Validation
Actuator
```

Additionally:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
</dependency>
```

### Step 2: Configure `application.yml`

```yaml
spring:
  application:
    name: normalizer

  kafka:
    bootstrap-servers: localhost:9092
    consumer:
      group-id: normalizer
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JacksonJsonDeserializer
      properties:
        spring.json.trusted.packages: 'ch.studior2.buildingpermitmonitor.*'
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
```

### Step 3: Implement the consumer/producer

```java
package ch.studior2.buildingpermitmonitor.normalizer.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitNormalizedEvent;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import ch.studior2.buildingpermitmonitor.normalizer.mapper.BuildingPermitRawEventMapper;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class BuildingPermitNormalizer {

  private final BuildingPermitRawEventMapper mapper;
  private final KafkaTemplate<String, BuildingPermitNormalizedEvent> kafkaTemplate;

  public BuildingPermitNormalizer(
      BuildingPermitRawEventMapper mapper,
      KafkaTemplate<String, BuildingPermitNormalizedEvent> kafkaTemplate) {
    this.mapper = mapper;
    this.kafkaTemplate = kafkaTemplate;
  }

  @KafkaListener(topics = KafkaTopics.RAW, groupId = KafkaGroupIDs.NORMALIZER)
  public void normalize(BuildingPermitRawEvent rawEvent) {
    BuildingPermitNormalizedEvent normalizedEvent = mapper.map(rawEvent);
    kafkaTemplate.send(KafkaTopics.NORMALIZED, normalizedEvent.permitId(), normalizedEvent);
  }
}
```

### Step 4: Test

```bash
mvn spring-boot:run
```

Observe normalized events:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server localhost:9092   --topic building-permit.normalized   --from-beginning
```

## Step-by-Step Guide: Enricher Service

`enricher` consumes normalized events, geocodes the full address, and then publishes enriched events. Coordinates are no longer stored statically per municipality. Instead, the address assembled by the normalizer is used — that is, street, house number, postal code, and city. The municipality remains as additional context only.

For the MVP we use the GeoAdmin Search API from geo.admin.ch. The API base URL and all business-relevant parameters are configured via `application.yml`. This keeps the client testable and allows the concrete geocoding source to be swapped out later.

### Step 1: Generate the Spring Boot project

```text
Artifact: enricher
Dependencies: Spring for Apache Kafka, WebFlux, Validation, Actuator
```

Also include `contracts` as a Maven dependency. `Spring WebFlux` is not used here for a reactive service, but for the `WebClient` with which the enricher calls the GeoAdmin API.

### Step 2: Configure `application.yml`

```yaml
spring:
  application:
    name: enricher

  kafka:
    bootstrap-servers: localhost:9092
    consumer:
      group-id: enricher
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JacksonJsonDeserializer
      properties:
        spring.json.trusted.packages: 'ch.studior2.buildingpermitmonitor.*'
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer

building-permit:
  geocoding:
    provider: GEO_ADMIN
    base-url: https://api3.geo.admin.ch
    search-path: /rest/services/api/SearchServer
    timeout: 5s
    type: locations
    origins: address,parcel
    spatial-reference: 4326
    limit: 1
```

The most important options:

- `provider`: business name of the geocoding source. This value is carried along in the `BuildingPermitEnrichedEvent`.
- `base-url`: base URL of the GeoAdmin API. It is intentionally configurable and not hard-coded.
- `search-path`: API path for the location search.
- `timeout`: maximum wait time per geocoding request.
- `type`: GeoAdmin search type. For addresses we use `locations`.
- `origins`: GeoAdmin sources used. For building permits, `address` and later `parcel` are relevant.
- `spatial-reference`: `4326` returns WGS84 coordinates, matching Leaflet and PostGIS `geometry(Point, 4326)`.
- `limit`: number of results. For the MVP we use the best match.

### Step 3: Add the configuration class

```java
package ch.studior2.buildingpermitmonitor.enricher.config;

import ch.studior2.buildingpermitmonitor.contracts.geocoding.GeocodingProvider;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "building-permit.geocoding")
public record GeocodingProperties(
    GeocodingProvider provider,
    String baseUrl,
    String searchPath,
    Duration timeout,
    String type,
    String origins,
    Integer spatialReference,
    Integer limit) {}
```

```java
package ch.studior2.buildingpermitmonitor.enricher.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(GeocodingProperties.class)
public class GeocodingConfiguration {}
```

### Step 4: Define the geocoding client

```java
package ch.studior2.buildingpermitmonitor.enricher.geocoding;

import ch.studior2.buildingpermitmonitor.contracts.model.Coordinates;

public interface GeocodingClient {
  Coordinates findCoordinates(String address, String municipality);
}
```

The GeoAdmin API query parameter names are extracted into a small constants class. This prevents HTTP parameter names from being scattered throughout the client code.

```java
package ch.studior2.buildingpermitmonitor.enricher.geocoding;

public final class GeoAdminQueryParameters {

  public static final String TYPE = "type";
  public static final String SEARCH_TEXT = "searchText";
  public static final String SPATIAL_REFERENCE = "sr";
  public static final String ORIGINS = "origins";
  public static final String LIMIT = "limit";

  private GeoAdminQueryParameters() {}
}
```

### Step 5: Implement the GeoAdmin client

```java
package ch.studior2.buildingpermitmonitor.enricher.geocoding;

import ch.studior2.buildingpermitmonitor.contracts.model.Coordinates;
import ch.studior2.buildingpermitmonitor.enricher.config.GeocodingProperties;
import java.util.List;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

@Component
public class GeoAdminGeocodingClient implements GeocodingClient {

  private final GeocodingProperties properties;
  private final WebClient webClient;

  public GeoAdminGeocodingClient(WebClient.Builder webClientBuilder, GeocodingProperties properties) {
    this.properties = properties;
    this.webClient = webClientBuilder.baseUrl(properties.baseUrl()).build();
  }

  @Override
  public Coordinates findCoordinates(String address, String municipality) {
    if (address == null || address.isBlank()) {
      return new Coordinates(null, null);
    }

    String searchText =
        municipality == null || municipality.isBlank()
            ? address.trim()
            : address.trim() + ", " + municipality.trim();

    GeoAdminSearchResponse response =
        webClient
            .get()
            .uri(
                uriBuilder ->
                    uriBuilder
                        .path(properties.searchPath())
                        .queryParam(GeoAdminQueryParameters.TYPE, properties.type())
                        .queryParam(GeoAdminQueryParameters.SEARCH_TEXT, searchText)
                        .queryParam(
                            GeoAdminQueryParameters.SPATIAL_REFERENCE,
                            properties.spatialReference())
                        .queryParam(GeoAdminQueryParameters.ORIGINS, properties.origins())
                        .queryParam(GeoAdminQueryParameters.LIMIT, properties.limit())
                        .build())
            .retrieve()
            .bodyToMono(GeoAdminSearchResponse.class)
            .timeout(properties.timeout())
            .onErrorReturn(new GeoAdminSearchResponse(List.of()))
            .block();

    if (response == null || response.results() == null || response.results().isEmpty()) {
      return new Coordinates(null, null);
    }

    GeoAdminSearchAttributes attrs = response.results().getFirst().attrs();

    if (attrs == null || attrs.lat() == null || attrs.lon() == null) {
      return new Coordinates(null, null);
    }

    return new Coordinates(attrs.lat(), attrs.lon());
  }

  public record GeoAdminSearchResponse(List<GeoAdminSearchResult> results) {}

  public record GeoAdminSearchResult(GeoAdminSearchAttributes attrs) {}

  public record GeoAdminSearchAttributes(Double lat, Double lon) {}
}
```

Important: The client requests WGS84 coordinates with `sr=4326`. These can be used directly in Leaflet as `[latitude, longitude]`. When saving to PostGIS this becomes `ST_MakePoint(longitude, latitude)`, because PostGIS expects points in `x, y` order.

### Step 6: Implement the enricher

```java
package ch.studior2.buildingpermitmonitor.enricher.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitNormalizedEvent;
import ch.studior2.buildingpermitmonitor.contracts.geocoding.GeocodingQuality;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.model.Coordinates;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import ch.studior2.buildingpermitmonitor.enricher.config.GeocodingProperties;
import ch.studior2.buildingpermitmonitor.enricher.geocoding.GeocodingClient;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class BuildingPermitEnricher {

  private final GeocodingProperties geocodingProperties;
  private final GeocodingClient geocodingClient;
  private final KafkaTemplate<String, BuildingPermitEnrichedEvent> kafkaTemplate;

  public BuildingPermitEnricher(
      GeocodingProperties geocodingProperties,
      GeocodingClient geocodingClient,
      KafkaTemplate<String, BuildingPermitEnrichedEvent> kafkaTemplate) {
    this.geocodingProperties = geocodingProperties;
    this.geocodingClient = geocodingClient;
    this.kafkaTemplate = kafkaTemplate;
  }

  @KafkaListener(topics = KafkaTopics.NORMALIZED, groupId = KafkaGroupIDs.ENRICHER)
  public void enrich(BuildingPermitNormalizedEvent event) {
    Coordinates coordinates = geocodingClient.findCoordinates(event.address(), event.municipality());

    GeocodingQuality quality =
        coordinates.latitude() == null || coordinates.longitude() == null
            ? GeocodingQuality.NOT_FOUND
            : GeocodingQuality.ADDRESS;

    BuildingPermitEnrichedEvent enrichedEvent =
        new BuildingPermitEnrichedEvent(
            event.permitId(),
            event.source(),
            event.externalId(),
            event.title(),
            event.description(),
            event.category(),
            event.status(),
            event.municipality(),
            event.publishedDate(),
            event.address(),
            coordinates.latitude(),
            coordinates.longitude(),
            geocodingProperties.provider().name(),
            quality.name());

    kafkaTemplate.send(KafkaTopics.ENRICHED, event.permitId(), enrichedEvent);
  }
}
```

### Step 7: Open the Java module

Because the enricher uses Java modules, Spring reflection, WebFlux, and JSON deserialization, `module-info.java` requires targeted `requires` and `opens` directives.

```java
module ch.studior2.buildingpermitmonitor.enricher {
  requires spring.boot;
  requires spring.boot.autoconfigure;
  requires spring.context;
  requires spring.kafka;
  requires kafka.clients;
  requires ch.studior2.buildingpermitmonitor.contracts;
  requires spring.webflux;
  requires spring.web;
  requires reactor.core;

  opens ch.studior2.buildingpermitmonitor.enricher to
      spring.core,
      spring.beans,
      spring.context;
  opens ch.studior2.buildingpermitmonitor.enricher.config to
      spring.core,
      spring.beans,
      spring.context;
  opens ch.studior2.buildingpermitmonitor.enricher.geocoding to
      spring.core,
      spring.beans,
      spring.context,
      com.fasterxml.jackson.databind,
      tools.jackson.databind;
  opens ch.studior2.buildingpermitmonitor.enricher.service to
      spring.core,
      spring.beans,
      spring.context;
}
```

### Step 8: Observe the enriched topic

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.enriched \
  --from-beginning
```

## Step-by-Step Guide: Persistence Service

`persistence` consumes enriched events and stores them idempotently in PostgreSQL/PostGIS. The current implementation uses **Spring Data JPA**, **Hibernate Spatial**, and **JTS**. JDBC Template is no longer used in the persistence module.

### Step 1: Generate the Spring Boot project

```text
Artifact: persistence
Dependencies: Spring for Apache Kafka, Spring Data JPA, PostgreSQL Driver, Flyway Migration, Validation, Actuator
```

The following additional dependencies are required:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>${project.version}</version>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>

<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
</dependency>

<dependency>
    <groupId>org.hibernate.orm</groupId>
    <artifactId>hibernate-spatial</artifactId>
</dependency>

<dependency>
    <groupId>org.locationtech.jts</groupId>
    <artifactId>jts-core</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-flyway</artifactId>
</dependency>
```

For repository tests against real PostGIS functions:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa-test</artifactId>
    <scope>test</scope>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-testcontainers</artifactId>
    <scope>test</scope>
</dependency>

<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
</dependency>

<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>postgresql</artifactId>
    <scope>test</scope>
</dependency>
```

### Step 2: Configure `application.yml`

```yaml
spring:
  application:
    name: persistence

  datasource:
    url: jdbc:postgresql://localhost:5432/building_permits
    username: app
    password: app

  flyway:
    enabled: true

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        format_sql: true

  kafka:
    bootstrap-servers: localhost:9092
    consumer:
      group-id: persistence
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JacksonJsonDeserializer
      properties:
        spring.json.trusted.packages: 'ch.studior2.buildingpermitmonitor.*'
```

Important: Flyway creates the schema. Hibernate only validates it. Tables should not be created automatically by Hibernate.

### Step 3: Create the Flyway migration

Files:

```text
src/main/resources/db/migration/V1__create_building_permit_raw_event_registry.sql
src/main/resources/db/migration/V2__create_extension_postgis.sql
src/main/resources/db/migration/V3__create_building_permits.sql
```

The migrations handle:

- Activating PostGIS
- Creating the `building_permit_raw_event_registry` table
- Creating the `building_permits` table
- GIST index on `geom`
- Unique constraint on `(source, external_id)`

The complete SQL scripts are in the `Database Model` section.

### Step 4: Implement the entity

The entity maps the business columns and the PostGIS geometry. `geom` is stored as a JTS `Point`. `raw_payload` is `jsonb` and is correctly bound as JSON with `@JdbcTypeCode(SqlTypes.JSON)`.

```java
package ch.studior2.buildingpermitmonitor.persistence.entity;

import ch.studior2.buildingpermitmonitor.contracts.geocoding.GeocodingProvider;
import ch.studior2.buildingpermitmonitor.contracts.geocoding.GeocodingQuality;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.locationtech.jts.geom.Point;

@Entity
@Table(name = "building_permits")
public class BuildingPermitEntity {

  @Id
  private UUID id;

  private String source;

  @Column(name = "external_id")
  private String externalId;

  private String title;
  private String description;
  private String category;
  private String status;
  private String municipality;

  @Column(name = "published_date")
  private LocalDate publishedDate;

  private String address;
  private Double latitude;
  private Double longitude;

  @Enumerated(EnumType.STRING)
  @Column(name = "geocoding_provider")
  private GeocodingProvider geocodingProvider;

  @Enumerated(EnumType.STRING)
  @Column(name = "geocoding_quality")
  private GeocodingQuality geocodingQuality;

  @JdbcTypeCode(SqlTypes.GEOMETRY)
  @Column(columnDefinition = "geometry(Point,4326)")
  private Point geom;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(name = "raw_payload", columnDefinition = "jsonb")
  private String rawPayload;

  // Getters, setters, equals, and hashCode
}
```

### Step 5: Implement the PointFactory

PostGIS expects points in `x, y` order, i.e., `longitude, latitude`. In the event and in the API, the values remain semantically readable as `latitude` and `longitude`.

```java
package ch.studior2.buildingpermitmonitor.persistence.geometry;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Component;

@Component
public class PointFactory {

  private static final int WGS84_SRID = 4326;

  private final GeometryFactory geometryFactory =
      new GeometryFactory(new PrecisionModel(), WGS84_SRID);

  public Point create(Double latitude, Double longitude) {
    if (latitude == null || longitude == null) {
      return null;
    }

    Point point = geometryFactory.createPoint(new Coordinate(longitude, latitude));
    point.setSRID(WGS84_SRID);
    return point;
  }
}
```

### Step 6: Implement the Spring Data repository

```java
package ch.studior2.buildingpermitmonitor.persistence.repository;

import ch.studior2.buildingpermitmonitor.persistence.entity.BuildingPermitEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.locationtech.jts.geom.Point;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BuildingPermitRepository extends JpaRepository<BuildingPermitEntity, UUID> {

  Optional<BuildingPermitEntity> findBySourceAndExternalId(String source, String externalId);

  @Query(
      value =
          """
          SELECT *
          FROM building_permits bp
          WHERE ST_DWithin(
              CAST(bp.geom AS geography),
              CAST(:point AS geography),
              :radiusMeters
          )
          """,
      nativeQuery = true)
  List<BuildingPermitEntity> findWithinRadius(
      @Param("point") Point point,
      @Param("radiusMeters") double radiusMeters);

  @Query(
      value =
          """
          SELECT *
          FROM building_permits bp
          WHERE bp.geom && ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
          """,
      nativeQuery = true)
  List<BuildingPermitEntity> findVisiblePermits(
      @Param("minLon") double minLon,
      @Param("minLat") double minLat,
      @Param("maxLon") double maxLon,
      @Param("maxLat") double maxLat);
}
```

Important: In Spring Data queries, `:point::geography` should not be used. Spring Data may interpret this as the parameter `point::geography`. A more robust approach is:

```sql
CAST(:point AS geography)
```

### Step 7: Implement the persistence service

The Kafka consumer intentionally contains no persistence logic. It receives enriched events and delegates to the service.

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class BuildingPermitPersistenceConsumer {

  private final BuildingPermitPersistenceService service;

  public BuildingPermitPersistenceConsumer(BuildingPermitPersistenceService service) {
    this.service = service;
  }

  @KafkaListener(topics = KafkaTopics.ENRICHED, groupId = KafkaGroupIDs.PERSISTENCE)
  public void persist(BuildingPermitEnrichedEvent event) {
    service.persist(event);
  }
}
```

The actual persistence logic resides in the service. It generates a stable UUID, builds the JTS `Point`, saves the complete event as JSON, and performs an idempotent insert/update using the natural business key `(source, external_id)`.

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import ch.studior2.buildingpermitmonitor.persistence.entity.BuildingPermitEntity;
import ch.studior2.buildingpermitmonitor.persistence.geometry.PointFactory;
import ch.studior2.buildingpermitmonitor.persistence.repository.BuildingPermitRepository;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@Service
public class BuildingPermitPersistenceService {

  private final BuildingPermitRepository repository;
  private final PointFactory pointFactory;
  private final JsonMapper jsonMapper;

  public BuildingPermitPersistenceService(
      BuildingPermitRepository repository,
      PointFactory pointFactory,
      JsonMapper jsonMapper) {
    this.repository = repository;
    this.pointFactory = pointFactory;
    this.jsonMapper = jsonMapper;
  }

  @Transactional
  public void persist(BuildingPermitEnrichedEvent event) {
    BuildingPermitEntity entity =
        repository
            .findBySourceAndExternalId(event.source(), event.externalId())
            .orElseGet(BuildingPermitEntity::new);

    entity.setId(UUID.nameUUIDFromBytes(event.permitId().getBytes(StandardCharsets.UTF_8)));
    entity.setSource(event.source());
    entity.setExternalId(event.externalId());
    entity.setTitle(event.title());
    entity.setDescription(event.description());
    entity.setCategory(event.category());
    entity.setStatus(event.status());
    entity.setMunicipality(event.municipality());
    entity.setPublishedDate(event.publishedDate());
    entity.setAddress(event.address());
    entity.setLatitude(event.latitude());
    entity.setLongitude(event.longitude());
    entity.setGeom(pointFactory.create(event.latitude(), event.longitude()));
    entity.setRawPayload(jsonMapper.writeValueAsString(event));

    repository.save(entity);
  }
}
```

### Step 8: Repository tests with Testcontainers

Repository tests run against a real PostGIS container. This verifies not only mocks but also:

- Flyway migrations
- Hibernate Spatial mapping
- `jsonb` mapping
- `ST_DWithin`
- `ST_MakeEnvelope`
- SRID `4326`

```java
package ch.studior2.buildingpermitmonitor.persistence.repository;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

@DataJpaTest
@Testcontainers
@DisplayName("BuildingPermitRepository")
class BuildingPermitRepositoryTest {

  private static final DockerImageName POSTGIS_IMAGE =
      DockerImageName.parse("postgis/postgis:17-3.5")
          .asCompatibleSubstituteFor("postgres");

  @Container
  @ServiceConnection
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>(POSTGIS_IMAGE);

  @Test
  @DisplayName("should load repository test context")
  void shouldLoadRepositoryTestContext() {
    // Repository tests persist sample entities and execute PostGIS queries.
  }
}
```

If the test loads additional Kafka configuration through the real `BuildingPermitPersistenceApplication`, a minimal test configuration should be used for the repository test:

```java
@ContextConfiguration(classes = BuildingPermitRepositoryTest.TestApplication.class)
class BuildingPermitRepositoryTest {

  @SpringBootConfiguration
  @EnableAutoConfiguration
  @EntityScan(basePackageClasses = BuildingPermitEntity.class)
  @EnableJpaRepositories(basePackageClasses = BuildingPermitRepository.class)
  static class TestApplication {}
}
```

For JPMS issues with test JARs — for example, multiple Kafka modules on the module path — the classpath can pragmatically be used for Surefire:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <configuration>
        <useModulePath>false</useModulePath>
    </configuration>
</plugin>
```

### Step 9: Check the database

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

```sql
SELECT municipality, category, count(*)
FROM building_permits
GROUP BY municipality, category
ORDER BY count(*) DESC;
```

Radius search in SQL:

```sql
SELECT title, municipality
FROM building_permits
WHERE ST_DWithin(
    CAST(geom AS geography),
    CAST(ST_SetSRID(ST_MakePoint(8.5631, 47.2918), 4326) AS geography),
    1000
);
```
## Step-by-Step Guide: API Service

`api` is a standalone Spring Boot application. It does not consume Kafka events; instead it reads from PostgreSQL/PostGIS.

### Step 1: Create the Spring Boot Project

```text
Artifact: api
Dependencies: Spring Web, Spring JDBC, PostgreSQL Driver, Validation, Actuator
```

WebFlux can optionally be used if streaming endpoints or reactive HTTP clients are needed later.

### Step 2: Configure `application.yml`

```yaml
spring:
  application:
    name: api

  datasource:
    url: jdbc:postgresql://localhost:5432/building_permits
    username: app
    password: app

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

### Step 3: Create the DTO

```java
package ch.studior2.buildingpermitmonitor.api.dto;

import java.time.LocalDate;
import java.util.UUID;

public record BuildingPermitDto(
        UUID id,
        String title,
        String description,
        String category,
        String status,
        String municipality,
        LocalDate publishedDate,
        String address,
        Double latitude,
        Double longitude
) {
}
```

### Step 4: Create the REST Controller

For the first MVP a simple endpoint is sufficient. In a later iteration the query should be parameterized using `NamedParameterJdbcTemplate`.

```java
package ch.studior2.buildingpermitmonitor.api.controller;

import ch.studior2.buildingpermitmonitor.api.dto.BuildingPermitDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
public class BuildingPermitController {

    private final JdbcTemplate jdbcTemplate;

    public BuildingPermitController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/api/building-permits")
    public List<BuildingPermitDto> findBuildingPermits(
            @RequestParam(required = false) String municipality,
            @RequestParam(required = false) String category
    ) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, title, description, category, status, municipality,
                       published_date, address, latitude, longitude
                FROM building_permits
                WHERE 1 = 1
                """);

        if (municipality != null && !municipality.isBlank()) {
            sql.append(" AND municipality = '").append(municipality.replace("'", "''")).append("'");
        }

        if (category != null && !category.isBlank()) {
            sql.append(" AND category = '").append(category.replace("'", "''")).append("'");
        }

        sql.append(" ORDER BY published_date DESC NULLS LAST, updated_at DESC LIMIT 500");

        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> new BuildingPermitDto(
                UUID.fromString(rs.getString("id")),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("category"),
                rs.getString("status"),
                rs.getString("municipality"),
                rs.getDate("published_date") != null
                        ? rs.getDate("published_date").toLocalDate()
                        : null,
                rs.getString("address"),
                rs.getObject("latitude", Double.class),
                rs.getObject("longitude", Double.class)
        ));
    }
}
```

### Step 5: Testing the API

```bash
mvn spring-boot:run
```

```bash
curl http://localhost:8080/api/building-permits
```

```bash
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
```

## Step-by-Step Guide: Web Angular Library

`web` is not a standalone Angular application. The module is built as an Angular library and later integrated as a dependency into the existing Studio-r2 web app. This keeps the Studio-r2 web app as the actual host application, while `web` only provides the domain-specific building-permit components, services, and models.

### Step 1: Create an Angular Workspace Without an Application

```bash
npm create angular@latest web -- --create-application=false
cd web
```

Alternatively, an existing Angular workspace can be used. The important point is that the building-permit frontend is generated as a library.

### Step 2: Generate the Library

```bash
npx ng generate library building-permit-map
```

Recommended structure:

```text
web/
|-- package.json
|-- angular.json
|-- ng-package.json
|-- projects/
|   `-- building-permit-map/
|       |-- ng-package.json
|       `-- src/
|           |-- public-api.ts
|           `-- lib/
|               |-- building-permit-map.component.ts
|               |-- building-permit-map.service.ts
|               |-- building-permit-map.config.ts
|               `-- model/
`-- dist/
```

### Step 3: Install Leaflet

```bash
npm install leaflet
npm install --save-dev @types/leaflet
```

Leaflet is used in the library module. The host application must also include the Leaflet CSS file, for example in `angular.json` or in global styles.

### Step 4: Prepare the Configuration for the Host Application

The library should not contain a hardcoded API URL. Instead it provides a configuration that is set by the Studio-r2 web app.

```typescript
export interface BuildingPermitMapConfig {
  apiBaseUrl: string;
}
```

The host application can later configure it as follows, for example:

```typescript
provideBuildingPermitMap({
  apiBaseUrl: 'https://api.studio-r2.ch',
});
```

### Step 5: Export Components

The library exports its public building blocks via `public-api.ts`:

```typescript
export * from './lib/building-permit-map.component';
export * from './lib/building-permit-map.service';
export * from './lib/building-permit-map.config';
export * from './lib/model/building-permit';
```

### Step 6: Build the Library

```bash
npm run build building-permit-map
```

The output is located under:

```text
dist/building-permit-map
```

### Step 7: Integration into the Studio-r2 Web App

For local development the library can be installed directly from the local `dist` directory:

```bash
cd ../studio-r2-web-app
npm install ../building-permit-monitor/web/dist/building-permit-map
```

Later, the library can be published and versioned in a private or public npm registry.

## Recommended Implementation Order

For the MVP, not everything should be built at the same time. The following order makes sense:

```text
1. platform
2. contracts
3. ingestor
4. normalizer
5. persistence
6. api
7. web
8. enricher
```

An even leaner initial version is possible:

```text
1. platform
2. contracts
3. ingestor
4. persistence
5. api
```

In this reduced variant the ingestor publishes a normalized event directly, or the persistence service temporarily stores raw/normalized events. The separate normalizer and enricher are added afterwards.

## Database Model

For the MVP a single central table is sufficient.

File:

```text
persistence/src/main/resources/db/migration/V1__create_building_permits.sql
```

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE building_permits (
    id UUID PRIMARY KEY,
    source TEXT NOT NULL,
    external_id TEXT NOT NULL,
    title TEXT,
    description TEXT,
    category TEXT,
    status TEXT,
    municipality TEXT,
    published_date DATE,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geocoding_provider TEXT,
    geocoding_quality TEXT,
    geom GEOMETRY(Point, 4326),
    raw_payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (source, external_id)
);

CREATE INDEX idx_building_permits_source_external_id
    ON building_permits (source, external_id);

CREATE INDEX idx_building_permits_municipality
    ON building_permits (municipality);

CREATE INDEX idx_building_permits_published_date
    ON building_permits (published_date);

CREATE INDEX idx_building_permits_geom
    ON building_permits
    USING GIST (geom);
```

### Flyway at Spring Boot Startup and as a Maven Plugin

The project uses Flyway in two roles:

```text
spring-boot-starter-flyway
    automatic migration on startup of the Persistence module

flyway-maven-plugin
    manual migrations, validation, and status queries
```

Both variants may coexist. The starter is part of the application. The Maven plugin is only executed when explicitly invoked.

Examples:

```bash
mvn -pl persistence flyway:info
mvn -pl persistence flyway:validate
mvn -pl persistence flyway:migrate
```

For the Maven plugin to know the database connection, `url`, `user`, and `password` must be configured — either in the plugin, via Maven properties, or on the command line:

```bash
mvn -pl persistence flyway:migrate \
  -Dflyway.url=jdbc:postgresql://localhost:5432/building_permits \
  -Dflyway.user=app \
  -Dflyway.password=app
```

The simplified domain data model looks like this.

![Simplified Data Model](docs/architecture/simplified-data-model.png)

## Event Model

### Raw Event

A Raw Event contains as much of the original information as possible.

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.Instant;
import java.util.Map;

public record BuildingPermitRawEvent(
        String source,
        String externalId,
        Instant fetchedAt,
        Map<String, String> payload
) {
}
```

Example:

```json
{
  "source": "kt-zh",
  "externalId": "123456",
  "fetchedAt": "2026-05-17T18:30:00Z",
  "payload": {
    "gemeinde": "Thalwil",
    "bauvorhaben": "Umbau Wohnung",
    "adresse": "Eisenbahnstrasse 27",
    "status": "beantragt"
  }
}
```

### Normalized Event

A normalized event contains a stable internal schema.

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.LocalDate;

public record BuildingPermitNormalizedEvent(
        String permitId,
        String source,
        String externalId,
        String title,
        String description,
        String category,
        String status,
        String municipality,
        LocalDate publishedDate,
        String address
) {
}
```

Example:

```json
{
  "permitId": "kt-zh:123456",
  "source": "kt-zh",
  "externalId": "123456",
  "title": "Umbau Wohnung",
  "description": "Umbau Wohnung, Balkoninstandsetzung",
  "category": "RENOVATION",
  "status": "SUBMITTED",
  "municipality": "Thalwil",
  "publishedDate": "2026-05-17",
  "address": "Eisenbahnstrasse 27, 8800 Thalwil"
}
```

### Enriched Event

An Enriched Event additionally contains coordinates and metadata about the geocoding. The coordinates are stored in WGS84 (`EPSG:4326`).

```java
package ch.studior2.buildingpermitmonitor.contracts.event;

import java.time.LocalDate;

public record BuildingPermitEnrichedEvent(
    String permitId,
    String source,
    String externalId,
    String title,
    String description,
    String category,
    String status,
    String municipality,
    LocalDate publishedDate,
    String address,
    Double latitude,
    Double longitude,
    String geocodingProvider,
    String geocodingQuality) {}
```

Example:

```json
{
  "permitId": "kt-zh:123456",
  "source": "kt-zh",
  "externalId": "123456",
  "title": "Umbau Wohnung",
  "description": "Umbau Wohnung, Balkoninstandsetzung",
  "category": "RENOVATION",
  "status": "SUBMITTED",
  "municipality": "Thalwil",
  "publishedDate": "2026-05-17",
  "address": "Eisenbahnstrasse 27, 8800 Thalwil",
  "latitude": 47.2918,
  "longitude": 8.5631,
  "geocodingProvider": "GEO_ADMIN",
  "geocodingQuality": "ADDRESS"
}
```

## Kafka Topic Constants

```java
package ch.studior2.buildingpermitmonitor.contracts.topic;

public final class KafkaTopics {

    private KafkaTopics() {
    }

    public static final String RAW = "building-permit.raw";
    public static final String NORMALIZED = "building-permit.normalized";
    public static final String ENRICHED = "building-permit.enriched";
    public static final String RAW_DLQ = "building-permit.raw.dlq";
    public static final String NORMALIZED_DLQ = "building-permit.normalized.dlq";
    public static final String ENRICHED_DLQ = "building-permit.enriched.dlq";
}
```

## Kafka Consumer Group Constants

```java
package ch.studior2.buildingpermitmonitor.contracts.group;

public final class KafkaGroupIDs {

    public static final String PERSISTENCE = "persistence";
    public static final String NORMALIZER = "normalizer";
    public static final String ENRICHER = "enricher";

    private KafkaGroupIDs() {
    }
}
```

## Kafka Producer

```java
package ch.studior2.buildingpermitmonitor.ingestor.kafka;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class BuildingPermitRawProducer {

    private final KafkaTemplate<String, BuildingPermitRawEvent> kafkaTemplate;

    public BuildingPermitRawProducer(
            KafkaTemplate<String, BuildingPermitRawEvent> kafkaTemplate
    ) {
        this.kafkaTemplate = kafkaTemplate;
    }

    public void send(BuildingPermitRawEvent event) {
        kafkaTemplate.send(KafkaTopics.RAW, event.externalId(), event);
    }
}
```

## CSV Ingestor

The ingestor loads the CSV file, reads each row, and publishes one Raw Event per row.

```java
package ch.studior2.buildingpermitmonitor.ingestor.service;

import static java.util.stream.Collectors.toMap;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.ingestor.kafka.BuildingPermitRawProducer;
import ch.studior2.buildingpermitmonitor.ingestor.source.CsvBuildingPermitRecordReader;
import ch.studior2.buildingpermitmonitor.persistence.api.BuildingPermitRawEventRegistry;
import java.io.InputStreamReader;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

@Service
public class BuildingPermitIngestor {

  private static final Logger LOG = LoggerFactory.getLogger(BuildingPermitIngestor.class);

  private final BuildingPermitRawProducer producer;
  private final CsvBuildingPermitRecordReader recordReader;
  private final BuildingPermitRawEventRegistry rawEventRegistry;
  private final JsonMapper jsonMapper;
  private final String sourceUrl;

  public BuildingPermitIngestor(
      BuildingPermitRawProducer producer,
      CsvBuildingPermitRecordReader recordReader,
      BuildingPermitRawEventRegistry rawEventRegistry,
      JsonMapper jsonMapper,
      @Value("${app.building-permits.source-url}") String sourceUrl) {
    this.producer = producer;
    this.recordReader = recordReader;
    this.rawEventRegistry = rawEventRegistry;
    this.jsonMapper = jsonMapper;
    this.sourceUrl = sourceUrl;
  }

  @Scheduled(cron = "${app.building-permits.ingest-cron}")
  public void ingest() throws Exception {
    try (var inputStream = URI.create(sourceUrl).toURL().openStream();
        var reader = new InputStreamReader(inputStream, StandardCharsets.UTF_8)) {

      for (var payload : recordReader.read(reader)) {
        BuildingPermitRawEvent event =
            jsonMapper.convertValue(prune(payload), BuildingPermitRawEvent.class);

        if (rawEventRegistry.registerIfNew(event.id(), event.publicationNumber())) {
          producer.send(event);
        } else {
          LOG.info("Skipping duplicate raw event: {}:{}", event.id(), event.publicationNumber());
        }
      }
    }
  }

  private static Map<String, String> prune(Map<String, String> payload) {
    return payload.entrySet().stream()
        .filter(entry -> entry.getValue() != null && !entry.getValue().isBlank())
        .collect(toMap(Map.Entry::getKey, Map.Entry::getValue));
  }
}
```

Enable scheduling:

```java
package ch.studior2.buildingpermitmonitor;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
public class BuildingPermitApplication {

    public static void main(String[] args) {
        SpringApplication.run(BuildingPermitApplication.class, args);
    }
}
```

## Why Do We Need a Stable External ID?

The application must be able to determine whether a building permit is new, already known, or has changed.

For this we need:

```text
source + externalId
```

Example:

```text
kt-zh:123456
```

If the record does not contain a unique ID, a hash can be formed as a temporary measure. Better, however, is a real business ID from the data source.

Example of a simple hash:

```java
String fingerprint = DigestUtils.sha256Hex(
        municipality + "|" + address + "|" + description + "|" + publishedDate
);
```

Apache Commons Codec can be used for this:

```xml
<dependency>
    <groupId>commons-codec</groupId>
    <artifactId>commons-codec</artifactId>
    <version>1.19.0</version>
</dependency>
```

## Normalizer Consumer

The normalizer consumes Raw Events and publishes Normalized Events.

```java
package ch.studior2.buildingpermitmonitor.normalizer.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitNormalizedEvent;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import ch.studior2.buildingpermitmonitor.normalizer.mapper.BuildingPermitRawEventMapper;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class BuildingPermitNormalizer {

  private final BuildingPermitRawEventMapper mapper;
  private final KafkaTemplate<String, BuildingPermitNormalizedEvent> kafkaTemplate;

  public BuildingPermitNormalizer(
      BuildingPermitRawEventMapper mapper,
      KafkaTemplate<String, BuildingPermitNormalizedEvent> kafkaTemplate) {
    this.mapper = mapper;
    this.kafkaTemplate = kafkaTemplate;
  }

  @KafkaListener(topics = KafkaTopics.RAW, groupId = KafkaGroupIDs.NORMALIZER)
  public void normalize(BuildingPermitRawEvent rawEvent) {
    BuildingPermitNormalizedEvent normalizedEvent = mapper.map(rawEvent);
    kafkaTemplate.send(KafkaTopics.NORMALIZED, normalizedEvent.permitId(), normalizedEvent);
  }
}
```

## Persistence Service

The Persistence Service consumes Enriched Events and stores them in PostgreSQL/PostGIS. The current implementation is based on Spring Data JPA, Hibernate Spatial, and JTS. JdbcTemplate is no longer used in the Persistence module.

The Kafka consumer remains very small:

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
public class BuildingPermitPersistenceConsumer {

  private final BuildingPermitPersistenceService service;

  public BuildingPermitPersistenceConsumer(BuildingPermitPersistenceService service) {
    this.service = service;
  }

  @KafkaListener(topics = KafkaTopics.ENRICHED, groupId = KafkaGroupIDs.PERSISTENCE)
  public void persist(BuildingPermitEnrichedEvent event) {
    service.persist(event);
  }
}
```

The persistence logic resides in `BuildingPermitPersistenceService` and the Spring Data repository:

```java
public interface BuildingPermitRepository extends JpaRepository<BuildingPermitEntity, UUID> {

  Optional<BuildingPermitEntity> findBySourceAndExternalId(String source, String externalId);

  @Query(
      value =
          """
          SELECT *
          FROM building_permits bp
          WHERE ST_DWithin(
              CAST(bp.geom AS geography),
              CAST(:point AS geography),
              :radiusMeters
          )
          """,
      nativeQuery = true)
  List<BuildingPermitEntity> findWithinRadius(
      @Param("point") Point point,
      @Param("radiusMeters") double radiusMeters);

  @Query(
      value =
          """
          SELECT *
          FROM building_permits bp
          WHERE bp.geom && ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)
          """,
      nativeQuery = true)
  List<BuildingPermitEntity> findVisiblePermits(
      @Param("minLon") double minLon,
      @Param("minLat") double minLat,
      @Param("maxLon") double maxLon,
      @Param("maxLat") double maxLat);
}
```

Key points:

- `source + external_id` is the natural business key.
- `id` is generated deterministically from `permitId`.
- `geom` is stored as `geometry(Point, 4326)`.
- `raw_payload` is stored as `jsonb` and mapped with `@JdbcTypeCode(SqlTypes.JSON)`.
- Spatial queries use native PostGIS functions.
- Repository tests use Testcontainers with `postgis/postgis:17-3.5`.

## Geocoding

Geocoding is no longer performed via statically stored municipality centroids. While those were convenient for an initial demo, they are too imprecise for building permits from a domain perspective. A building permit typically refers to a specific plot or at least a concrete address. For this reason the enricher uses the address from the normalized event.

The normalizer assembles the address from the available raw data:

```text
street + house number, postcode + town
```

Example:

```text
Eisenbahnstrasse 27, 8800 Thalwil
```

This address is passed by the enricher to the `GeocodingClient`. The municipality is additionally supplied as context so that ambiguous addresses can be resolved more accurately.

### GeoAdmin as the MVP Geocoder

For the MVP we use the GeoAdmin Search API from `geo.admin.ch`. It is more appropriate for Swiss geodata from a domain perspective than a generic international geocoder. The base URL and query options are defined in `application.yml` and are therefore swappable.

```yaml
building-permit:
  geocoding:
    provider: GEO_ADMIN
    base-url: https://api3.geo.admin.ch
    search-path: /rest/services/api/SearchServer
    timeout: 5s
    type: locations
    origins: address,parcel
    spatial-reference: 4326
    limit: 1
```

`spatial-reference: 4326` is important. It causes the geocoder to return WGS84 coordinates, which is the standard format for web maps such as Leaflet.

```text
Leaflet Marker: [latitude, longitude]
PostGIS Point:  ST_MakePoint(longitude, latitude)
```

This difference in order is important. In the Java event the values remain readable as `latitude` and `longitude`. When writing to PostGIS, however, longitude is passed first and latitude second for technical reasons.

### Geocoding Provider and Quality

The Enriched Event additionally contains metadata about the geocoding:

```java
String geocodingProvider,
String geocodingQuality
```

For the MVP these values are sufficient:

```text
GeocodingProvider.GEO_ADMIN
GeocodingQuality.ADDRESS
GeocodingQuality.NOT_FOUND
```

Additional quality levels can be added later, for example `PARCEL`, `STREET`, or `MUNICIPALITY`. This allows the API or the frontend to later distinguish whether a marker is based on an exact address or was placed only approximately.

### Fallback Strategy

The recommended search strategy is:

1. full address: street, house number, postcode, town
2. reduced address: street, postcode, town
3. town or municipality
4. no marker if no reliable coordinates are found

Municipality centroids remain at most an optional fallback. They should be clearly marked as approximate in the frontend and should not be mixed with exactly geocoded addresses.

### Storage in PostGIS

The database stores both the numeric coordinates and a PostGIS geometry:

```sql
latitude DOUBLE PRECISION,
longitude DOUBLE PRECISION,
geom GEOMETRY(Point, 4326)
```

On upsert the geometry is only created when both coordinates are present:

```sql
CASE
    WHEN ? IS NOT NULL AND ? IS NOT NULL
    THEN ST_SetSRID(ST_MakePoint(?, ?), 4326)
    ELSE NULL
END
```

The parameter order is:

```text
longitude, latitude
```

This ensures that later spatial queries with PostGIS and marker display with Leaflet work without any coordinate transformation.

## REST API

### DTO

```java
package ch.studior2.buildingpermitmonitor.api.dto;

import java.time.LocalDate;
import java.util.UUID;

public record BuildingPermitDto(
        UUID id,
        String title,
        String description,
        String category,
        String status,
        String municipality,
        LocalDate publishedDate,
        String address,
        Double latitude,
        Double longitude
) {
}
```

### Controller

```java
package ch.studior2.buildingpermitmonitor.api.controller;

import ch.studior2.buildingpermitmonitor.api.dto.BuildingPermitDto;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
public class BuildingPermitController {

    private final JdbcTemplate jdbcTemplate;

    public BuildingPermitController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/api/building-permits")
    public List<BuildingPermitDto> findBuildingPermits(
            @RequestParam(required = false) String municipality,
            @RequestParam(required = false) String category
    ) {
        StringBuilder sql = new StringBuilder("""
                SELECT id, title, description, category, status, municipality,
                       published_date, address, latitude, longitude
                FROM building_permits
                WHERE 1 = 1
                """);

        if (municipality != null && !municipality.isBlank()) {
            sql.append(" AND municipality = '").append(municipality.replace("'", "''")).append("'");
        }

        if (category != null && !category.isBlank()) {
            sql.append(" AND category = '").append(category.replace("'", "''")).append("'");
        }

        sql.append(" ORDER BY published_date DESC NULLS LAST, updated_at DESC LIMIT 500");

        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> new BuildingPermitDto(
                UUID.fromString(rs.getString("id")),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("category"),
                rs.getString("status"),
                rs.getString("municipality"),
                rs.getDate("published_date") != null
                        ? rs.getDate("published_date").toLocalDate()
                        : null,
                rs.getString("address"),
                rs.getObject("latitude", Double.class),
                rs.getObject("longitude", Double.class)
        ));
    }
}
```

Note: For the first MVP this is readable. In a more production-ready version, parameterized queries should be used, e.g. with `NamedParameterJdbcTemplate`, to cleanly avoid SQL injection.

Better:

```java
// Next iteration:
// NamedParameterJdbcTemplate + MapSqlParameterSource
```

## Testing the API

Start the API service:

```bash
cd api
mvn spring-boot:run
```

Test the API:

```bash
curl http://localhost:8080/api/building-permits
```

With filter:

```bash
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
```

## Simple Angular Library Module with Leaflet

For the MVP a simple, reusable Angular component in the `web` library is sufficient.

Install:

```bash
npm install leaflet
npm install --save-dev @types/leaflet
```

Angular component, heavily simplified:

```typescript
import { AfterViewInit, Component, Inject } from '@angular/core';
import * as L from 'leaflet';
import {
  BUILDING_PERMIT_MAP_CONFIG,
  BuildingPermitMapConfig,
} from './building-permit-map.config';

interface BuildingPermit {
  title: string;
  description: string;
  municipality: string;
  category: string;
  latitude: number;
  longitude: number;
}

@Component({
  selector: 'bpm-building-permit-map',
  template: '<div id="building-permit-map" style="height: 600px"></div>',
  standalone: true,
})
export class BuildingPermitMapComponent implements AfterViewInit {
  constructor(
    @Inject(BUILDING_PERMIT_MAP_CONFIG)
    private readonly config: BuildingPermitMapConfig,
  ) {}

  async ngAfterViewInit(): Promise<void> {
    const map = L.map('building-permit-map').setView([47.3769, 8.5417], 10);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);

    const response = await fetch(
      `${this.config.apiBaseUrl}/api/building-permits`,
    );
    const permits: BuildingPermit[] = await response.json();

    for (const permit of permits) {
      if (permit.latitude == null || permit.longitude == null) {
        continue;
      }

      L.marker([permit.latitude, permit.longitude]).addTo(map).bindPopup(`
          <strong>${permit.title ?? 'Baugesuch'}</strong><br>
          ${permit.municipality ?? ''}<br>
          ${permit.category ?? ''}<br>
          ${permit.description ?? ''}
        `);
    }
  }
}
```
## Kubernetes and Google Cloud as a Later Target Platform

For local development, Podman Compose is sufficient. For a later deployment, the application can be migrated to Kubernetes. The target platform can be Google Cloud, ideally with the `europe-west6` Zurich region.

A later deployment structure could look like this:

```text
Google Cloud europe-west6
|-- GKE Cluster
|-- PostgreSQL/PostGIS, e.g. Cloud SQL with the PostGIS extension, if suitable
|-- Kafka, either self-hosted or as a separate service
|-- Spring Boot API deployment
|-- Studio r2 web app as the host application
`-- web Angular library as an integrated dependency
```

For the MVP, Kubernetes should not be the first step. The local pipeline must run stably first. After that, Kubernetes manifests or Helm Charts can be added.

The target vision for a later Kubernetes deployment on Google Cloud looks as follows.

![Kubernetes on Google Cloud](docs/architecture/kubernetes-google-cloud.png)

## Testing the Event Flow

### Observe Raw Events

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.raw \
  --from-beginning
```

### Observe Normalized Events

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.normalized \
  --from-beginning
```

### Observe DLQ Events

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.raw.dlq \
  --from-beginning
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.normalized.dlq \
  --from-beginning
```

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.enriched.dlq \
  --from-beginning
```

### Check the Database

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

```sql
SELECT municipality, category, count(*)
FROM building_permits
GROUP BY municipality, category
ORDER BY count(*) DESC;
```

## Step-by-Step Implementation Plan

### Step 1: Create the Repository

```bash
mkdir building-permit-monitor
cd building-permit-monitor
git init
```

### Step 2: Add Podman and Container Compose

Create the `docker-compose.yml` file and define Kafka, PostGIS, and Conduktor Console. The environment is run locally with Podman.

Afterwards:

```bash
podman compose up -d
```

### Step 3: Create the First Spring Boot Module

The recommended first domain module is `ingestor`. This module loads the public data source and writes raw events to Kafka.

```bash
mkdir ingestor
```

Generate the Spring Boot project for `ingestor`.

### Step 4: Create the Contracts Library

The `contracts` module contains the shared event classes and topic constants. It is built locally with Maven and used as a dependency by the Spring Boot services.

```bash
cd contracts
mvn clean install
```

### Step 5: Create Kafka Topics

Create topics manually or automatically on startup.

For the beginning: manually via the Kafka CLI.

### Step 6: Create the Raw Event Model

Class:

```text
BuildingPermitRawEvent.java
```

### Step 7: Implement the CSV Ingestor

Class:

```text
BuildingPermitIngestor.java
```

First test locally with a small test CSV.

### Step 8: Connect the Canton of Zurich CSV

Use the real CSV URL from the data catalog.

Important:

- Inspect the CSV header
- Identify a stable ID column
- Document the relevant columns

### Step 9: Implement the Normalizer

Class:

```text
BuildingPermitNormalizer.java
```

Goal:

- Map raw event to normalized event
- Derive category
- Standardize status
- Extract address and municipality

### Step 10: Implement Persistence

Classes:

```text
BuildingPermitPersistenceConsumer.java
BuildingPermitPersistenceService.java
BuildingPermitEntity.java
BuildingPermitRepository.java
PointFactory.java
```

Goal:

- Consume enriched event
- Store idempotently with Spring Data JPA
- Create PostGIS geometry with Hibernate Spatial and JTS
- Produce no duplicates

### Step 11: Implement the REST API

Endpoint:

```text
GET /api/building-permits
```

Filters:

```text
municipality
category
```

### Step 12: Add the Frontend

First version:

- Map centered on the Canton of Zurich
- Display markers
- Popup with building permit details

### Step 13: Add Screenshots to the README

Screenshots:

- Conduktor Console with topics
- API response
- Map view
- Database query

### Step 14: Add GitHub Actions

Minimal:

```yaml
name: Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '25'
      - name: Check format contracts
        run: mvn -f contracts/pom.xml spotless:check

      - name: Build contracts
        run: mvn -f contracts/pom.xml clean install

      - name: Check format ingestor
        run: mvn -f ingestor/pom.xml spotless:check

      - name: Build ingestor
        run: mvn -f ingestor/pom.xml clean verify

      - name: Check format normalizer
        run: mvn -f normalizer/pom.xml spotless:check

      - name: Build normalizer
        run: mvn -f normalizer/pom.xml clean verify

      - name: Check format enricher
        run: mvn -f enricher/pom.xml spotless:check

      - name: Build enricher
        run: mvn -f enricher/pom.xml clean verify

      - name: Check format persistence
        run: mvn -f persistence/pom.xml spotless:check

      - name: Build persistence
        run: mvn -f persistence/pom.xml clean verify

      - name: Check format API
        run: mvn -f api/pom.xml spotless:check

      - name: Build API
        run: mvn -f api/pom.xml clean verify
```

## Key Technical Decisions

### Why Kafka?

Kafka makes sense here because building permits can be treated as events:

```text
building permit was found
building permit was changed
building permit was normalized
building permit was stored
```

This allows later:

- multiple consumers
- analytics
- alerting
- reprocessing
- event history

### Why PostGIS?

PostGIS extends PostgreSQL with spatial data types and functions. This makes it possible to answer questions later such as:

```text
Which building permits lie within 500 m of a train station?
Which building permits lie within a specific municipal boundary?
Which building permits lie within a noise zone?
```

Example:

```sql
SELECT title, municipality
FROM building_permits
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(8.5417, 47.3769), 4326)::geography,
    1000
);
```

This query finds building permits within a radius of 1000 metres around a point.

### Why Not a Monolith First?

A modular monolith would be simpler to start with. For this project, however, a microservice architecture is strategically more sensible because individual services are intended to be published separately as GitHub projects.

Advantages of the microservice-first approach:

- each service demonstrates a clearly bounded technical competency
- Kafka is not used artificially but forms the integration layer
- services can be tested and started independently
- a Kubernetes deployment is more natural later
- individual repositories are better suited as portfolio artifacts
- the technical cut matches a real data-streaming pipeline

The disadvantage is higher initial effort. This disadvantage is limited by keeping all services minimal at first and starting them together locally via `platform`.

## Error Handling

### Parsing Errors

When a CSV row cannot be processed:

- log the error
- write the raw payload via the central `DefaultErrorHandler` to `building-permit.raw.dlq`
- continue processing

### Kafka Unreachable

For local development, the following is sufficient:

- error in the log
- restart the application

Later:

- retry
- health checks
- backoff

### Database Unreachable

For local development:

```bash
podman compose restart postgres
```

In Spring Boot:

- use the Actuator Health Endpoint
- monitor the database connection via the connection pool

## Post-MVP Extensions

### Enrichment with Geospatial Data

Additional data sources:

- municipal boundaries
- building zones
- public transport stops
- noise zones
- flood zones

### Risk Analyzer

A simple score could be calculated for each building permit:

```text
risk_score = noise_score + flood_score + slope_score + traffic_score
```

### Housing Market Stream

Later, real estate or housing market data could be added:

- rental prices
- vacancy rates
- construction activity
- housing stock

### Kafka Streams

For aggregated analytics:

- building permits per municipality and week
- building permits per category
- rolling averages
- hotspots

Example topics:

```text
building-permit.statistics.daily
building-permit.statistics.weekly
building-permit.statistics.by-municipality
```

## Example Roadmap

### Version 0.1

- Podman and Container Compose
- Kafka
- PostGIS
- manual test events

### Version 0.2

- CSV ingestor
- raw topic
- Conduktor Console

### Version 0.3

- normalizer
- normalized topic
- simple category detection

### Version 0.4

- persistence to PostGIS
- REST API

### Version 0.5

- Angular Library Package
- embeddable map with markers

### Version 0.6

- GeoAdmin geocoding for addresses
- WGS84 coordinates for Leaflet
- PostGIS geometries with `geometry(Point, 4326)`
- optional GPKG import for later GIS extensions

### Version 0.7

- first statistics
- building permits per municipality
- time filter

### Version 1.0

- stable demo
- README with screenshots
- GitHub Actions
- optional deployment on a Swiss VPS

## Pandoc PDF Export

This README can be converted to a PDF with Pandoc.

Example:

```bash
pandoc README.md \
  -o README.pdf \
  --pdf-engine=pdflatex \
  --toc \
  --number-sections
```

For this README, a small LaTeX preamble in `header.tex` is recommended. It enables line breaks in code blocks and reduces overfull-box problems with long file paths, Maven coordinates, Java packages, and URLs. This prevents long examples in the PDF from being cut off on the right.

PlantUML diagrams are deliberately no longer rendered during the Pandoc run via `pandoc-plantuml`. Instead, all diagrams are stored as separate `.puml` files in the `docs/architecture/` directory. This means PDF generation no longer depends on a Java/PlantUML subprocess inside Pandoc.

Render diagrams first:

```bash
find architecture -name "*.puml" -exec plantuml -tpng {} \\;
```

Then generate the PDF:

```bash
pandoc README_live_building_permit_monitor_zh_integrated.md \
  -o README_live_building_permit_monitor_zh.pdf \
  --from markdown \
  --pdf-engine=pdflatex \
  --pdf-engine-opt=-shell-escape \
  --toc \
  --toc-depth=3 \
  --number-sections \
  --highlight-style=tango \
  -V geometry:margin=2.5cm \
  -V fontsize=11pt \
  -V colorlinks=true \
  -V linkcolor=blue \
  -V urlcolor=blue \
  -V documentclass=report \
  -V minted=true \
  -V monofont="DejaVu Sans Mono" \
  --include-in-header=header.tex
```

Important: `--filter pandoc-plantuml` is deliberately omitted. Chapter numbering is not maintained manually in the Markdown. It is generated automatically during rendering via `--number-sections`.

The `header.tex` file should be in the same directory as the README. It contains in particular `breaklines`, `breakanywhere`, `xurl`, `hyphenat`, `\sloppy`, and `\emergencystretch`, so that long code lines, URLs, package names, and file paths can be wrapped in the PDF.

## Further Links

### Public Data

- Canton of Zurich Data Catalog: https://datenkatalog.statistik.zh.ch/
- Building permits in the Canton of Zurich: https://datenkatalog.statistik.zh.ch/datasets/2982%40statistisches-amt-kanton-zürich
- opendata.swiss: https://opendata.swiss/
- geo.admin.ch API: https://api3.geo.admin.ch/

### Kafka

- Apache Kafka Quickstart: https://kafka.apache.org/quickstart/
- Apache Kafka Documentation: https://kafka.apache.org/documentation/
- Spring for Apache Kafka: https://docs.spring.io/spring-kafka/reference/
- Docker Kafka Guide: https://docs.docker.com/guides/kafka/

### PostGIS

- PostGIS Documentation: https://postgis.net/documentation/
- PostGIS Docker: https://postgis.net/documentation/getting_started/install_docker/
- Docker Hub postgis/postgis: https://hub.docker.com/r/postgis/postgis/

### Frontend Maps

- Leaflet: https://leafletjs.com/
- MapLibre: https://maplibre.org/
- OpenStreetMap: https://www.openstreetmap.org/

### Spring Boot

- Spring Boot Documentation: https://docs.spring.io/spring-boot/
- Spring Initializr: https://start.spring.io/

## GitHub README Checklist

Before publication, the repository should contain:

- project description
- architecture diagram
- data source used
- local setup
- Podman and Container Compose guide
- screenshots
- API examples
- known limitations
- roadmap
- license

Recommended license:

```text
MIT License
```

For data sources, the respective terms of use of the original data should additionally be clearly referenced.

## Short Description for GitHub

```text
Kafka-based live monitor for public building permit data in the Canton of Zurich. The system ingests open government data, publishes raw and normalized events to Kafka, stores results in PostGIS and visualizes building permit activity on an interactive map.
```

## Domain Limitations

This project is a technical prototype. It does not replace an official review of building permits and should not be used as a legally binding source.

Possible limitations:

- updates depend on the original dataset
- individual fields may be missing or named differently
- addresses may be incomplete
- geocoding may fail or return imprecise results
- municipal centroids are at most an optional fallback and only approximate positions
- geocoding must be carefully validated

## Next Sensible Development Step

The next concrete step is:

1. Download the CSV file from the Canton of Zurich data catalog.
2. Analyze the header.
3. Determine a stable ID column.
4. Create a mapping table:

```text
CSV column -> internal field
```

Example:

```text
Gemeinde      -> municipality
Bauvorhaben   -> description
Adresse       -> address
Publikation   -> publishedDate
```

After that, the ingestor can be cleanly implemented against the real data structure.


## Additions from 2026-06-04

### Spring Boot 4 + Java Module System

When using `module-info.java` with Spring Boot 4, all packages that Spring accesses via reflection must be explicitly opened.

Typical error message:

```text
IllegalAccessException:
module ... does not open ...config to module spring.core
```

Example:

```java
module ch.studior2.buildingpermitmonitor.persistence {

    requires spring.boot;
    requires spring.boot.autoconfigure;

    opens ch.studior2.buildingpermitmonitor.persistence
        to spring.core, spring.beans, spring.context;

    opens ch.studior2.buildingpermitmonitor.persistence.config
        to spring.core, spring.beans, spring.context;

    opens ch.studior2.buildingpermitmonitor.persistence.entity
        to spring.core, spring.beans, spring.context;
}
```

Recommendation:

- open the main package
- open `config` packages
- open `entity` packages
- open `repository` and `service` packages if Spring or Hibernate accesses them via reflection
- only export DTO and event packages, do not open them unnecessarily
- for repository tests with JPMS issues, configure Surefire with `<useModulePath>false</useModulePath>` as a last resort

### WebClient in the Enricher

The geocoding client uses `WebClient.Builder`.

For this, the `spring-boot-starter-webflux` module must be included:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>
```

Additionally, the builder should be explicitly available as a bean:

```java
@Configuration
public class WebClientConfiguration {

    @Bean
    public WebClient.Builder webClientBuilder() {
        return WebClient.builder();
    }
}
```

This keeps the enricher independent of a later API application and allows it to be started standalone.

### Smoke Tests for All Spring Boot Services

Every microservice should have at least one startup test.

Example:

```java
@SpringBootTest
class ApplicationStartupTest {

    @Test
    void contextLoads() {
    }
}
```

Recommended test classes:

```text
BuildingPermitIngestorApplicationTest
BuildingPermitNormalizerApplicationTest
BuildingPermitEnricherApplicationTest
BuildingPermitPersistenceApplicationTest
BuildingPermitApiApplicationTest
```

Goal:

- Spring context starts successfully
- bean wiring works
- module and reflection configuration is detected early
- missing dependencies become visible already in the CI build

### Test Strategy

Order of tests:

1. Context load test per service
2. Unit tests for mappers and services
3. Kafka integration tests
4. PostgreSQL/PostGIS integration tests
5. End-to-end tests across the complete event pipeline

The context load test is the cheapest way to detect configuration errors early.

## Generating Documentation in the Maven Site Lifecycle

The technical project documentation should not be generated in the normal Maven default lifecycle. A normal build with:

```bash
mvn clean verify
```

continues to only compile, test, and verify the application.

The documentation is deliberately generated in the Maven site lifecycle:

```bash
mvn -N site
```

or, if the entire reactor should be used:

```bash
mvn site
```

The following order applies:

1. All PlantUML diagrams from `docs/architecture/*.puml` are rendered as PNG.
2. Afterwards, the PDF `docs/README.pdf` is created from `docs/README.md` using Pandoc.

### Prerequisites

The following tools must be installed locally:

```bash
pandoc --version
pdflatex --version
plantuml -version
```

For `minted=true`, a LaTeX installation with `minted` and `pygmentize` is also required:

```bash
pygmentize -V
```

Since Pandoc is run with `--pdf-engine-opt=-shell-escape`, this step should only be used for trusted Markdown files and local documentation.

### Root `pom.xml`

The documentation is integrated into the Maven site lifecycle in the root `pom.xml` via the `exec-maven-plugin`.

Important:

- The configuration belongs only in the root module.
- `<inherited>false</inherited>` prevents submodules from executing the same commands again.
- PlantUML runs in `pre-site`.
- Pandoc runs in `post-site`, so that the diagrams are guaranteed to be rendered already.

```xml
<build>
    <plugins>

        <plugin>
            <groupId>org.codehaus.mojo</groupId>
            <artifactId>exec-maven-plugin</artifactId>
            <version>${exec.maven.plugin.version}</version>
            <inherited>false</inherited>

            <executions>

                <!-- ================================================= -->
                <!-- Render PlantUML diagrams                          -->
                <!-- ================================================= -->

                <execution>
                    <id>render-plantuml-diagrams</id>
                    <phase>pre-site</phase>

                    <goals>
                        <goal>exec</goal>
                    </goals>

                    <configuration>
                        <executable>bash</executable>
                        <arguments>
                            <argument>-lc</argument>
                            <argument>
                                mkdir -p docs/architecture &amp;&amp;
                                find docs/architecture -name "*.puml" -print0 |
                                xargs -0 -r plantuml -tpng
                            </argument>
                        </arguments>
                    </configuration>
                </execution>

                <!-- ================================================= -->
                <!-- Generate PDF documentation with Pandoc             -->
                <!-- ================================================= -->

                <execution>
                    <id>generate-documentation-pdf</id>
                    <phase>post-site</phase>

                    <goals>
                        <goal>exec</goal>
                    </goals>

                    <configuration>
                        <executable>pandoc</executable>
                        <arguments>
                            <argument>docs/README.md</argument>
                            <argument>-o</argument>
                            <argument>docs/README.pdf</argument>
                            <argument>--from</argument>
                            <argument>markdown</argument>
                            <argument>--pdf-engine=pdflatex</argument>
                            <argument>--pdf-engine-opt=-shell-escape</argument>
                            <argument>--toc</argument>
                            <argument>--toc-depth=3</argument>
                            <argument>--number-sections</argument>
                            <argument>--highlight-style=tango</argument>
                            <argument>-V</argument>
                            <argument>geometry:margin=2.5cm</argument>
                            <argument>-V</argument>
                            <argument>fontsize=11pt</argument>
                            <argument>-V</argument>
                            <argument>colorlinks=true</argument>
                            <argument>-V</argument>
                            <argument>linkcolor=blue</argument>
                            <argument>-V</argument>
                            <argument>urlcolor=blue</argument>
                            <argument>-V</argument>
                            <argument>documentclass=report</argument>
                            <argument>-V</argument>
                            <argument>minted=true</argument>
                            <argument>-V</argument>
                            <argument>monofont=DejaVu Sans Mono</argument>
                            <argument>--include-in-header=header.tex</argument>
                        </arguments>
                    </configuration>
                </execution>

            </executions>
        </plugin>

    </plugins>
</build>
```

The plugin version is managed centrally in the properties:

```xml
<properties>
    <exec.maven.plugin.version>3.6.3</exec.maven.plugin.version>
</properties>
```

### Recommended Directory Structure

```text
building-permit-monitor/
|-- pom.xml
|-- docs/
|   |-- README.md
|   |-- README.pdf
|   |-- header.tex
|   `-- architecture/
|       |-- kafka-event-flow.puml
|       |-- kafka-event-flow.png
|       |-- microservice-architecture.puml
|       |-- microservice-architecture.png
|       |-- target-architecture.puml
|       `-- target-architecture.png
|-- contracts/
|-- ingestor/
|-- normalizer/
|-- enricher/
|-- persistence/
`-- api/
```

### Invocation

Generate only the documentation in the root module:

```bash
mvn -N site
```

Complete site lifecycle for the entire Maven reactor:

```bash
mvn site
```

If you only want to check that the normal build continues to work independently:

```bash
mvn clean verify
```

### Notes on Paths in Markdown

Images should be referenced in `docs/README.md` relative to the Markdown document:

```markdown
![Kafka Event Flow](docs/architecture/kafka-event-flow.png)

![Microservice Architecture](docs/architecture/microservice-architecture.png)

![Target Architecture](docs/architecture/target-architecture.png)
```

Since Pandoc is invoked from the project root with `docs/README.md`, these relative paths work correctly within the document.
