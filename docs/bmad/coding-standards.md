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

## 11. JUnit Test Standards

### 1. Arrange/Act/Assert Pattern
- Follow the **Arrange/Act/Assert (AAA)** pattern in every test method.
- Clearly separate setup, execution, and verification.

**Example (AAA Pattern):**
```java
@Test
void composeAddress_returnsUnknownForMissingComponents() {
    // Arrange
    BuildingPermitRawEvent event = new BuildingPermitRawEvent(null, null, null, null);
    
    // Act
    String result = AddressComposer.compose(event);
    
    // Assert
    assertEquals("UNKNOWN_ADDRESS", result);
}
```

---

### 2. Comments
- Add **meaningful comments** for:
  - Test classes (purpose of the test suite).
  - Nested test classes (purpose of the group).
  - Test methods (what is being tested and why).

**Example (Comments):**
```java
/**
 * Tests for the AddressComposer utility.
 * Ensures addresses are composed correctly from raw event fields.
 */
@DisplayName("AddressComposer")
class AddressComposerTest {
    /**
     * Tests for valid address components.
     * Ensures the composer handles all valid inputs correctly.
     */
    @Nested
    @DisplayName("When all address components are valid")
    class ValidComponents {
        /**
         * Tests that the composer returns the expected format for a full address.
         */
        @Test
        @DisplayName("composes full address from valid components")
        void composeAddress_returnsExpectedFormat() {}
    }
}
```

---

### 3. Display Names
- Use **`@DisplayName`** for test classes and methods to improve readability.
- Avoid technical jargon; use plain language.

**Example (Display Names):**
```java
@DisplayName("AddressComposer")
class AddressComposerTest {
    @Test
    @DisplayName("composes full address from valid components")
    void composeAddress_returnsExpectedFormat() {}
}
```

---

### 4. Mockito for Unit Tests
- Use **Mockito** to mock dependencies in unit tests.
- Avoid mocking value objects or simple POJOs.

**Example (Mockito):**
```java
@ExtendWith(MockitoExtension.class)
class NormalizerServiceTest {
    @Mock
    private AddressComposer addressComposer;
    
    @InjectMocks
    private NormalizerService normalizerService;
    
    @Test
    void normalize_setsAddressFromComposer() {
        // Arrange
        BuildingPermitRawEvent rawEvent = new BuildingPermitRawEvent("Hauptstrasse", "1", "8000", "Zürich");
        when(addressComposer.compose(rawEvent)).thenReturn("Hauptstrasse 1, 8000 Zürich");
        
        // Act
        BuildingPermitNormalizedEvent result = normalizerService.normalize(rawEvent);
        
        // Assert
        assertEquals("Hauptstrasse 1, 8000 Zürich", result.getAddress());
    }
}
```

---

### 5. Nested Tests
- Use **`@Nested`** to group related test cases logically.
- Add **meaningful comments** for each nested class to explain its purpose.

**Example (Nested Tests):**
```java
@DisplayName("AddressComposer Tests")
class AddressComposerTest {
    @Nested
    @DisplayName("When all address components are valid")
    class ValidComponents {
        // Tests for valid inputs
    }
    
    @Nested
    @DisplayName("When address components are missing")
    class MissingComponents {
        // Tests for missing inputs
    }
}
```

---

### 6. Parameterized Tests
- Use **parameterized tests** wherever possible to reduce boilerplate.
- **Priority Order**: `MethodSource` → `CsvSource` → Other sources.
- **MethodSource**: Return `Stream<Arguments>` for clarity and flexibility.
- **Named Arguments**: Use `Arguments.of(named("description", value))` for readability.

**Example (MethodSource):**
```java
@ParameterizedTest
@MethodSource("addressCombinations")
void composeAddress_returnsExpectedFormat(String street, String houseNumber, String postalCode, String city, String expected) {
    // Arrange
    BuildingPermitRawEvent event = new BuildingPermitRawEvent(street, houseNumber, postalCode, city);
    
    // Act
    String result = AddressComposer.compose(event);
    
    // Assert
    assertEquals(expected, result);
}

static Stream<Arguments> addressCombinations() {
    return Stream.of(
        Arguments.of(named("Full address", "Hauptstrasse 1, 8000 Zürich"), "Hauptstrasse", "1", "8000", "Zürich", "Hauptstrasse 1, 8000 Zürich"),
        Arguments.of(named("Missing street", "UNKNOWN_ADDRESS"), null, "1", "8000", "Zürich", "UNKNOWN_ADDRESS")
    );
}
```

---

### 7. SpringBootTest for Integration Tests
- Use **`@SpringBootTest`** for integration tests that require the Spring context.
- Avoid loading the full context for unit tests.

**Example (SpringBootTest):**
```java
@SpringBootTest
class NormalizerServiceIT {
    @Autowired
    private NormalizerService normalizerService;
    
    @Test
    void normalize_integrationTest() {
        // Arrange
        BuildingPermitRawEvent rawEvent = new BuildingPermitRawEvent("Hauptstrasse", "1", "8000", "Zürich");
        
        // Act
        BuildingPermitNormalizedEvent result = normalizerService.normalize(rawEvent);
        
        // Assert
        assertNotNull(result.getAddress());
    }
}
```

