# building-permit-monitor

Eine Kafka-basierte Streaming-Anwendung von Studio r2 zur Verarbeitung öffentlicher Baugesuchs- und GIS-Daten.

## Ziel des Projekts

Dieses Projekt baut einen kleinen, aber realitätsnahen Event-Streaming-Prototypen. Die Anwendung liest öffentliche Baugesuchs-Daten, erkennt neue oder geänderte Bauvorhaben, publiziert diese als Kafka-Events, normalisiert die Daten, speichert sie in PostGIS und stellt sie über eine REST-API sowie ein wiederverwendbares Angular-Kartenmodul zur Verfügung.

Das Projekt eignet sich als privates Portfolio-Projekt auf GitHub, weil es mehrere relevante Themen kombiniert:

- Kafka und Event Streaming
- Spring Boot 4 und Java 25
- öffentliche Datenquellen
- Geodaten und PostGIS
- REST-API Design
- wiederverwendbares Angular-Kartenmodul
- Podman und Container Compose
- spätere Erweiterbarkeit Richtung Risk Analyzer und Housing Market Stream

## MVP-Scope

Der erste MVP verwendet bewusst nur den Kanton Zürich als erste Datenquelle. Der Projektname bleibt dennoch allgemein, damit später weitere Kantone und Datenquellen ergänzt werden können.

### Enthalten im MVP

Der MVP soll Folgendes können:

1. Baugesuchs-Daten des Kantons Zürich periodisch laden.
2. Rohdaten als Events nach Kafka schreiben.
3. Daten normalisieren.
4. Events in PostGIS speichern.
5. Eine REST-API bereitstellen.
6. Baugesuche über ein integrierbares Angular-Kartenmodul anzeigen.
7. Neue oder geänderte Einträge erkennen.

### Nicht im MVP enthalten

Folgende Themen sind bewusst spätere Ausbaustufen:

- vollständige Parzellenanalyse
- Bauzonenanalyse
- Lärm- und Hochwasserrisiko
- Immobilienpreis-Analyse
- Machine Learning
- mehrkantonale Datenintegration
- produktionsreifes User Management
- komplexe Event-Schemata mit Avro oder Protobuf

## Öffentliche Datenquelle

### Primäre Datenquelle

Für den MVP verwenden wir den öffentlichen Datensatz:

- Name: Baugesuche im Kanton Zürich
- Herausgeber: Statistisches Amt Kanton Zürich
- Portal: https://datenkatalog.statistik.zh.ch/
- Suchbegriff: `Baugesuche im Kanton Zürich`
- Formate: CSV, HTML, GPKG

Der Datensatz enthält Bauvorhaben, die im Kanton Zürich beantragt wurden. Für den Einstieg ist CSV am einfachsten, weil es direkt mit Java geladen und geparst werden kann. Für spätere GIS-Auswertungen ist GPKG interessant, weil es Geometrien und räumliche Informationen strukturierter enthalten kann.

### Warum zuerst CSV?

CSV ist für den Anfang sinnvoll, weil:

- es einfach mit Java gelesen werden kann
- keine GDAL-Abhängigkeit notwendig ist
- der Kafka-Ingestor schneller implementiert werden kann
- das Datenmodell zuerst stabilisiert werden kann

### Warum später GPKG?

GPKG, also GeoPackage, ist für GIS besser geeignet, weil:

- Geometrien direkt enthalten sein können
- räumliche Daten sauberer modelliert sind
- Import in PostGIS einfacher automatisiert werden kann
- komplexere Spatial Queries möglich werden

## Zielarchitektur

Die Anwendung wird bewusst von Anfang an als Microservice-Architektur aufgebaut. Das ist für den MVP etwas aufwändiger als ein modularer Monolith, hat aber einen wichtigen Vorteil: Jeder Service kann später als eigenes GitHub-Projekt veröffentlicht, dokumentiert, getestet und weiterentwickelt werden.

Die Services kommunizieren nicht direkt über synchrone REST-Aufrufe, sondern primär über Kafka Events. Dadurch bleibt die Architektur lose gekoppelt und nahe an realen Event-Streaming-Systemen.

Das folgende PlantUML-Diagramm zeigt die Zielarchitektur mit Datenpipeline, Read-Modell, API und der Integration des wiederverwendbaren Angular-Library-Moduls in die Studio-r2-Web-App.

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

Das folgende System-Context-Diagramm zeigt die wichtigsten externen Akteure, Datenquellen und Systemgrenzen.

![System Context](docs/architecture/system-context.png)

### Microservice-Schnitt

Der erste sinnvolle Schnitt sieht so aus:

```text
platform
    lokale Infrastruktur, Podman Compose, Kubernetes Manifeste, Dokumentation

contracts
    gemeinsame Event-Klassen, DTOs, JSON Schemas, Test-Fixtures

ingestor
    liest externe Datenquellen und publiziert Raw Events

normalizer
    normalisiert Raw Events in ein stabiles fachliches Format

enricher
    ergänzt Geodaten, Koordinaten und später Risiko- oder Zonendaten

persistence
    speichert enriched Events in PostgreSQL/PostGIS

api
    stellt Daten für Frontend und externe Clients bereit

web
    Angular 19+ Library mit Leaflet-Kartenkomponenten, die als Dependency in die Studio-r2-Web-App integriert wird
```

Das folgende Container- und Microservice-Diagramm konkretisiert diesen Schnitt.

![Microservice Architecture](docs/architecture/microservice-architecture.png)

### Warum Microservices für dieses Projekt?

Microservices sind hier sinnvoll, weil das Projekt natürlich aus einer Datenpipeline besteht. Jeder Schritt hat eine klare Verantwortung:

- Ingestion: Daten holen
- Normalization: Daten fachlich bereinigen
- Enrichment: Daten geografisch erweitern
- Persistence: Daten speichern
- API: Daten ausliefern
- Web: Daten visualisieren

Das ermöglicht kleine, fokussierte Repositories. Ein Recruiter oder Reviewer kann dadurch einzelne Teile gezielt anschauen, zum Beispiel nur den Kafka Ingestor oder nur die PostGIS API.

### Wichtiges Architekturprinzip

Jeder Microservice soll lokal allein testbar sein, aber im Gesamtsystem über Kafka und Podman Compose zusammenarbeiten.

Das bedeutet:

- jeder Service hat ein eigenes `README.md`
- jeder Service hat ein eigenes Maven- oder npm-Projekt
- jeder Service hat eigene Tests
- jeder Service kann als Container gebaut werden
- die Plattform startet alle Services gemeinsam
- die fachlichen Events liegen zentral in `contracts`

## Ziel-Tech-Stack

Das Projekt läuft unter dem Startup/Branding `Studio r2`. Die öffentliche Website ist:

```text
https://www.studio-r2.ch
```

Der technische Ziel-Stack ist bewusst modern gewählt. Für den MVP muss nicht jede Komponente sofort produktionsreif eingesetzt werden. Die Architektur soll aber so vorbereitet werden, dass die Anwendung später sauber Richtung Kubernetes und Google Cloud erweitert werden kann.

### Backend

- Java 25
- Maven 3.9+
- Spring Boot 4
- Spring for Apache Kafka
- Spring Data JPA
- Spring WebFlux, falls reaktive HTTP-Clients oder Streaming-Endpunkte sinnvoll werden
- Flyway für Datenbankmigrationen
- Jackson für JSON
- Apache Commons CSV für CSV Parsing

### Messaging

- Apache Kafka im KRaft-Modus
- keine ZooKeeper-Abhängigkeit
- Topics für Raw, Normalized, Enriched und Dead Letter Events

### Datenbank

- PostgreSQL
- PostGIS Extension
- Flyway Migrationen
- JPA Entities für fachliche Tabellen
- native SQL oder JDBC dort, wo PostGIS-spezifische Queries einfacher und klarer sind

### Frontend

- npm
- Angular 19+
- Angular Library Package statt eigenständiger Standalone-App
- Leaflet für Kartenvisualisierung
- Integration als Dependency in die bestehende Studio-r2-Web-App

### Lokale Infrastruktur

- Podman
- podman compose oder docker-compose-kompatible Compose-Dateien
- Kafka im KRaft-Modus
- PostgreSQL/PostGIS
- Conduktor Console als lokale Kafka-UI

### Deployment-Ziel

- Kubernetes
- Google Cloud
- Zielregion für produktionsähnliches Deployment: `europe-west6` Zürich

Für den MVP reicht lokal eine Compose-Umgebung mit Podman. Kubernetes und Google Cloud werden zuerst vorbereitet, aber nicht zwingend im ersten Schritt produktiv betrieben.

### Java Package Naming und Maven Coordinates

Die Maven GroupID ist für alle Java-Module identisch:

```text
ch.studio-r2.building-permit-monitor
```

Diese GroupID beschreibt die fachliche Zugehörigkeit der Artefakte. Da Java-Packages und Java-9-Modulnamen keine Bindestriche enthalten dürfen, verwenden wir dafür eine Java-kompatible Schreibweise:

```text
ch.studior2.buildingpermitmonitor
```

Jeder Microservice erhält ein eigenes Package unterhalb dieses Basis-Packages:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

Beispiel für den Ingestor:

