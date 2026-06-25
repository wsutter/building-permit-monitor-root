# Story: Robust Status Normalization

> **Epic:** 1 — Trustworthy Permit Data
> **Story Key:** 1-3-robust-status-normalization
> **Status:** done
> **Completeness Note:** Ultimate context engine analysis completed — comprehensive developer guide created
> **Baseline Commit:** 0336f03
> **Last Updated:** 2026-06-24

---

## Story Requirements

### User Story Statement
As an API consumer,
I want permit statuses normalized to a consistent enum,
So that status filters work reliably.

### Acceptance Criteria (BDD)

**Given** raw status values from the CSV,
**When** they are normalized,
**Then** they map to the `BuildingPermitStatus` enum.

**Given** an unknown status value,
**When** it is normalized,
**Then** it defaults to `UNKNOWN`.

**Given** the normalizer,
**When** unit tests run,
**Then** all status branches are covered.

---

## Developer Context

### Technical Requirements
- **Module:** `normalizer` (Spring Boot service)
- **Primary File:** `BuildingPermitStatusNormalizer.java` (create or extend)
- **Enum:** `BuildingPermitStatus` (in `contracts` module)
- **Test File:** `BuildingPermitStatusNormalizerTest.java` (JUnit 6 + AssertJ)
- **Input:** `BuildingPermitRawEvent` → `status` field (German text)
- **Output:** `BuildingPermitNormalizedEvent` → `status` field (`BuildingPermitStatus` enum)
- **Integration Point:** `BuildingPermitNormalizer` (calls normalizer during normalization)

### Architecture Compliance
- **Event Contracts:** Use `BuildingPermitStatus` enum from `contracts` module. Do not modify the enum or event schemas.
- **Error Handling:** Unknown status values must result in `UNKNOWN` enum value. Never throw exceptions or return null.
- **Testing:** Use JUnit 6 + AssertJ. Testcontainers not required for unit tests.
- **Build:** Maven multi-module. Ensure `contracts` is built before `normalizer`.

### Library & Framework Requirements
- **Java:** 25 (parent POM)
- **Spring Boot:** 4.0.6 (parent POM)
- **JUnit:** 6 (parent POM)
- **AssertJ:** 3.26.3 (parent POM)
- **Spotless:** Enforced at `verify` phase (Google Java Format)
- **JaCoCo:** Coverage enforced (parent POM)

### File Structure Requirements
- **Normalizer:** `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizer.java`
- **Test:** `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizerTest.java`
- **Integration:** Modify `NormalizerService` to call normalizer during normalization.

### Testing Requirements
- **Unit Tests:** 100% branch coverage for normalizer logic.
- **Edge Cases:** Empty string, null, mixed case, partial matches, non-German text.
- **Integration Test:** Verify `NormalizerService` correctly sets `status` in `BuildingPermitNormalizedEvent`.
- **Regression:** Ensure existing status mappings (if any) are preserved.

---

## Previous Story Intelligence

### Learnings from Story 1-2
- **Field Stability:** The `status` field in `BuildingPermitRawEvent` is stable and validated against the live OGD CSV.
- **Enum Usage:** All domain enums (`BuildingPermitStatus`, `BuildingPermitCategory`) are defined in `contracts` and must not be modified without coordination.
- **Testing Patterns:** Use `@ParameterizedTest` for enum mapping tests. Test fixtures should include real-world examples from the OGD CSV.
- **Error Handling:** Unknown values must default to `UNKNOWN` (not null or exceptions).
- **Integration:** The `NormalizerService` already integrates classifiers/normalizers for other fields (e.g., `BuildingPermitCategoryClassifier`). Follow the same pattern for status normalization.

### Files Modified in Story 1-2
- `contracts/src/main/java/ch/studior2/buildingpermitmonitor/contracts/events/BuildingPermitCategory.java` (enum definition)
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitCategoryClassifier.java` (classifier implementation)
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitCategoryClassifierTest.java` (unit tests)
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/NormalizerService.java` (integration point)

### Git Intelligence
- **Recent Commits:** Focus on `normalizer` module and `contracts` updates.
- **Patterns:** Follow existing test structure (JUnit 6 + AssertJ). Use `@SpringBootTest` for integration tests.
- **Libraries:** No new dependencies required. Use existing Spring Boot, JUnit, and AssertJ.

---

## Latest Technical Information

### Enum Definition (`BuildingPermitStatus`)
```java
package ch.studior2.buildingpermitmonitor.contracts.events;

