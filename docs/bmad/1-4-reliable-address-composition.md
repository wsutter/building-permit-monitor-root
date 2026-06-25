# Story: Reliable Address Composition

> **Epic:** 1 — Trustworthy Permit Data
> **Story Key:** 1-4-reliable-address-composition
> **Status:** done
> **Completeness Note:** Ultimate context engine analysis completed — comprehensive developer guide created
> **Baseline Commit:** c80dfb694cb0f4d99db131e0590e547767956b9f
> **Last Updated:** 2026-06-24

---

## Story Requirements

### User Story Statement
As an API consumer,
I want addresses composed reliably,
So that spatial queries return accurate results.

### Acceptance Criteria (BDD)

**Given** address components from the CSV,
**When** they are composed,
**Then** the full address is formatted correctly.

**Given** missing or invalid components,
**When** the address is composed,
**Then** it defaults to a fallback value.

**Given** the address composer,
**When** unit tests run,
**Then** all edge cases are covered.

---

## Developer Context

### Technical Requirements
- **Module:** `normalizer` (Spring Boot service)
- **Primary File:** `AddressComposer.java` (create)
- **Input:** `BuildingPermitRawEvent` → `street`, `streetNumber`, `zip`, `town` fields
- **Output:** `BuildingPermitNormalizedEvent` → `address` field (human-readable string)
- **Integration Point:** `BuildingPermitNormalizer` (calls composer during normalization)
- **Fallback:** If address cannot be composed, default to `"UNKNOWN_ADDRESS"` (never null or empty)

### Architecture Compliance
- **Event Contracts:** Use `BuildingPermitNormalizedEvent` from `contracts` module. Do not modify the event schema.
- **Error Handling:** Missing or invalid components must result in `"UNKNOWN_ADDRESS"`. Never throw exceptions.
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
- **Composer:** `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposer.java`
- **Test:** `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposerTest.java`
- **Integration:** Modify `BuildingPermitRawEventMapper` to call composer during normalization.

### Testing Requirements
- **Unit Tests:** 100% branch coverage for composer logic.
- **Edge Cases:** Null/empty components, missing street number, missing ZIP/town, mixed case, special characters.
- **Integration Test:** Verify `BuildingPermitRawEventMapper` correctly sets `address` in `BuildingPermitNormalizedEvent`.
- **Regression:** Ensure existing address composition (if any) is preserved.

---

## Previous Story Intelligence

### Learnings from Story 1-3
- **Field Stability:** The `street`, `streetNumber`, `zip`, and `town` fields in `BuildingPermitRawEvent` are stable and validated against the live OGD CSV.
- **Testing Patterns:** Use `@ParameterizedTest` for edge case testing. Test fixtures should include real-world examples from the OGD CSV.
- **Error Handling:** Default to `UNKNOWN` or fallback values (never null or exceptions).
- **Integration:** The `NormalizerService` integrates classifiers/normalizers for other fields. Follow the same pattern for address composition.

### Files Modified in Story 1-3
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizer.java`
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/classification/BuildingPermitStatusNormalizerTest.java`
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/mapper/BuildingPermitRawEventMapper.java`

### Git Intelligence
- **Recent Commits:** Focus on `normalizer` module and `contracts` updates.
- **Patterns:** Follow existing test structure (JUnit 6 + AssertJ). Use `@SpringBootTest` for integration tests.
- **Libraries:** No new dependencies required. Use existing Spring Boot, JUnit, and AssertJ.

---

## Latest Technical Information

### AddressComposer Interface
```java
package ch.studior2.buildingpermitmonitor.normalizer.address;

public class AddressComposer {
    public static String compose(String street, String streetNumber, String zip, String town) {
        if (street == null || street.trim().isEmpty()) {
            return "UNKNOWN_ADDRESS";
        }
        
        StringBuilder address = new StringBuilder();
        address.append(street.trim());
        
        if (streetNumber != null && !streetNumber.trim().isEmpty()) {
            address.append(" ").append(streetNumber.trim());
        }
        
        if (zip != null && !zip.trim().isEmpty() && town != null && !town.trim().isEmpty()) {
            address.append(", ").append(zip.trim()).append(" ").append(town.trim());
        } else if (town != null && !town.trim().isEmpty()) {
            address.append(", ").append(town.trim());
        }
        
        return address.toString().isEmpty() ? "UNKNOWN_ADDRESS" : address.toString();
    }
}
```

### Test Template
```java
package ch.studior2.buildingpermitmonitor.normalizer.address;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class AddressComposerTest {
    @ParameterizedTest
    @CsvSource({
        "Bahnhofstrasse, 10, 8000, Zürich, Bahnhofstrasse 10, 8000 Zürich",
        "Hauptstrasse, 5, 8000, , Hauptstrasse 5",
        ", 10, 8000, Zürich, UNKNOWN_ADDRESS",
        "Bahnhofstrasse, , 8000, Zürich, Bahnhofstrasse, 8000 Zürich",
        "Bahnhofstrasse, 10, , Zürich, Bahnhofstrasse 10, Zürich",
        "Bahnhofstrasse, 10, 8000, , Bahnhofstrasse 10",
        " , , , , UNKNOWN_ADDRESS",
        "null, null, null, null, UNKNOWN_ADDRESS"
    })
    void compose_returnsExpectedAddress(String street, String streetNumber, String zip, String town, String expected) {
        assertThat(AddressComposer.compose(street, streetNumber, zip, town))
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

- [x] Task 1: Implement the `AddressComposer` in `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposer.java`.
  - [x] Use the provided interface and logic.
  - [x] Ensure the composer handles edge cases (null, empty, missing components) and defaults to `"UNKNOWN_ADDRESS"`.
- [x] Task 2: Write unit tests in `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposerTest.java`.
  - [x] Use the provided test template.
  - [x] Ensure 100% branch coverage.
  - [x] Include edge cases (null, empty, mixed case, special characters).
- [x] Task 3: Integrate the composer into `BuildingPermitRawEventMapper`.
  - [x] Modify `BuildingPermitRawEventMapper` to call the composer during normalization.
  - [x] Ensure the `address` field in `BuildingPermitNormalizedEvent` is set correctly.
- [x] Task 4: Write an integration test to verify the `BuildingPermitRawEventMapper` correctly sets the `address` field.

## File List
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposer.java` (new)
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/address/AddressComposerTest.java` (new)
- `normalizer/src/main/java/ch/studior2/buildingpermitmonitor/normalizer/mapper/BuildingPermitRawEventMapper.java` (modified)
- `normalizer/src/test/java/ch/studior2/buildingpermitmonitor/normalizer/mapper/BuildingPermitRawEventMapperTest.java` (new)

---

## Story Completion Status

- [x] Story file created
- [x] Requirements extracted from epics, PRD, and architecture
- [x] Developer context section completed
- [x] Previous story learnings incorporated
- [x] Git intelligence analyzed
- [x] Latest technical specifics included
- [x] Implementation completed
- [x] Unit tests written and passing
- [x] Integration tests written and passing
- [x] Status updated to `review`