```text
ch.studior2.buildingpermitmonitor.ingestor.BuildingPermitIngestorApplication
ch.studior2.buildingpermitmonitor.ingestor.config
ch.studior2.buildingpermitmonitor.ingestor.kafka
ch.studior2.buildingpermitmonitor.ingestor.source
ch.studior2.buildingpermitmonitor.ingestor.service
```

Beispiel für die API:

```text
ch.studior2.buildingpermitmonitor.api.BuildingPermitApiApplication
ch.studior2.buildingpermitmonitor.api.controller
ch.studior2.buildingpermitmonitor.api.repository
ch.studior2.buildingpermitmonitor.api.model
ch.studior2.buildingpermitmonitor.api.dto
```

### Java 9 Module Strategy

Die Java-Services werden als Java-9-Module aufgebaut. Jedes Maven-Projekt enthält deshalb eine eigene `module-info.java`. Die Modulnamen orientieren sich an den Java-Packages und bleiben bewusst ohne Bindestriche.

Empfohlene Modulnamen:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

Die Maven GroupID bleibt trotzdem:

```text
ch.studio-r2.building-permit-monitor
```

Beispiel für `contracts/src/main/java/module-info.java`:

```java
module ch.studior2.buildingpermitmonitor.contracts {
    requires com.fasterxml.jackson.annotation;

    exports ch.studior2.buildingpermitmonitor.contracts.config;
    exports ch.studior2.buildingpermitmonitor.contracts.event;
    exports ch.studior2.buildingpermitmonitor.contracts.model;
    exports ch.studior2.buildingpermitmonitor.contracts.topic;
}
```

Beispiel für `ingestor/src/main/java/module-info.java`:

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

Beispiel für `api/src/main/java/module-info.java`:

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

Hinweis: Spring Boot funktioniert mit Java-Modulen, benötigt aber für Reflection gezielte `opens`-Direktiven. Deshalb werden nur die Spring-Komponenten-Packages geoeffnet, während fachliche DTOs und Event-Klassen explizit exportiert werden.

## Repository-Struktur

Da einzelne Microservices später separat auf GitHub veröffentlicht werden sollen, empfiehlt es sich kein einzelnes grosses Repository als einzige Struktur anzulegen. Besser ist eine Kombination aus mehreren Service-Repositories plus einem Plattform-Repository.

### Empfohlene GitHub-Repositories

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

Dabei ist `platform` das Repository, das alles zusammenführt. Die anderen Repositories können einzeln präsentiert werden.

### Repository: platform

Dieses Repository enthält keine fachliche Business-Logik. Es beschreibt und startet das Gesamtsystem.

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

Dieses Repository ist ideal als Hauptlink im Portfolio.

### Repository: contracts

Dieses Repository enthält gemeinsame Event-Definitionen und Testdaten. Dadurch müssen Event-Klassen nicht in jedem Service kopiert werden.

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

Maven Koordinaten:

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

Verantwortung:

- Datenquelle pollen
- CSV herunterladen
- neue oder geänderte Einträge erkennen
- Raw Events nach Kafka schreiben

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

Verantwortung:

- Raw Events konsumieren
- Felder vereinheitlichen
- Kategorien und Statuswerte normalisieren
- Normalized Events publizieren

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

Verantwortung:

- Adressen geokodieren
- Koordinaten ergänzen
- später Zonen, Lärm, Hochwasser oder ÖV-Nähe ergänzen
- Enriched Events publizieren

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

Verantwortung:

- Enriched Events konsumieren
- Idempotent in PostgreSQL/PostGIS speichern
- Flyway Migrationen verwalten

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

Verantwortung:

- REST API für Karte und externe Clients bereitstellen
- Filter nach Gemeinde, Datum, Kategorie und Bounding Box
- später Streaming-Endpunkte mit WebFlux oder Server-Sent Events

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

Verantwortung:

- Angular 19+ Library Package statt eigenständiger Applikation
- Leaflet-Kartenkomponenten für Baugesuche
- API-Client, Konfiguration und TypeScript-Modelle
- Filter und Detail-Popups als wiederverwendbare Komponenten
- Integration als npm-Dependency in die bestehende Studio-r2-Web-App

### Wann separate Repositories sinnvoll sind

Nicht jeder Microservice muss sofort öffentlich sein. Für den Anfang reichen diese vier Repositories:

```text
platform
contracts
ingestor
api
```

Danach können `normalizer`, `enricher`, `persistence` und `web` folgen.

## Lokale Entwicklungsumgebung

### Voraussetzungen

Installiert sein sollten:

- Java 25
- Maven 3.9+
- npm
- Podman
- podman compose oder podman-compose
- optional Angular CLI
- optional psql

Prüfen:

```bash
java --version
mvn --version
podman --version
podman compose version
```

## Container Compose mit Podman

Für den MVP starten wir Kafka, PostGIS und Conduktor Console lokal mit Podman. Die Datei bleibt bewusst `docker-compose.yml`, weil Compose-Dateien von Docker und Podman verstanden werden. Conduktor ersetzt dabei die einfache Kafka-UI und dient als komfortablere Oberfläche für Topics, Consumer Groups, Messages und später Schema Registry oder Kafka Connect.

Datei: `docker-compose.yml`

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

Datei: `conduktor/platform-config.yaml`

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

Wichtig ist der interne Kafka Listener `kafka:29092`. Der Host verwendet weiterhin `localhost:9092`, aber Conduktor läuft selbst im Compose-Netzwerk und muss Kafka deshalb über den Servicenamen `kafka` erreichen.

Starten:

```bash
podman compose up -d
```

Status prüfen:

```bash
podman compose ps
```

Das lokale Deployment mit Podman Compose sieht damit wie folgt aus.

![Local Podman Compose Deployment](docs/architecture/local-podman-compose-deployment.png)

Conduktor Console öffnen:

```text
http://localhost:8085
```

Login für die lokale Entwicklungsumgebung:

```text
admin@studio-r2.ch / admin
```

PostgreSQL testen:

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

Innerhalb von psql:

```sql
SELECT PostGIS_Version();
```

## Erklärung der wichtigsten Kafka- und Conduktor-Konfigurationen

### Kafka Listener-Konfiguration

```yaml
KAFKA_LISTENERS: PLAINTEXT://:9092,INTERNAL://:29092,CONTROLLER://:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092,INTERNAL://kafka:29092
```

- `PLAINTEXT://:9092`
  - Zugriff vom Host-System.

- `INTERNAL://:29092`
  - Interner Listener für Container innerhalb des Compose-Netzwerks.

- `CONTROLLER://:9093`
  - Interner KRaft-Controller-Listener.

### KRaft-Modus

```yaml
KAFKA_PROCESS_ROLES: broker,controller
KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
```

Diese Konfiguration aktiviert Kafka ohne ZooKeeper.

### Warum zwei PostgreSQL-Container?

- `postgres`
  - Fachliche Datenbank mit PostGIS.

- `conduktor-postgres`
  - Separate Datenbank für Conduktor Console.

### Kafka-Clusterdefinition

```yaml
kafka:
  clusters:
    - id: local
      name: local
      bootstrapServers: kafka:29092
```

Conduktor verwendet `kafka:29092`, weil die Verbindung innerhalb des Compose-Netzwerks erfolgt.

### PostgreSQL-Verbindung prüfen

```bash
podman exec -it bpm-conduktor-postgres   psql -U conduktor -d conduktor -c '\l'
```

## Kafka Topics

Für den MVP verwenden wir diese Topics:

```text
building-permit.raw
building-permit.normalized
building-permit.enriched
building-permit.raw.dlq
building-permit.normalized.dlq
building-permit.enriched.dlq
```

Später können ergänzt werden:

```text
building-permit.statistics.daily
building-permit.statistics.municipality
building-permit.alerts
```

Der folgende Kafka-Event-Flow zeigt, wie Raw, Normalized und Enriched Events durch die Pipeline laufen.

![Kafka Event Flow](docs/architecture/kafka-event-flow.png)

Topics manuell erstellen:

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

Topics anzeigen:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

### Dead-Letter-Topics und zentrale Fehlerbehandlung

Die DLQ-Topics werden nicht direkt von Kafka verwendet. Sie werden erst aktiv, wenn die Spring-Kafka-Consumer einen gemeinsamen `DefaultErrorHandler` verwenden. Diese Konfiguration liegt im `contracts`-Modul und kann von `normalizer`, `enricher` und `persistence` importiert werden.

Die Zuordnung erfolgt anhand des ursprünglichen Input-Topics:

```text
building-permit.raw        -> building-permit.raw.dlq
building-permit.normalized -> building-permit.normalized.dlq
building-permit.enriched   -> building-permit.enriched.dlq
```

Dadurch bleibt sichtbar, in welchem Verarbeitungsschritt ein Event gescheitert ist. Der `exception`-Parameter des Topic-Resolvers wird bewusst noch nicht verwendet; für den MVP reicht die Zuordnung über `record.topic()`.

Beispiel im `contracts`-Modul:

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

Falls die Package-Struktur der Services die `contracts`-Konfiguration nicht automatisch scannt, wird sie in den Kafka-konsumierenden Services explizit importiert:

```java
@Import(KafkaDlqConfiguration.class)
@SpringBootApplication
public class BuildingPermitNormalizerApplication {
    public static void main(String[] args) {
        SpringApplication.run(BuildingPermitNormalizerApplication.class, args);
    }
}
```

