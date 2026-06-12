# Coding Standards — Building Permit Monitor

> BMAD planning artifact · Author: Walter Sutter · Date: 2026-06-12 · Status: draft
> Distilled from `docs/README.md` (DE) and verified against the actual `pom.xml`, module layout, and service configuration. These are the conventions every module follows.

## 1. Languages & Versions

- **Java 25** (`maven.compiler.release=25`, `-parameters` enabled).
- **Spring Boot 4.0.6** (managed via `spring-boot-dependencies` BOM).
- **JUnit 6** (`junit-bom`), AssertJ, Mockito.
- **Maven 3.9+** as the build tool; multi-module reactor under a central parent POM.
- **Frontend (planned):** npm, Angular 19+ as a **library package** (not a standalone app), Leaflet.

## 2. Module & Naming Conventions

- Maven `groupId` (all Java modules): `ch.studio-r2.building-permit-monitor`.
- `artifactId` = repository/module name: `contracts`, `ingestor`, `normalizer`, `enricher`, `persistence`, `api`.
- Java package base (no hyphens — required for packages & JPMS): `ch.studior2.buildingpermitmonitor`, then `.<module>`.
- Application classes follow `BuildingPermit<Module>Application` (e.g. `BuildingPermitIngestorApplication`).
- Within a service, package by role: `config`, `kafka` / `consumer`, `service`, plus module-specific (`source`, `mapper`, `geocoding`, `entity`, `repository`, `geometry`, `controller`, `dto`).

## 3. Java Module System (JPMS)

- Each Java module ships a `module-info.java`.
- `requires` the Spring modules it uses and `ch.studior2.buildingpermitmonitor.contracts`.
- **`opens`** packages Spring/Hibernate access by reflection — main app package, `config`, `entity` (and `repository`/`service` if reflected on) — to `spring.core, spring.beans, spring.context`.
- **`exports`** DTO and event packages; do not `open` what only needs exporting.
- If JPMS fights Testcontainers/Surefire, fall back to `<useModulePath>false</useModulePath>` for that module's tests.

## 4. Formatting (Spotless — enforced)

- Spotless runs `check` at the `verify` phase; CI runs `mvn spotless:check` only (never auto-apply in CI).
- Java rules: Google/Palantir Java Format, `removeUnusedImports`, `importOrder`, `formatAnnotations`, `trimTrailingWhitespace`, `endWithNewline`. POMs sorted via `sortPom`.
- Apply locally before committing: `mvn spotless:apply`.

## 5. Logging

- Code logs through **SLF4J** (`org.slf4j.Logger` / `LoggerFactory`); runtime is **Log4j2**.
- Exclude `spring-boot-starter-logging`, add `spring-boot-starter-log4j2` in every Spring Boot module (also exclude it transitively where other starters pull it in).
- Config file: `src/main/resources/log4j2-spring.xml`. Project logger `ch.studior2.buildingpermitmonitor` at `INFO`; Kafka at `WARN`; Hibernate SQL at `WARN`.
- Levels: expected business states → `INFO`; processing-blocking technical failures → `ERROR`; verbose diagnostics → `DEBUG`. Prefer parameterized logging: `LOG.info("Skipping duplicate raw event: {}:{}", id, publicationNumber)`.

## 6. Messaging Conventions

- Never hard-code topic names or group ids — use `KafkaTopics.*` and `KafkaGroupIDs.*` from `contracts`.
- Producers key messages meaningfully (raw → external id; normalized/enriched → `permitId`) for partition affinity and ordering.
- Consumers declare `spring.json.trusted.packages: ch.studior2.buildingpermitmonitor.*`.
- Error handling is centralized: import `KafkaDlqConfiguration` from `contracts`; do not write per-service ad-hoc DLQ logic.

## 7. Persistence Conventions

- **Flyway owns the schema.** JPA runs with `ddl-auto: validate`; never `update`/`create`. Add changes as new, immutable, sequentially numbered migrations (`V<n>__description.sql`).
- Business key is `(source, external_id)`; primary key is a deterministic UUID from `permitId`. Writes are **upserts** (find-or-create), never blind inserts.
- Geometry is `GEOMETRY(Point,4326)` via JTS `Point`; build a point only when both coordinates are present.
- **Coordinate order invariant:** events/DTOs expose `latitude`/`longitude`; PostGIS construction takes `(longitude, latitude)`; Leaflet uses `[lat, lon]`. Honor this everywhere.
- JSONB columns mapped with `@JdbcTypeCode(SqlTypes.JSON)`.

## 8. API Conventions

- Use **`NamedParameterJdbcTemplate`** with bind parameters — never concatenate user input into SQL.
- Return DTO records (`BuildingPermitDto`), not entities.
- Cap unbounded result sets (current default `LIMIT 500`) and apply a stable ordering.

## 9. Domain Vocabulary (canonical enums in `contracts`)

- `BuildingPermitCategory`: `NEW_BUILDING, RENOVATION, DEMOLITION, REFURBISHMENT, OTHER, UNKNOWN`.
- `BuildingPermitStatus`: `SUBMITTED, APPROVED, REJECTED, WITHDRAWN, UNKNOWN`.
- `GeocodingProvider`: `GEO_ADMIN` (extensible).
- `GeocodingQuality`: `ADDRESS, PARCEL, MUNICIPALITY, NOT_FOUND`.
- Map undecidable inputs to `UNKNOWN`/`NOT_FOUND` — never invent values, never fabricate coordinates.

## 10. Testing Standards

- Recommended order: (1) Spring context smoke test per service (`@SpringBootTest contextLoads`), (2) unit tests for mappers/services, (3) Kafka integration tests, (4) PostGIS integration tests, (5) end-to-end pipeline tests.
- Every Spring Boot service has at least a context-load test (e.g. `BuildingPermit<Module>ApplicationTest`).
- PostGIS repository tests use **Testcontainers** with `postgis/postgis:17-3.5`.
- Naming: unit tests `*Test.java` (Surefire), integration tests `*IT.java` (Failsafe).
- Run: `mvn test` (unit), `mvn verify` (incl. integration + Spotless + JaCoCo).

## 11. Build & CI

- Whole reactor: `mvn clean verify`. Single module: `mvn -pl <module> clean verify`. With deps: `mvn -pl <module> -am clean verify`.
- `contracts` is installed locally (`mvn -pl contracts install`) so dependents resolve it.
- CI (GitHub Actions) builds per module with Temurin Java 25, running `spotless:check` then `clean verify`.
- Documentation (PlantUML render + Pandoc PDF) is bound to the **Maven `site` lifecycle only**, never the default build.

## 12. Git & `.gitignore`

- Each Java module has its own `.gitignore` (Maven `target/`, IDE files, logs, `*.hprof`, local env/compose artifacts).
- Keep commits scoped per module where practical; do not commit build output or local credentials.

## 13. Security & Data Hygiene

- Local credentials (`app`/`app`, Conduktor admin) are **development-only**; production must use managed secrets.
- Treat geocoded output as non-authoritative; surface quality, never silently fill gaps.
- `--shell-escape` Pandoc/minted PDF generation is for trusted local docs only.