---

### 8. Test Data Randomization and Anonymization
- **Randomize test data** to avoid bias.
- **Anonymize data** to ensure it does not represent real places or addresses.
- Use libraries like **`java-faker`** or **`DataFaker`** for generating realistic but fake data.

**Example (Randomized Data):**
```java
static Stream<Arguments> randomAddressCombinations() {
    Faker faker = new Faker();
    return Stream.of(
        Arguments.of(named("Random full address", faker.address().fullAddress()), faker.address().streetName(), faker.address().buildingNumber(), faker.address().zipCode(), faker.address().city(), faker.address().fullAddress()),
        Arguments.of(named("Random missing street", "UNKNOWN_ADDRESS"), null, faker.address().buildingNumber(), faker.address().zipCode(), faker.address().city(), "UNKNOWN_ADDRESS")
    );
}
```

---

### 9. Testcontainers for Integration Tests
- Use **Testcontainers** for integration tests requiring external dependencies (e.g., databases, Kafka).
- Use **`@Testcontainers`** and **`@Container`** annotations.

**Example (Testcontainers):**
```java
@Testcontainers
class PostGISRepositoryIT {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgis/postgis:17-3.5");
    
    @Test
    void savePermit_persistsData() {
        // Arrange
        PostGISRepository repository = new PostGISRepository(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
        BuildingPermit permit = new BuildingPermit("1", "Hauptstrasse 1, 8000 Zürich");
        
        // Act
        repository.save(permit);
        
        // Assert
        assertTrue(repository.existsById("1"));
    }
}
```

## 11. JUnit Test Standards

*(See previous section for details.)*

## 12. Build & CI

- Whole reactor: `mvn clean verify`. Single module: `mvn -pl <module> clean verify`. With deps: `mvn -pl <module> -am clean verify`.
- `contracts` is installed locally (`mvn -pl contracts install`) so dependents resolve it.
- CI (GitHub Actions) builds per module with Temurin Java 25, running `spotless:check` then `clean verify`.
- Documentation (PlantUML render + Pandoc PDF) is bound to the **Maven `site` lifecycle only**, never the default build.

## 13. Git & `.gitignore`

- Each Java module has its own `.gitignore` (Maven `target/`, IDE files, logs, `*.hprof`, local env/compose artifacts).
- Keep commits scoped per module where practical; do not commit build output or local credentials.

## 14. Java-Specific Rules

### 1. Imports in Alphabetical Order
- Sort imports alphabetically.
- Enforce this via Spotless or Checkstyle.

**Good:**
```java
import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Component;
```

**Bad:**
```java
import org.springframework.stereotype.Component;
import java.util.List;
import java.util.ArrayList;
```

---

### 2. No `.*` Imports
- List every class separately.
- No wildcard imports.

**Good:**
```java
import java.util.ArrayList;
import java.util.List;
```

**Bad:**
```java
import java.util.*;
```

---

### 3. No Fully Qualified Class Paths
- All classes must be explicitly imported.
- No fully qualified class names in the code.

**Good:**
```java
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {}
```

**Bad:**
```java
org.springframework.context.annotation.Configuration
public class AppConfig {}
```

---

### 4. No Large If-ElseIf-Else Blocks
- Replace with **switch expressions** (Java 14+) where possible.
- If switch expressions are not suitable, use polymorphism or strategy patterns.

**Good (Switch Expression):**
```java
String result = switch (status) {
    case "SUCCESS" -> "Operation succeeded";
    case "FAILURE" -> "Operation failed";
    default -> "Unknown status";
};
```

**Good (Polymorphism):**
```java
interface StatusHandler {
    String handle();
}

class SuccessHandler implements StatusHandler {
    @Override
    public String handle() { return "Operation succeeded"; }
}

class FailureHandler implements StatusHandler {
    @Override
    public String handle() { return "Operation failed"; }
}
```

**Bad:**
```java
if (status.equals("SUCCESS")) {
    return "Operation succeeded";
} else if (status.equals("FAILURE")) {
    return "Operation failed";
} else {
    return "Unknown status";
}
```

---

### 5. No Unused Imports
- Remove all unused imports.
- Enforce this via Spotless or Checkstyle.

**Good:**
```java
import java.util.List;

public class Example {
    private List<String> items;
}
```

**Bad:**
```java
import java.util.ArrayList;
import java.util.List;

public class Example {
    private List<String> items;
}
```

---

### 6. Update `module-info.java`
- Ensure `module-info.java` is updated when new packages or modules are added.

**Example:**
```java
module com.example.app {
    requires java.base;
    requires org.springframework.boot;
    exports com.example.app.service;
}
```

---

## 14. Security & Data Hygiene

- Local credentials (`app`/`app`, Conduktor admin) are **development-only**; production must use managed secrets.
- Treat geocoded output as non-authoritative; surface quality, never silently fill gaps.
- `--shell-escape` Pandoc/minted PDF generation is for trusted local docs only.

---

## General Rules

### Formatting
- Use `mvn spotless:apply` to format code before committing.
- Ensure consistent indentation (4 spaces).
- Trim trailing whitespace.
- End files with a newline.