Dasselbe Prinzip gilt für `enricher` und `persistence`. Der `ingestor` produziert nur Raw Events und benötigt diese Consumer-DLQ-Konfiguration nicht.

## Spring Boot Microservices erstellen

Dieser Abschnitt ersetzt bewusst die Idee eines einzigen `backend`-Projekts. Die Zielarchitektur besteht aus mehreren kleinen Spring-Boot-Applikationen, die über Kafka miteinander kommunizieren. Nur `contracts` ist eine gemeinsame Java-Bibliothek. `platform` enthält die lokale Infrastruktur und ist keine Spring-Boot-Anwendung.

### Übersicht der Module

| Modul         | Typ                      | Spring Boot? | Hauptaufgabe                                                            |
| ------------- | ------------------------ | -----------: | ----------------------------------------------------------------------- |
| `platform`    | Infrastruktur-Repository |         Nein | Podman Compose, Kafka, PostGIS, Conduktor, Scripts, Dokumentation       |
| `contracts`   | Java Library             |         Nein | Gemeinsame Event-Klassen, DTOs, Topic-Konstanten, JSON-Schemas          |
| `ingestor`    | Microservice             |           Ja | Externe Datenquelle laden und Raw Events publizieren                    |
| `normalizer`  | Microservice             |           Ja | Raw Events konsumieren und fachlich normalisieren                       |
| `enricher`    | Microservice             |           Ja | Geodaten, Koordinaten und spätere Risikodaten ergänzen                  |
| `persistence` | Microservice             |           Ja | Enriched Events konsumieren und nach PostGIS schreiben                  |
| `api`         | Microservice             |           Ja | REST API für Frontend und externe Clients bereitstellen                 |
| `web`         | Angular Library          |         Nein | Wiederverwendbares Kartenmodul für Integration in die Studio-r2-Web-App |

### Kommunikationsprinzip

Die Services rufen sich nicht gegenseitig synchron per REST auf. Die fachliche Pipeline läuft primär asynchron über Kafka.

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

Dadurch bleibt jeder Service klein, testbar und unabhängig deploybar. Kafka bildet die Integrationsschicht, PostgreSQL/PostGIS ist das Query- und Read-Modell für die API.

### Gemeinsame Maven-Konventionen

Alle Java-Repositories verwenden dieselbe GroupID:

```xml
<groupId>ch.studio-r2.building-permit-monitor</groupId>
```

Die ArtifactIDs entsprechen den Repository-Namen:

```text
contracts
ingestor
normalizer
enricher
persistence
api
```

Die Java-Packages verwenden keine Bindestriche:

```text
ch.studior2.buildingpermitmonitor.contracts
ch.studior2.buildingpermitmonitor.ingestor
ch.studior2.buildingpermitmonitor.normalizer
ch.studior2.buildingpermitmonitor.enricher
ch.studior2.buildingpermitmonitor.persistence
ch.studior2.buildingpermitmonitor.api
```

## Gemeinsames Root Parent `pom.xml`

Für das gesamte Multi-Module-Projekt empfiehlt sich ein zentrales Root-Parent-`pom.xml`.  
Alle Java-Module erben davon und verwenden dadurch identische Versionen, Plugin-Konfigurationen, Build-Regeln und Teststandards.

Vorteile:

- zentrale Verwaltung von Java- und Spring-Versionen
- zentrale Verwaltung von JUnit 6
- identische Maven-Plugin-Versionen in allen Services
- gemeinsame Spotless-Formatierung
- zentrale JaCoCo-Konfiguration
- gemeinsame Surefire/Failsafe-Konfiguration
- reproduzierbare Builds
- vereinfachte GitHub-Actions-Pipelines
- konsistente Build-Qualität in allen Microservices

Empfohlene Struktur:

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

### Beispiel eines Submoduls

Beispiel `ingestor/pom.xml`:

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

### Build des gesamten Projekts

Das gesamte Projekt kann danach zentral gebaut werden:

```bash
mvn clean verify
```

Nur ein einzelnes Modul bauen:

```bash
mvn -pl ingestor clean verify
```

Build inklusive aller abhängigen Module:

```bash
mvn -pl api -am clean verify
```

### Automatische Code-Formatierung

Spotless kann zentral verwendet werden:

```bash
mvn spotless:apply
```

Nur prüfen:

```bash
mvn spotless:check
```

### Testen

Alle Unit-Tests:

```bash
mvn test
```

Alle Tests inklusive Integrationstests:

```bash
mvn verify
```

### Erweiterte Spotless-Konfiguration

Für konsistente Formatierung über alle Java-Module hinweg wird zentral `Spotless` verwendet.  
Die Konfiguration kombiniert:

- Google Java Format
- automatische Import-Bereinigung
- konsistente Import-Reihenfolge
- Annotation-Formatierung
- POM-Sorting
- Entfernen von Trailing Whitespace
- erzwungenes Newline am Dateiende
- Javadoc-Formatierung

Empfohlene zentrale Konfiguration im Root Parent `pom.xml`:

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

#### Lokale Formatierung ausführen

Automatische Formatierung:

```bash
mvn spotless:apply
```

Nur prüfen:

```bash
mvn spotless:check
```

#### CI/CD

In GitHub Actions sollte typischerweise nur geprüft werden:

```bash
mvn spotless:check
```

Dadurch verhindert man unerwartete automatische Änderungen während des Builds.

## Gemeinsame Entwicklungsstandards für alle Module

### Log4J2 Konfiguration und Setup

Alle Spring-Boot-Services sollen konsistent über SLF4J loggen. Als konkrete Logging-Implementierung verwenden wir Log4J2. Dadurch bleiben die Klassen unabhängig von der Logging-Implementierung, während Format, Log-Level und Appender zentral konfiguriert werden können.

Wichtiges Prinzip:

```text
Application Code -> SLF4J API -> Log4J2 Runtime
```

Die Java-Klassen verwenden deshalb `org.slf4j.Logger` und `org.slf4j.LoggerFactory`. Log4J2 wird nur über Maven und `log4j2-spring.xml` konfiguriert.

#### Maven-Konfiguration

In jedem Spring-Boot-Service wird der Standard-Logging-Starter ausgeschlossen und `spring-boot-starter-log4j2` ergänzt.

Beispiel für ein Spring-Boot-Modul:

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

Falls ein Modul andere Spring-Boot-Starter verwendet, zum Beispiel `spring-boot-starter-web`, `spring-boot-starter-actuator` oder `spring-boot-starter-data-jpa`, wird `spring-boot-starter-logging` dort ebenfalls ausgeschlossen, falls es transitiv eingezogen wird.

#### `log4j2-spring.xml`

Datei:

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

#### Verwendung im Code

In Service-Klassen wird ein statischer Logger definiert:

```java
private static final Logger LOG = LoggerFactory.getLogger(MyService.class);
```

Danach werden fachlich relevante Ereignisse geloggt:

```java
LOG.info("Skipping duplicate raw event: {}:{}", event.id(), event.publicationNumber());
```

Für erwartbare fachliche Zustände reicht normalerweise `INFO`. Technische Fehler, die eine Verarbeitung verhindern, gehören auf `ERROR`. Sehr detaillierte Diagnoseinformationen gehören auf `DEBUG`.

### `.gitignore`

Die Java-Module `contracts`, `ingestor`, `normalizer`, `enricher`, `persistence` und `api` erhalten jeweils ein eigenes `.gitignore`. Das verhindert, dass IDE-Dateien, Build-Artefakte, lokale Logs oder temporäre Dateien versehentlich ins Repository gelangen.

Datei: `.gitignore`

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

Für `platform` kann dieselbe Datei verwendet werden. Zusätzlich sind lokale Compose-Daten, generierte Logs und temporäre Volumes auszuschliessen:

```gitignore
# Local compose / Podman artefacts
compose/.env
compose/.env.local
logs/
volumes/
.tmp/
```

Für `web` werden zusätzlich Node-, Angular- und Library-Build-Artefakte ignoriert:

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

### Code-Formatierung

Für die Java-Module empfiehlt sich `spotless-maven-plugin`. Spotless ist bewusst pragmatisch: Es läuft lokal über Maven, funktioniert in CI und kann IntelliJ-formatierte Dateien unabhängig von persönlichen IDE-Einstellungen erzwingen.

Empfohlene Regel:

```text
mvn spotless:apply
mvn spotless:check
```

- `spotless:apply` formatiert den Code lokal.
- `spotless:check` prüft im Build, ob alles korrekt formatiert ist.
- In GitHub Actions sollte `spotless:check` vor `mvn verify` laufen.

#### Maven-Konfiguration für alle Java-Module

In allen Java-`pom.xml`-Dateien wird folgender Plugin-Block ergänzt. Bei Spring-Boot-Services steht er innerhalb von `<build><plugins>...</plugins></build>`.

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

Optional kann zusätzlich eine zentrale Datei `spotless.xml` pro Java-Modul abgelegt werden, falls später Import-Reihenfolge, Lizenzheader oder projektspezifische Formatregeln ergänzt werden sollen.

#### Frontend-Formatierung für `web`

Für Angular empfiehlt sich `prettier`.

Datei: `.prettierrc`

```json
{
  "singleQuote": true,
  "semi": true,
  "printWidth": 100,
  "trailingComma": "all"
}
```