public enum BuildingPermitStatus {
    SUBMITTED,
    APPROVED,
    REJECTED,
    WITHDRAWN,
    UNKNOWN
}
```

### Normalizer Interface
```java
public class BuildingPermitStatusNormalizer {
    public static BuildingPermitStatus normalize(String status) {
        if (status == null || status.trim().isEmpty()) {
            return BuildingPermitStatus.UNKNOWN;
        }
        String normalizedStatus = status.toLowerCase().trim();
        
        if (normalizedStatus.contains("eingereicht") || normalizedStatus.contains("beantragt")) {
            return BuildingPermitStatus.SUBMITTED;
        } else if (normalizedStatus.contains("genehmigt")) {
            return BuildingPermitStatus.APPROVED;
        } else if (normalizedStatus.contains("abgelehnt")) {
            return BuildingPermitStatus.REJECTED;
        } else if (normalizedStatus.contains("zurückgezogen")) {
            return BuildingPermitStatus.WITHDRAWN;
        } else {
            return BuildingPermitStatus.UNKNOWN;
        }
    }
}
```

### Test Template
```java
package ch.studior2.buildingpermitmonitor.normalizer.classification;

import static org.assertj.core.api.Assertions.assertThat;

import ch.studior2.buildingpermitmonitor.contracts.events.BuildingPermitStatus;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class BuildingPermitStatusNormalizerTest {
    @ParameterizedTest
    @CsvSource({
        "Eingereicht, SUBMITTED",
        "Beantragt, SUBMITTED",
        "Genehmigt, APPROVED",
        "Abgelehnt, REJECTED",
        "Zurückgezogen, WITHDRAWN",
        "Unbekannt, UNKNOWN",
        " , UNKNOWN",
        "null, UNKNOWN"
    })
    void normalize_returnsExpectedStatus(String status, BuildingPermitStatus expected) {
        assertThat(BuildingPermitStatusNormalizer.normalize(status))
            .isEqualTo(expected);
    }
}
```

---

## Project Context Reference

### Key Decisions (ADR)
- **AD-1:** Microservices over monolith (each service is an independent repo).
- **AD-2:** Kafka (KRaft) as the backbone for event-driven architecture.
- **AD-3:** PostGIS as the read model for spatial queries.

### Constraints
- **Coordinate Order:** Events expose `(latitude, longitude)`; PostGIS uses `(longitude, latitude)`.
- **Idempotency:** Re-processing the same permit must not create duplicates.
- **Fault Isolation:** Poison messages go to DLQs (3 retries, 1s backoff).

### Dependencies
- **Kafka:** `building-permit.raw` → `building-permit.normalized`
- **PostGIS:** Persistence layer for enriched events.
- **GeoAdmin:** Geocoding service (used in `enricher`).

---

## Tasks/Subtasks

- [x] Task 1: Implement the `BuildingPermitStatusNormalizer` in `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizer.java`.
  - [x] Use the provided interface and logic.
  - [x] Ensure the normalizer handles edge cases (null, empty, unknown statuses) and defaults to `UNKNOWN`.
- [x] Task 2: Write unit tests in `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizerTest.java`.
  - [x] Use the provided test template.
  - [x] Ensure 100% branch coverage.
  - [x] Include edge cases (empty, null, mixed case, partial matches, non-German text).
- [x] Task 3: Integrate the normalizer into `BuildingPermitNormalizer`.
  - [x] Modify `BuildingPermitRawEventMapper` to call the normalizer during normalization.
  - [x] Ensure the `status` field in `BuildingPermitNormalizedEvent` is set correctly.
- [x] Task 4: Write an integration test to verify the `BuildingPermitRawEventMapper` correctly sets the `status` field.

## File List
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizer.java`
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizerTest.java`
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/mapper/BuildingPermitRawEventMapper.java`
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/mapper/BuildingPermitRawEventMapperTest.java`

---

## Story Completion Status

- [x] Story file created
- [x] Requirements extracted from epics, PRD, and architecture
- [x] Developer context section completed
- [x] Previous story learnings incorporated
- [x] Git intelligence analyzed
- [x] Latest technical specifics included
- [x] All tasks implemented and verified
- [ ] Status set to `ready-for-dev`