Zusätzliche npm Scripts:

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

### Gemeinsame JUnit-6-Konfiguration

Alle Java-Module werden mit JUnit 6 getestet. JUnit 6 verwendet weiterhin das Jupiter-Programmiermodell mit `@Test`, `@ParameterizedTest`, `@MethodSource`, `@DisplayName`, `@Nested`, `Arguments.arguments(...)` und `Named.named(...)`.

In allen Java-Modulen wird folgende Testabhängigkeit ergänzt:

```xml
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>6.0.3</version>
    <scope>test</scope>
</dependency>
```

Für Maven sollte der Surefire-Plugin-Stand bewusst gesetzt werden:

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.5.4</version>
</plugin>
```

Für Spring-Boot-Services bleibt zusätzlich `spring-boot-starter-test` sinnvoll. Wichtig ist, dass die JUnit-Versionen konsistent bleiben. Am saubersten ist Dependency Management über Spring Boot oder, falls nötig, über den JUnit BOM.

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
```

Test-Konventionen:

- Testklassen enden auf `Test`.
- Fachliche Varianten werden bevorzugt als `@ParameterizedTest` geschrieben.
- Datenquellen heissen sprechend, zum Beispiel `classifyBuildingPermitDescriptions()`.
- Jeder Test erhält ein `@DisplayName`.
- Wo mehrere fachliche Gruppen existieren, wird `@Nested` verwendet.
- Testfälle verwenden nach Möglichkeit `arguments(named("Beschreibung", value), expected)`.

## Teststrategie und Beispieltests pro Modul

Die folgenden Tests sind bewusst einfach, aber sinnvoll. Sie testen zuerst reine Logik, Mapper, DTOs, Topic-Konstanten und SQL-/Query-Aufbau. Externe Infrastruktur wie Kafka, PostgreSQL oder HTTP wird im ersten Schritt gemockt oder in Integrationstests verschoben.

### `contracts`: Event- und Topic-Tests

Datei:

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

Datei:

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

### `ingestor`: External-ID- und Payload-Tests

Damit der Ingestor gut testbar ist, sollte die ID-Ermittlung in eine kleine Klasse ausgelagert werden.

Datei:

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

Datei:

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

### `normalizer`: Klassifikation und Mapping testen

Die Mapping-Logik wird in einen dedizierten Mapper verschoben. Der Normalizer bleibt dadurch klein und delegiert die fachliche Transformation an `BuildingPermitRawEventMapper`.

Datei:

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

Datei:

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

### `enricher`: Koordinaten-Fallback testen

Für den Enricher wird die Koordinatenlogik ausgelagert.

Datei:

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

Datei:

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

### `persistence`: UUID- und SQL-Parameter-Tests

Damit der Persistenz-Service ohne echte Datenbank testbar ist, sollte die UUID-Erzeugung ausgelagert werden.

Datei:

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

Datei:

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

### `api`: Query-Parameter und DTO-Mapping testen

Der aktuelle Controller baut SQL direkt im Controller. Für saubere Tests sollte der Query-Aufbau in eine kleine Klasse verschoben werden. Noch besser wäre später `NamedParameterJdbcTemplate`; für den MVP bleibt diese Zwischenlösung verständlich.

Datei:

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

Datei:

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

### Spring-Boot-Application-Smoke-Tests

Für die Spring-Boot-Services kann zusätzlich ein sehr einfacher Context-Test ergänzt werden. Dieser Test muss nicht parameterisiert sein, weil er nur prüft, ob der Spring-Kontext startet. Die fachliche Logik bleibt trotzdem in parameterisierten Unit-Tests.

Beispiel für `api`:

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

Für `ingestor`, `normalizer`, `enricher` und `persistence` wird derselbe Smoke-Test mit der jeweiligen Application-Klasse erstellt.

## Schritt-für-Schritt-Anleitung: Plattform-Repository

Das Plattform-Repository startet die lokale Infrastruktur. Es enthält keine fachliche Java-Logik.

### Schritt 1: Repository erstellen

```bash
mkdir platform
cd platform
git init
```

### Schritt 2: Verzeichnisstruktur anlegen

```bash
mkdir -p compose conduktor scripts docs k8s
```

Empfohlene Struktur:

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

### Schritt 3: Compose-Datei hinzufügen

Die Datei `compose/docker-compose.yml` enthält Kafka, PostGIS, Conduktor Console und die Conduktor-Datenbank. Für lokale Entwicklung bleibt der Dateiname bewusst Docker-kompatibel, auch wenn die Umgebung mit Podman gestartet wird.

```bash
podman compose -f compose/docker-compose.yml up -d
```

### Schritt 4: Conduktor-Konfiguration hinzufügen

Die Datei `conduktor/platform-config.yaml` definiert den lokalen Conduktor-Login, die interne Conduktor-Datenbank und den Kafka-Cluster.

Wichtig:

```yaml
bootstrapServers: kafka:29092
```

Conduktor läuft im Compose-Netzwerk und darf deshalb nicht `localhost:9092` verwenden. `localhost:9092` ist nur für Zugriffe vom Host-System gedacht.

### Schritt 5: Kafka Topics erstellen

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

Ausführbar machen:

```bash
chmod +x scripts/create-topics.sh
./scripts/create-topics.sh
```

### Schritt 6: Infrastruktur prüfen

```bash
podman compose -f compose/docker-compose.yml ps
```

Kafka Topics prüfen:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-topics.sh   --bootstrap-server localhost:9092   --list
```

PostGIS prüfen:

```bash
podman exec -it bpm-postgres psql -U app -d building_permits   -c 'SELECT PostGIS_Version();'
```

Conduktor öffnen:

```text
http://localhost:8085
```

## Schritt-für-Schritt-Anleitung: contracts Library

`contracts` ist keine Spring-Boot-Anwendung. Es ist ein normales Maven-Java-Projekt, das von allen Microservices als Dependency verwendet wird.

### Schritt 1: Projekt erstellen

```bash
mkdir contracts
cd contracts
git init
mkdir -p src/main/java/ch/studior2/buildingpermitmonitor/contracts/{config,event,model,topic}
mkdir -p src/main/resources/schemas
mkdir -p examples
```

### Schritt 2: `pom.xml` erstellen

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

### Schritt 3: Event-Klassen anlegen

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

`latitude` und `longitude` werden im WGS84-Koordinatensystem (`EPSG:4326`) gespeichert. Das passt direkt für Leaflet und kann in PostGIS als `geometry(Point, 4326)` abgelegt werden. Wichtig ist dabei die Reihenfolge: Im Java-Event steht fachlich zuerst `latitude`, dann `longitude`; in PostGIS wird der Punkt aber mit `ST_MakePoint(longitude, latitude)` erzeugt.

### Schritt 4: Topic-Konstanten anlegen

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

### Schritt 5: Library lokal installieren

```bash
mvn clean install
```

Danach können die Spring-Boot-Services diese Dependency verwenden:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
</dependency>
```

## Schritt-für-Schritt-Anleitung: Ingestor Service

`ingestor` ist eine eigenständige Spring-Boot-Applikation. Sie lädt die externe CSV- oder GPKG-Datenquelle und publiziert Raw Events nach Kafka.

### Schritt 1: Spring-Boot-Projekt erzeugen

Mit Spring Initializr:

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

Zusätzlich im `pom.xml`:

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

### Schritt 2: Package-Struktur anlegen

```text
src/main/java/ch/studior2/buildingpermitmonitor/ingestor/
|-- BuildingPermitIngestorApplication.java
|-- config/
|-- kafka/
|-- source/
`-- service/
```

### Schritt 3: Anwendungsklasse erstellen

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

### Schritt 4: `application.yml` konfigurieren

Datei: `src/main/resources/application.yml`

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

### Schritt 5: Kafka Producer implementieren

```java
package ch.studior2.buildingpermitmonitor.ingestor.kafka;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitRawEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
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

### Schritt 6: CSV Ingestor implementieren

Der Ingestor liest die CSV-Datei und publiziert pro Datensatz ein Raw Event. Die stabile External ID muss nach Analyse des echten CSV-Headers sauber ersetzt werden.

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

### Schritt 7: Lokal starten und testen

```bash
mvn spring-boot:run
```

Raw Events beobachten:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server localhost:9092   --topic building-permit.raw   --from-beginning
```

## Schritt-für-Schritt-Anleitung: Normalizer Service

`normalizer` konsumiert Raw Events und erzeugt ein stabiles fachliches Schema.

### Schritt 1: Spring-Boot-Projekt erzeugen

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

Zusätzlich:

```xml
<dependency>
    <groupId>ch.studio-r2.building-permit-monitor</groupId>
    <artifactId>contracts</artifactId>
    <version>0.1.0-SNAPSHOT</version>
</dependency>
```

### Schritt 2: `application.yml` konfigurieren

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

### Schritt 3: Consumer/Producer implementieren

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

### Schritt 4: Testen

```bash
mvn spring-boot:run
```

Normalized Events beobachten:

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh   --bootstrap-server localhost:9092   --topic building-permit.normalized   --from-beginning
```

## Schritt-für-Schritt-Anleitung: Enricher Service

`enricher` konsumiert normalisierte Events, geokodiert die vollständige Adresse und publiziert anschliessend Enriched Events. Die Koordinaten werden nicht mehr statisch pro Gemeinde hinterlegt. Stattdessen wird zuerst die im Normalizer aufgebaute Adresse verwendet, also Strasse, Hausnummer, PLZ und Ort. Die Gemeinde bleibt nur zusätzlicher Kontext.

Für den MVP verwenden wir die GeoAdmin Search API von geo.admin.ch. Die API-Basis-URL und alle fachlich relevanten Parameter werden über `application.yml` konfiguriert. Dadurch bleibt der Client testbar und die konkrete Geocoding-Quelle kann später ausgetauscht werden.

### Schritt 1: Spring-Boot-Projekt erzeugen

```text
Artifact: enricher
Dependencies: Spring for Apache Kafka, WebFlux, Validation, Actuator
```

Zusätzlich wieder `contracts` als Maven Dependency einbinden. `Spring WebFlux` wird hier nicht für einen reaktiven Service verwendet, sondern für den `WebClient`, mit dem der Enricher die GeoAdmin API aufruft.

### Schritt 2: `application.yml` konfigurieren

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

Die wichtigsten Optionen:

- `provider`: fachlicher Name der Geocoding-Quelle. Dieser Wert wird im `BuildingPermitEnrichedEvent` mitgeführt.
- `base-url`: Basis-URL der GeoAdmin API. Sie ist bewusst konfigurierbar und nicht im Code hart verdrahtet.
- `search-path`: API-Pfad für die Location Search.
- `timeout`: maximale Wartezeit pro Geocoding-Request.
- `type`: GeoAdmin-Suchtyp. Für Adressen verwenden wir `locations`.
- `origins`: verwendete GeoAdmin-Quellen. Für Baugesuche sind `address` und später `parcel` interessant.
- `spatial-reference`: `4326` liefert WGS84-Koordinaten, passend für Leaflet und PostGIS `geometry(Point, 4326)`.
- `limit`: Anzahl Treffer. Für den MVP verwenden wir den besten Treffer.

### Schritt 3: Konfigurationsklasse ergänzen

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

### Schritt 4: Geocoding-Client definieren

```java
package ch.studior2.buildingpermitmonitor.enricher.geocoding;

import ch.studior2.buildingpermitmonitor.contracts.model.Coordinates;

public interface GeocodingClient {
  Coordinates findCoordinates(String address, String municipality);
}
```

Die Query-Parameter-Namen der GeoAdmin API werden in eine kleine Konstantenklasse ausgelagert. Damit stehen keine HTTP-Parameternamen verstreut im Client-Code.

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

### Schritt 5: GeoAdmin Client implementieren

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

Wichtig: Der Client fordert mit `sr=4326` WGS84-Koordinaten an. Diese können direkt in Leaflet als `[latitude, longitude]` verwendet werden. Beim Speichern in PostGIS wird daraus `ST_MakePoint(longitude, latitude)`, weil PostGIS bei Punkten die Reihenfolge `x, y` erwartet.

### Schritt 6: Enricher implementieren

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

### Schritt 7: Java-Modul öffnen

Da der Enricher mit Java-Modulen, Spring Reflection, WebFlux und JSON-Deserialisierung arbeitet, braucht `module-info.java` gezielte `requires`- und `opens`-Direktiven.

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

### Schritt 8: Enriched Topic beobachten

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.enriched \
  --from-beginning
```

## Schritt-für-Schritt-Anleitung: Persistence Service

`persistence` konsumiert Enriched Events und speichert sie idempotent in PostgreSQL/PostGIS.

### Schritt 1: Spring-Boot-Projekt erzeugen

```text
Artifact: persistence
Dependencies: Spring for Apache Kafka, Spring JDBC, PostgreSQL Driver, Flyway Migration, Validation, Actuator
```

Zusätzlich `contracts` einbinden.

### Schritt 2: `application.yml` konfigurieren

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

  kafka:
    bootstrap-servers: localhost:9092
    consumer:
      group-id: persistence
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JacksonJsonDeserializer
      properties:
        spring.json.trusted.packages: 'ch.studior2.buildingpermitmonitor.*'
```

### Schritt 3: Flyway Migration erstellen

Datei:

```text
src/main/resources/db/migration/V1__create_building_permits.sql
```

Die Migration erstellt die Tabelle `building_permits` und aktiviert PostGIS. Das vollständige SQL steht im Abschnitt `Datenbankmodell`.

### Schritt 4: Persistence Consumer implementieren

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

@Service
public class BuildingPermitPersistenceConsumer {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public BuildingPermitPersistenceConsumer(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(topics = KafkaTopics.ENRICHED, groupId = KafkaGroupIDs.PERSISTENCE)
    public void persist(BuildingPermitEnrichedEvent event) throws Exception {
        String rawJson = objectMapper.writeValueAsString(event);

        jdbcTemplate.update("""
                INSERT INTO building_permits (
                    id,
                    source,
                    external_id,
                    title,
                    description,
                    category,
                    status,
                    municipality,
                    published_date,
                    address,
                    latitude,
                    longitude,
                    geom,
                    raw_payload,
                    created_at,
                    updated_at
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    CASE
                        WHEN ? IS NOT NULL AND ? IS NOT NULL
                        THEN ST_SetSRID(ST_MakePoint(?, ?), 4326)
                        ELSE NULL
                    END,
                    ?::jsonb,
                    now(),
                    now()
                )
                ON CONFLICT (source, external_id)
                DO UPDATE SET
                    title = EXCLUDED.title,
                    description = EXCLUDED.description,
                    category = EXCLUDED.category,
                    status = EXCLUDED.status,
                    municipality = EXCLUDED.municipality,
                    published_date = EXCLUDED.published_date,
                    address = EXCLUDED.address,
                    latitude = EXCLUDED.latitude,
                    longitude = EXCLUDED.longitude,
                    geom = EXCLUDED.geom,
                    raw_payload = EXCLUDED.raw_payload,
                    updated_at = now()
                """,
                UUID.nameUUIDFromBytes(event.permitId().getBytes(StandardCharsets.UTF_8)),
                event.source(),
                event.externalId(),
                event.title(),
                event.description(),
                event.category(),
                event.status(),
                event.municipality(),
                event.publishedDate(),
                event.address(),
                event.latitude(),
                event.longitude(),
                event.longitude(),
                event.latitude(),
                event.longitude(),
                event.latitude(),
                rawJson
        );
    }
}
```

### Schritt 5: Datenbank prüfen

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

```sql
SELECT municipality, category, count(*)
FROM building_permits
GROUP BY municipality, category
ORDER BY count(*) DESC;
```

## Schritt-für-Schritt-Anleitung: API Service

`api` ist eine eigenständige Spring-Boot-Applikation. Sie konsumiert keine Kafka Events, sondern liest aus PostgreSQL/PostGIS.

### Schritt 1: Spring-Boot-Projekt erzeugen

```text
Artifact: api
Dependencies: Spring Web, Spring JDBC, PostgreSQL Driver, Validation, Actuator
```

Optional kann WebFlux verwendet werden, wenn später Streaming-Endpunkte oder reaktive HTTP-Clients benötigt werden.

### Schritt 2: `application.yml` konfigurieren

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

### Schritt 3: DTO erstellen

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

### Schritt 4: REST Controller erstellen

Für den ersten MVP ist ein einfacher Endpoint ausreichend. In einer späteren Iteration sollte die Query mit `NamedParameterJdbcTemplate` parametrisiert werden.

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

### Schritt 5: API testen

```bash
mvn spring-boot:run
```

```bash
curl http://localhost:8080/api/building-permits
```

```bash
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
```

## Schritt-für-Schritt-Anleitung: Web Angular Library

`web` ist keine eigenständige Angular-Applikation. Das Modul wird als Angular Library gebaut und später als Dependency in die bestehende Studio-r2-Web-App integriert. Dadurch bleibt die Studio-r2-Web-App die eigentliche Host-Applikation, während `web` nur die fachlichen Baugesuch-Komponenten, Services und Modelle bereitstellt.

### Schritt 1: Angular Workspace ohne Applikation erstellen

```bash
npm create angular@latest web -- --create-application=false
cd web
```

Alternativ kann ein bestehender Angular Workspace verwendet werden. Wichtig ist, dass das Baugesuch-Frontend als Library erzeugt wird.

### Schritt 2: Library erzeugen

```bash
npx ng generate library building-permit-map
```

Empfohlene Struktur:

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

### Schritt 3: Leaflet installieren

```bash
npm install leaflet
npm install --save-dev @types/leaflet
```

Leaflet wird im Library-Modul verwendet. Die Host-Applikation muss die Leaflet-CSS-Datei ebenfalls einbinden, z. B. in `angular.json` oder globalen Styles.

### Schritt 4: Konfiguration für die Host-Applikation vorbereiten

Die Library sollte keine fixe API-URL enthalten. Stattdessen stellt sie eine Konfiguration bereit, die von der Studio-r2-Web-App gesetzt wird.

```typescript
export interface BuildingPermitMapConfig {
  apiBaseUrl: string;
}
```

Die Host-Applikation kann später z. B. konfigurieren:

```typescript
provideBuildingPermitMap({
  apiBaseUrl: 'https://api.studio-r2.ch',
});
```

### Schritt 5: Komponenten exportieren

Die Library exportiert ihre öffentlichen Bausteine über `public-api.ts`:

```typescript
export * from './lib/building-permit-map.component';
export * from './lib/building-permit-map.service';
export * from './lib/building-permit-map.config';
export * from './lib/model/building-permit';
```

### Schritt 6: Library bauen

```bash
npm run build building-permit-map
```

Das Ergebnis liegt unter:

```text
dist/building-permit-map
```

### Schritt 7: Integration in die Studio-r2-Web-App

Für lokale Entwicklung kann die Library direkt aus dem lokalen `dist`-Verzeichnis installiert werden:

```bash
cd ../studio-r2-web-app
npm install ../building-permit-monitor/web/dist/building-permit-map
```

Später kann die Library in eine private oder öffentliche npm Registry publiziert und versioniert werden.

## Empfohlene Implementierungsreihenfolge

Für den MVP sollte nicht alles gleichzeitig gebaut werden. Sinnvoll ist diese Reihenfolge:

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

Eine noch schlankere erste Version ist möglich:

```text
1. platform
2. contracts
3. ingestor
4. persistence
5. api
```

In dieser reduzierten Variante publiziert der Ingestor direkt ein normalisiertes Event oder die Persistence speichert vorübergehend Raw/Normalized Events. Der separate Normalizer und Enricher werden danach ergänzt.

## Datenbankmodell

Für den MVP reicht eine zentrale Tabelle.

Datei:

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

Das vereinfachte fachliche Datenmodell sieht so aus.

![Simplified Data Model](docs/architecture/simplified-data-model.png)

## Event-Modell

### Raw Event

Ein Raw Event enthält möglichst viel Originalinformation.

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

Beispiel:

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

Ein normalisiertes Event enthält ein stabiles internes Schema.

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

Beispiel:

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

Ein Enriched Event enthält zusätzlich Koordinaten und Metadaten zur Geokodierung. Die Koordinaten werden in WGS84 (`EPSG:4326`) geführt.

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

Beispiel:

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

## Kafka Topic Konstanten

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

## Kafka Consumer Group Konstanten

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
import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
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

Der Ingestor lädt die CSV-Datei, liest jede Zeile und publiziert pro Zeile ein Raw Event.

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

Scheduling aktivieren:

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

## Warum brauchen wir eine stabile External ID?

Die Anwendung muss erkennen können, ob ein Baugesuch neu, bereits bekannt oder geändert ist.

Dafür brauchen wir:

```text
source + externalId
```

Beispiel:

```text
kt-zh:123456
```

Wenn der Datensatz keine eindeutige ID enthält, kann man vorläufig einen Hash bilden. Besser ist aber eine echte fachliche ID aus der Datenquelle.

Beispiel für einen einfachen Hash:

```java
String fingerprint = DigestUtils.sha256Hex(
        municipality + "|" + address + "|" + description + "|" + publishedDate
);
```

Dafür kann man Apache Commons Codec verwenden:

```xml
<dependency>
    <groupId>commons-codec</groupId>
    <artifactId>commons-codec</artifactId>
    <version>1.19.0</version>
</dependency>
```

## Normalizer Consumer

Der Normalizer konsumiert Raw Events und publiziert Normalized Events.

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

## Persistenz-Service

Der Persistenz-Service konsumiert Enriched Events und speichert sie in PostGIS.

Für den MVP verwenden wir ein normales JDBC Repository, damit das SQL sichtbar und nachvollziehbar bleibt.

```java
package ch.studior2.buildingpermitmonitor.persistence.service;

import ch.studior2.buildingpermitmonitor.contracts.group.KafkaGroupIDs;
import ch.studior2.buildingpermitmonitor.contracts.topic.KafkaTopics;
import ch.studior2.buildingpermitmonitor.contracts.event.BuildingPermitEnrichedEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class BuildingPermitPersistenceConsumer {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public BuildingPermitPersistenceConsumer(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(topics = KafkaTopics.ENRICHED, groupId = KafkaGroupIDs.PERSISTENCE)
    public void persist(BuildingPermitEnrichedEvent event) throws Exception {
        String rawJson = objectMapper.writeValueAsString(event);

        jdbcTemplate.update("""
                INSERT INTO building_permits (
                    id,
                    source,
                    external_id,
                    title,
                    description,
                    category,
                    status,
                    municipality,
                    published_date,
                    address,
                    raw_payload,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb, now(), now())
                ON CONFLICT (source, external_id)
                DO UPDATE SET
                    title = EXCLUDED.title,
                    description = EXCLUDED.description,
                    category = EXCLUDED.category,
                    status = EXCLUDED.status,
                    municipality = EXCLUDED.municipality,
                    published_date = EXCLUDED.published_date,
                    address = EXCLUDED.address,
                    raw_payload = EXCLUDED.raw_payload,
                    updated_at = now()
                """,
                UUID.nameUUIDFromBytes(event.permitId().getBytes()),
                event.source(),
                event.externalId(),
                event.title(),
                event.description(),
                event.category(),
                event.status(),
                event.municipality(),
                event.publishedDate(),
                event.address(),
                rawJson
        );
    }
}
```

## Geokodierung

Die Geokodierung erfolgt nicht mehr über statisch hinterlegte Gemeindezentroide. Diese waren für eine erste Demo zwar einfach, sind für Baugesuche aber fachlich zu ungenau. Ein Baugesuch bezieht sich in der Regel auf ein Grundstück oder mindestens auf eine konkrete Adresse. Deshalb verwendet der Enricher die Adresse aus dem normalisierten Event.

Der Normalizer baut die Adresse aus den verfügbaren Rohdaten zusammen:

```text
Strasse + Hausnummer, PLZ + Ort
```

Beispiel:

```text
Eisenbahnstrasse 27, 8800 Thalwil
```

Diese Adresse wird vom Enricher an den `GeocodingClient` übergeben. Die Gemeinde wird zusätzlich als Kontext ergänzt, damit mehrdeutige Adressen besser aufgelöst werden können.

### GeoAdmin als MVP-Geocoder

Für den MVP verwenden wir die GeoAdmin Search API von `geo.admin.ch`. Sie ist für Schweizer Geodaten fachlich passender als ein generischer internationaler Geocoder. Die Basis-URL und die Query-Optionen stehen in `application.yml` und sind dadurch austauschbar.

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

Wichtig ist `spatial-reference: 4326`. Dadurch liefert der Geocoder WGS84-Koordinaten. Das ist das Standardformat für Webkarten wie Leaflet.

```text
Leaflet Marker: [latitude, longitude]
PostGIS Point:  ST_MakePoint(longitude, latitude)
```

Diese unterschiedliche Reihenfolge ist wichtig. Im Java-Event bleiben die Werte lesbar als `latitude` und `longitude`. Beim Schreiben nach PostGIS wird aber aus technischen Gründen zuerst `longitude` und danach `latitude` übergeben.

### Geocoding Provider und Quality

Das Enriched Event enthält zusätzlich Metadaten zur Geokodierung:

```java
String geocodingProvider,
String geocodingQuality
```

Für den MVP reichen diese Werte:

```text
GeocodingProvider.GEO_ADMIN
GeocodingQuality.ADDRESS
GeocodingQuality.NOT_FOUND
```

Später können weitere Qualitätsstufen ergänzt werden, zum Beispiel `PARCEL`, `STREET` oder `MUNICIPALITY`. Dadurch kann die API oder das Frontend später unterscheiden, ob ein Marker exakt adressbasiert ist oder nur ungefähr gesetzt wurde.

### Fallback-Strategie

Die empfohlene Suchstrategie ist:

1. vollständige Adresse: Strasse, Hausnummer, PLZ, Ort
2. reduzierte Adresse: Strasse, PLZ, Ort
3. Ort oder Gemeinde
4. kein Marker, falls keine belastbaren Koordinaten gefunden werden

Gemeindezentroide bleiben höchstens ein optionaler Fallback. Sie sollten im Frontend klar als ungenau markiert werden und nicht mit exakt geokodierten Adressen vermischt werden.

### Speicherung in PostGIS

Die Datenbank speichert sowohl die numerischen Koordinaten als auch eine PostGIS-Geometrie:

```sql
latitude DOUBLE PRECISION,
longitude DOUBLE PRECISION,
geom GEOMETRY(Point, 4326)
```

Beim Upsert wird die Geometrie nur erzeugt, wenn beide Koordinaten vorhanden sind:

```sql
CASE
    WHEN ? IS NOT NULL AND ? IS NOT NULL
    THEN ST_SetSRID(ST_MakePoint(?, ?), 4326)
    ELSE NULL
END
```

Die Parameterreihenfolge ist dabei:

```text
longitude, latitude
```

Damit funktionieren spätere räumliche Abfragen mit PostGIS und Marker-Anzeigen mit Leaflet ohne Koordinatentransformation.

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

Hinweis: Für den ersten MVP ist das lesbar. In einer produktiveren Version sollte man parametrisierte Queries verwenden, z. B. mit `NamedParameterJdbcTemplate`, um SQL-Injection sauber zu vermeiden.

Besser:

```java
// Nächste Iteration:
// NamedParameterJdbcTemplate + MapSqlParameterSource
```

## API testen

API Service starten:

```bash
cd api
mvn spring-boot:run
```

API testen:

```bash
curl http://localhost:8080/api/building-permits
```

Mit Filter:

```bash
curl "http://localhost:8080/api/building-permits?municipality=Thalwil"
```

## Einfaches Angular-Library-Modul mit Leaflet

Für den MVP kann eine einfache, wiederverwendbare Angular-Komponente in der `web` Library reichen.

Installieren:

```bash
npm install leaflet
npm install --save-dev @types/leaflet
```

Angular-Komponente, stark vereinfacht:

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

## Kubernetes und Google Cloud als spätere Zielplattform

Für die lokale Entwicklung reicht Podman Compose. Für ein späteres Deployment kann die Anwendung in Kubernetes überführt werden. Die Zielplattform kann Google Cloud sein, idealerweise mit der Region `europe-west6` Zürich.

Eine spätere Deployment-Struktur könnte so aussehen:

```text
Google Cloud europe-west6
|-- GKE Cluster
|-- PostgreSQL/PostGIS, z. B. Cloud SQL mit PostGIS Extension, falls passend
|-- Kafka, entweder selbst betrieben oder als separater Dienst
|-- Spring Boot API Deployment
|-- Studio-r2-Web-App als Host-Applikation
`-- web Angular Library als integrierte Dependency
```

Für den MVP sollte Kubernetes aber nicht der erste Schritt sein. Zuerst muss die lokale Pipeline stabil laufen. Danach kann man Kubernetes-Manifeste oder Helm Charts ergänzen.

Das Zielbild für ein späteres Kubernetes-Deployment auf Google Cloud sieht wie folgt aus.

![Kubernetes on Google Cloud](docs/architecture/kubernetes-google-cloud.png)

## Event Flow testen

### Raw Events beobachten

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.raw \
  --from-beginning
```

### Normalized Events beobachten

```bash
podman exec -it bpm-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic building-permit.normalized \
  --from-beginning
```

### DLQ-Events beobachten

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

### Datenbank prüfen

```bash
podman exec -it bpm-postgres psql -U app -d building_permits
```

```sql
SELECT municipality, category, count(*)
FROM building_permits
GROUP BY municipality, category
ORDER BY count(*) DESC;
```

## Schritt-für-Schritt Implementierungsplan

### Schritt 1: Repository erstellen

```bash
mkdir building-permit-monitor
cd building-permit-monitor
git init
```

### Schritt 2: Podman und Container Compose hinzufügen

Datei `docker-compose.yml` erstellen und Kafka, PostGIS sowie Conduktor Console definieren. Ausgeführt wird die Umgebung lokal mit Podman.

Danach:

```bash
podman compose up -d
```

### Schritt 3: Erstes Spring-Boot-Modul erstellen

Als erstes fachliches Modul empfiehlt sich `ingestor`. Dieses Modul lädt die öffentliche Datenquelle und schreibt Raw Events nach Kafka.

```bash
mkdir ingestor
```

Spring-Boot-Projekt für `ingestor` erzeugen.

### Schritt 4: Contracts Library erstellen

Das Modul `contracts` enthält die gemeinsamen Event-Klassen und Topic-Konstanten. Es wird lokal mit Maven gebaut und von den Spring-Boot-Services als Dependency verwendet.

```bash
cd contracts
mvn clean install
```

### Schritt 5: Kafka Topics erstellen

Topics manuell oder beim Start automatisch erstellen.

Für den Anfang: manuell via Kafka CLI.

### Schritt 6: Raw Event Modell erstellen

Klasse:

```text
BuildingPermitRawEvent.java
```

### Schritt 7: CSV Ingestor implementieren

Klasse:

```text
BuildingPermitIngestor.java
```

Zuerst lokal mit einer kleinen Test-CSV testen.

### Schritt 8: Kanton-Zürich-CSV anbinden

Die reale CSV-URL aus dem Datenkatalog verwenden.

Wichtig:

- Header der CSV anschauen
- stabile ID-Spalte identifizieren
- relevante Spalten dokumentieren

### Schritt 9: Normalizer implementieren

Klasse:

```text
BuildingPermitNormalizer.java
```

Ziel:

- Raw Event nach Normalized Event mappen
- Kategorie ableiten
- Status vereinheitlichen
- Adresse und Gemeinde extrahieren

### Schritt 10: Persistenz implementieren

Klasse:

```text
BuildingPermitPersistenceConsumer.java
```

Ziel:

- Enriched Event konsumieren
- Upsert in PostGIS
- keine Duplikate erzeugen

### Schritt 11: REST API implementieren

Endpoint:

```text
GET /api/building-permits
```

Filter:

```text
municipality
category
```

### Schritt 12: Frontend ergänzen

Erste Version:

- Karte zentriert auf Kanton Zürich
- Marker anzeigen
- Popup mit Baugesuch-Details

### Schritt 13: README mit Screenshots ergänzen

Screenshots:

- Conduktor Console mit Topics
- API Response
- Kartenansicht
- Datenbankabfrage

### Schritt 14: GitHub Actions ergänzen

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

## Wichtige technische Entscheidungen

### Warum Kafka?

Kafka ist hier sinnvoll, weil Baugesuche als Events betrachtet werden können:

```text
Baugesuch wurde gefunden
Baugesuch wurde geändert
Baugesuch wurde normalisiert
Baugesuch wurde gespeichert
```

Das erlaubt später:

- mehrere Consumer
- Analytics
- Alerting
- Reprocessing
- Event History

### Warum PostGIS?

PostGIS erweitert PostgreSQL um räumliche Datentypen und Funktionen. Dadurch kann man später Fragen beantworten wie:

```text
Welche Baugesuche liegen innerhalb von 500 m um einen Bahnhof?
Welche Baugesuche liegen in einer bestimmten Gemeindegrenze?
Welche Baugesuche liegen in einem Lärmgebiet?
```

Beispiel:

```sql
SELECT title, municipality
FROM building_permits
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(8.5417, 47.3769), 4326)::geography,
    1000
);
```

Diese Query findet Baugesuche im Umkreis von 1000 Metern um einen Punkt.

### Warum nicht zuerst ein Monolith?

Ein modularer Monolith wäre für den Start einfacher. Für dieses Projekt ist eine Microservice-Architektur aber strategisch sinnvoller, weil einzelne Services separat als GitHub-Projekte veröffentlicht werden sollen.

Vorteile der Microservice-first-Variante:

- jeder Service zeigt eine klar abgegrenzte technische Kompetenz
- Kafka wird nicht künstlich eingesetzt, sondern bildet die Integrationsschicht
- Services können unabhängig getestet und gestartet werden
- später ist ein Kubernetes Deployment natürlicher
- einzelne Repositories eignen sich besser als Portfolio-Artefakte
- der technische Schnitt entspricht einer echten Data-Streaming-Pipeline

Der Nachteil ist höherer initialer Aufwand. Dieser Nachteil wird begrenzt, indem alle Services zuerst minimal gehalten werden und lokal gemeinsam über `platform` gestartet werden.

## Fehlerbehandlung

### Parsing-Fehler

Wenn eine CSV-Zeile nicht verarbeitet werden kann:

- Fehler loggen
- Raw Payload über den zentralen `DefaultErrorHandler` nach `building-permit.raw.dlq` schreiben
- Verarbeitung fortsetzen

### Kafka nicht erreichbar

Für lokale Entwicklung reicht:

- Fehler im Log
- Anwendung neu starten

Später:

- Retry
- Health Checks
- Backoff

### Datenbank nicht erreichbar

Für lokale Entwicklung:

```bash
podman compose restart postgres
```

In Spring Boot:

- Actuator Health Endpoint verwenden
- DB-Verbindung über Connection Pool überwachen

## Erweiterungen nach dem MVP

### Enrichment mit Geodaten

Zusätzliche Datenquellen:

- Gemeindegrenzen
- Bauzonen
- ÖV-Haltestellen
- Lärmzonen
- Hochwasserzonen

### Risk Analyzer

Für jedes Baugesuch könnte ein einfacher Score berechnet werden:

```text
risk_score = noise_score + flood_score + slope_score + traffic_score
```

### Housing Market Stream

Später könnten Immobilien- oder Wohnungsmarktdaten ergänzt werden:

- Mietpreise
- Leerwohnungsziffern
- Bauaktivität
- Wohnungsbestand

### Kafka Streams

Für aggregierte Auswertungen:

- Baugesuche pro Gemeinde und Woche
- Baugesuche pro Kategorie
- gleitende Durchschnittswerte
- Hotspots

Beispielhafte Topics:

```text
building-permit.statistics.daily
building-permit.statistics.weekly
building-permit.statistics.by-municipality
```

## Beispielhafte Roadmap

### Version 0.1

- Podman und Container Compose
- Kafka
- PostGIS
- manuelle Testevents

### Version 0.2

- CSV Ingestor
- Raw Topic
- Conduktor Console

### Version 0.3

- Normalizer
- Normalized Topic
- einfache Kategorie-Erkennung

### Version 0.4

- Persistenz nach PostGIS
- REST API

### Version 0.5

- Angular Library Package
- integrierbare Karte mit Markern

### Version 0.6

- GeoAdmin-Geocoding für Adressen
- WGS84-Koordinaten für Leaflet
- PostGIS-Geometrien mit `geometry(Point, 4326)`
- optionaler GPKG-Import für spätere GIS-Erweiterungen

### Version 0.7

- erste Statistiken
- Baugesuche pro Gemeinde
- Zeitfilter

### Version 1.0

- stabile Demo
- README mit Screenshots
- GitHub Actions
- optional Deployment auf Schweizer VPS

## Pandoc PDF Export

Dieses README kann mit Pandoc in ein PDF umgewandelt werden.

Beispiel:

```bash
pandoc README.md \
  -o README.pdf \
  --pdf-engine=pdflatex \
  --toc \
  --number-sections
```

Für dieses README wird eine kleine LaTeX-Präambel in `header.tex` empfohlen. Sie aktiviert Zeilenumbrüche in Code-Blöcken und reduziert Overfull-Box-Probleme bei langen Dateipfaden, Maven-Koordinaten, Java-Packages und URLs. Dadurch werden lange Beispiele im PDF nicht mehr rechts abgeschnitten.

PlantUML-Diagramme werden bewusst nicht mehr während des Pandoc-Laufs über `pandoc-plantuml` gerendert. Stattdessen liegen alle Diagramme als separate `.puml`-Dateien im Verzeichnis `docs/architecture/`. Dadurch hängt die PDF-Generierung nicht an einem Java-/PlantUML-Subprozess innerhalb von Pandoc.

Diagramme zuerst rendern:

```bash
find architecture -name "*.puml" -exec plantuml -tpng {} \\;
```

Danach das PDF erzeugen:

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

Wichtig: `--filter pandoc-plantuml` entfällt bewusst. Die Kapitelnummerierung wird nicht manuell im Markdown gepflegt. Sie entsteht beim Rendern automatisch über `--number-sections`.

Die Datei `header.tex` sollte im gleichen Verzeichnis wie das README liegen. Sie enthält insbesondere `breaklines`, `breakanywhere`, `xurl`, `hyphenat`, `\sloppy` und `\emergencystretch`, damit lange Code-Zeilen, URLs, Package-Namen und Dateipfade im PDF umgebrochen werden können.

## Weiterführende Links

### Öffentliche Daten

- Kanton Zürich Datenkatalog: https://datenkatalog.statistik.zh.ch/
- Baugesuche im Kanton Zürich: https://datenkatalog.statistik.zh.ch/datasets/2982%40statistisches-amt-kanton-zürich
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

## GitHub README Checkliste

Vor Veröffentlichung sollte das Repository enthalten:

- Projektbeschreibung
- Architekturdiagramm
- verwendete Datenquelle
- lokales Setup
- Podman und Container Compose Anleitung
- Screenshots
- API Beispiele
- bekannte Einschränkungen
- Roadmap
- Lizenz

Empfohlene Lizenz:

```text
MIT License
```

Für Datenquellen sollte zusätzlich klar auf die jeweiligen Nutzungsbedingungen der Originaldaten verwiesen werden.

## Kurzbeschreibung für GitHub

```text
Kafka-based live monitor for public building permit data in the Canton of Zurich. The system ingests open government data, publishes raw and normalized events to Kafka, stores results in PostGIS and visualizes building permit activity on an interactive map.
```

## Fachliche Einschränkungen

Dieses Projekt ist ein technischer Prototyp. Es ersetzt keine amtliche Prüfung von Baugesuchen und sollte nicht als rechtlich verbindliche Quelle verwendet werden.

Mögliche Einschränkungen:

- Aktualisierung hängt vom Originaldatensatz ab
- einzelne Felder können fehlen oder anders benannt sein
- Adressen können unvollständig sein
- Geokodierung kann fehlschlagen oder ungenaue Treffer liefern
- Gemeindezentroide sind höchstens ein optionaler Fallback und nur ungefähre Positionen
- Geokodierung muss sorgfältig validiert werden

## Nächster sinnvoller Entwicklungsschritt

Der nächste konkrete Schritt ist:

1. CSV-Datei aus dem Kanton-Zürich-Datenkatalog herunterladen.
2. Header analysieren.
3. stabile ID-Spalte bestimmen.
4. Mapping-Tabelle erstellen:

```text
CSV column -> internal field
```

Beispiel:

```text
Gemeinde      -> municipality
Bauvorhaben   -> description
Adresse       -> address
Publikation   -> publishedDate
```

Danach kann der Ingestor sauber gegen die reale Datenstruktur implementiert werden.


## Ergänzungen vom 04.06.2026

### Spring Boot 4 + Java Module System

Bei Verwendung von `module-info.java` mit Spring Boot 4 müssen alle Pakete, auf die Spring per Reflection zugreift, explizit geöffnet werden.

Typische Fehlermeldung:

```text
IllegalAccessException:
module ... does not open ...config to module spring.core
```

Beispiel:

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

Empfehlung:

- Hauptpackage öffnen
- `config`-Packages öffnen
- `entity`-Packages öffnen
- weitere Spring-komponentisierte Packages bei Bedarf öffnen

### WebClient im Enricher

Der Geocoding-Client verwendet `WebClient.Builder`.

Dafür muss das Modul `spring-boot-starter-webflux` eingebunden sein:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-webflux</artifactId>
</dependency>
```

Zusätzlich sollte der Builder explizit als Bean verfügbar sein:

```java
@Configuration
public class WebClientConfiguration {

    @Bean
    public WebClient.Builder webClientBuilder() {
        return WebClient.builder();
    }
}
```

Dadurch bleibt der Enricher unabhängig von einer späteren API-Anwendung und kann eigenständig gestartet werden.

### Smoke Tests für alle Spring-Boot-Services

Jeder Microservice sollte mindestens einen Start-Up-Test besitzen.

Beispiel:

```java
@SpringBootTest
class ApplicationStartupTest {

    @Test
    void contextLoads() {
    }
}
```

Empfohlene Testklassen:

```text
BuildingPermitIngestorApplicationTest
BuildingPermitNormalizerApplicationTest
BuildingPermitEnricherApplicationTest
BuildingPermitPersistenceApplicationTest
BuildingPermitApiApplicationTest
```

Ziel:

- Spring Context startet erfolgreich
- Bean-Wiring funktioniert
- Modul- und Reflection-Konfiguration wird früh erkannt
- fehlende Dependencies werden bereits im CI-Build sichtbar

### Teststrategie

Reihenfolge der Tests:

1. Context-Load-Test pro Service
2. Unit-Tests für Mapper und Services
3. Kafka-Integrationstests
4. PostgreSQL/PostGIS-Integrationstests
5. End-to-End-Tests über die komplette Event-Pipeline

Der Context-Load-Test ist die günstigste Möglichkeit, Konfigurationsfehler früh zu erkennen.

## Dokumentation im Maven Site Lifecycle generieren

Die technische Projektdokumentation soll nicht im normalen Maven Default Lifecycle erzeugt werden. Ein normaler Build mit:

```bash
mvn clean verify
```

kompiliert, testet und prüft weiterhin nur die Anwendung.

Die Dokumentation wird bewusst im Maven Site Lifecycle erzeugt:

```bash
mvn -N site
```

oder, falls der gesamte Reactor verwendet werden soll:

```bash
mvn site
```

Dabei gilt folgende Reihenfolge:

1. Alle PlantUML-Diagramme aus `docs/architecture/*.puml` werden als PNG gerendert.
2. Danach wird aus `docs/README.md` mit Pandoc das PDF `docs/README.pdf` erstellt.

### Voraussetzungen

Lokal müssen folgende Tools installiert sein:

```bash
pandoc --version
pdflatex --version
plantuml -version
```

Für `minted=true` wird ausserdem eine LaTeX-Installation mit `minted` und `pygmentize` benötigt:

```bash
pygmentize -V
```

Da Pandoc mit `--pdf-engine-opt=-shell-escape` ausgeführt wird, sollte dieser Schritt nur für vertrauenswürdige Markdown-Dateien und lokale Dokumentation verwendet werden.

### Root `pom.xml`

Die Dokumentation wird im Root-`pom.xml` über das `exec-maven-plugin` in den Maven Site Lifecycle eingebunden.

Wichtig:

- Die Konfiguration gehört nur ins Root-Modul.
- `<inherited>false</inherited>` verhindert, dass Submodule dieselben Befehle erneut ausführen.
- PlantUML läuft in `pre-site`.
- Pandoc läuft in `post-site`, damit die Diagramme sicher bereits gerendert sind.

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

Die Plugin-Version wird zentral in den Properties verwaltet:

```xml
<properties>
    <exec.maven.plugin.version>3.6.3</exec.maven.plugin.version>
</properties>
```

### Empfohlene Verzeichnisstruktur

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

### Aufruf

Nur die Dokumentation im Root-Modul erzeugen:

```bash
mvn -N site
```

Kompletter Site-Lifecycle für den ganzen Maven-Reactor:

```bash
mvn site
```

Falls nur geprüft werden soll, ob der normale Build weiterhin unabhängig funktioniert:

```bash
mvn clean verify
```

### Hinweise zu Pfaden in Markdown

Die Bilder sollten in `docs/README.md` relativ zum Markdown-Dokument referenziert werden:

```markdown
![Kafka Event Flow](docs/architecture/kafka-event-flow.png)

![Microservice Architecture](docs/architecture/microservice-architecture.png)

![Target Architecture](docs/architecture/target-architecture.png)
```

Da Pandoc aus dem Projekt-Root mit `docs/README.md` aufgerufen wird, funktionieren diese relativen Pfade innerhalb des Dokuments korrekt.
