# Epics for Building Permit Monitor

> **Project:** Building Permit Monitor
> **Last Updated:** 2026-06-24
> **Tracking System:** File-based (BMad)

---

## Epic 1: Trustworthy Permit Data

### **Description**
Ensure the building permit data is accurate, reliable, and well-documented for downstream consumers.

### **Stories**

#### **1-1: Validate and Document the CSV Domain Field Mapping**
- **User Story**: As a data consumer, I want the CSV domain field mapping validated and documented so that I can trust the data structure and semantics.
- **Acceptance Criteria (BDD):**
  - **Given** the OGD CSV schema,
    **When** the mapping is validated,
    **Then** all fields are accounted for and documented.
  - **Given** a field in the CSV,
    **When** it is mapped to the domain model,
    **Then** the mapping is accurate and documented in `docs/domain-mapping.md`.
- **Technical Requirements**:
  - Validate the CSV schema against the domain model.
  - Document mappings in `docs/domain-mapping.md`.

---

#### **1-2: Broaden Building Permit Category Classification**
- **User Story**: As an API consumer, I want permits classified into the correct `BuildingPermitCategory` so that category filters return meaningful results.
- **Acceptance Criteria (BDD):**
  - **Given** representative German project descriptions (e.g., Neubau, Umbau, Rückbau, Sanierung, Nutzungsänderung),
    **When** they are normalized,
    **Then** each maps to the expected enum (NEW_BUILDING, RENOVATION, DEMOLITION, REFURBISHMENT, OTHER).
  - **Given** a description matching no rule,
    **When** it is classified,
    **Then** the category is `UNKNOWN` (never null, never invented).
  - **Given** the classifier,
    **When** unit tests run,
    **Then** `BuildingPermitCategoryClassifierTest` covers each category branch and the UNKNOWN fallback.
- **Technical Requirements**:
  - Implement `BuildingPermitCategoryClassifier` in the `normalizer` module.
  - Add unit tests for all categories and edge cases.

---

#### **1-3: Robust Status Normalization**
- **User Story**: As an API consumer, I want permit statuses normalized to a consistent enum so that status filters work reliably.
- **Acceptance Criteria (BDD):**
  - **Given** raw status values from the CSV,
    **When** they are normalized,
    **Then** they map to the `BuildingPermitStatus` enum.
  - **Given** an unknown status value,
    **When** it is normalized,
    **Then** it defaults to `UNKNOWN`.
  - **Given** the normalizer,
    **When** unit tests run,
    **Then** all status branches are covered.
- **Technical Requirements**:
  - Extend `BuildingPermitStatusNormalizer` in the `normalizer` module.
  - Add unit tests for all status values and edge cases.

---

#### **1-4: Reliable Address Composition**
- **User Story**: As an API consumer, I want addresses composed reliably so that spatial queries return accurate results.
- **Acceptance Criteria (BDD):**
  - **Given** address components from the CSV,
    **When** they are composed,
    **Then** the full address is formatted correctly.
  - **Given** missing or invalid components,
    **When** the address is composed,
    **Then** it defaults to a fallback value.
  - **Given** the address composer,
    **When** unit tests run,
    **Then** all edge cases are covered.
- **Technical Requirements**:
  - Implement `AddressComposer` in the `normalizer` module.
  - Add unit tests for all edge cases.

---

### **Epic Status**
- **Status**: `in-progress`
- **Retrospective**: `optional`

---

## Epic 2: Spatial Query API

### **Description**
Enable spatial queries for building permits to support location-based filtering and analysis.

### **Stories**

#### **2-1: Bounding Box Query Endpoint**
- **User Story**: As an API consumer, I want to query permits within a bounding box so that I can analyze permits in a specific geographic area.
- **Acceptance Criteria (BDD):**
  - **Given** a bounding box (latitude/longitude coordinates),
    **When** the endpoint is called,
    **Then** it returns all permits within the box.
  - **Given** invalid coordinates,
    **When** the endpoint is called,
    **Then** it returns a 400 Bad Request.
  - **Given** the endpoint,
    **When** integration tests run,
    **Then** it returns the correct permits for valid inputs.
- **Technical Requirements**:
  - Implement `/api/permits/bbox` endpoint in the `query` module.
  - Use PostGIS for spatial queries.

---

#### **2-2: Radius Query Endpoint**
- **User Story**: As an API consumer, I want to query permits within a radius of a point so that I can analyze permits near a location.
- **Acceptance Criteria (BDD):**
  - **Given** a point and radius,
    **When** the endpoint is called,
    **Then** it returns all permits within the radius.
  - **Given** invalid input,
    **When** the endpoint is called,
    **Then** it returns a 400 Bad Request.
  - **Given** the endpoint,
    **When** integration tests run,
    **Then** it returns the correct permits for valid inputs.
- **Technical Requirements**:
  - Implement `/api/permits/radius` endpoint in the `query` module.
  - Use PostGIS for spatial queries.

---

### **Epic Status**
- **Status**: `backlog`
- **Retrospective**: `optional`

---

## Epic 3: Engineering Quality & Delivery Hardening

### **Description**
Improve engineering practices, testing, and delivery processes to ensure reliability and maintainability.

### **Stories**

#### **3-1: GitHub Actions CI Pipeline**
- **User Story**: As a developer, I want a CI pipeline for the project so that changes are validated automatically.
- **Acceptance Criteria (BDD):**
  - **Given** a push or pull request,
    **When** the pipeline runs,
    **Then** it runs tests, linting, and builds the project.
  - **Given** a failing test,
    **When** the pipeline runs,
    **Then** the build is marked as failed.
  - **Given** the pipeline,
    **When** it completes successfully,
    **Then** the build is marked as passed.
- **Technical Requirements**:
  - Configure GitHub Actions for the root module.
  - Ensure tests and linting run on every push/PR.

---

#### **3-2: Per-Service Spring Context Smoke Tests**
- **User Story**: As a developer, I want smoke tests for each Spring context so that I can verify service startup and basic functionality.
- **Acceptance Criteria (BDD):**
  - **Given** a Spring service,
    **When** the smoke test runs,
    **Then** the context loads without errors.
  - **Given** a misconfigured service,
    **When** the smoke test runs,
    **Then** it fails and reports the error.
  - **Given** the smoke tests,
    **When** they run in CI,
    **Then** they pass for all services.
- **Technical Requirements**:
  - Add smoke tests for `normalizer`, `enricher`, and `query` services.
  - Configure tests to run in the CI pipeline.

---

#### **3-3: Contract Test Fixtures and Round-Trip Tests**
- **User Story**: As a developer, I want contract test fixtures and round-trip tests so that I can ensure data consistency across services.
- **Acceptance Criteria (BDD):**
  - **Given** a raw event,
    **When** it is normalized and enriched,
    **Then** the output matches the expected contract.
  - **Given** a contract test,
    **When** it runs,
    **Then** it verifies data consistency.
  - **Given** the test suite,
    **When** it runs in CI,
    **Then** all contract tests pass.
- **Technical Requirements**:
  - Implement contract test fixtures for `BuildingPermitRawEvent` and `BuildingPermitNormalizedEvent`.
  - Add round-trip tests for the `normalizer` and `enricher` services.

---

#### **3-4: Maintain `updated_at` on Upsert**
- **User Story**: As a data consumer, I want the `updated_at` field maintained on upsert so that I can track when permits are last updated.
- **Acceptance Criteria (BDD):**
  - **Given** a permit upsert,
    **When** the operation completes,
    **Then** the `updated_at` field is set to the current timestamp.
  - **Given** an existing permit,
    **When** it is updated,
    **Then** the `updated_at` field is updated.
  - **Given** the upsert logic,
    **When** unit tests run,
    **Then** they verify the `updated_at` behavior.
- **Technical Requirements**:
  - Update the upsert logic in the `enricher` service.
  - Add unit tests for `updated_at` behavior.

---

#### **3-5: Decide and Implement Ingestor Persistence Decoupling**
- **User Story**: As a developer, I want the ingestor persistence decoupled so that the system is more modular and maintainable.
- **Acceptance Criteria (BDD):**
  - **Given** the ingestor service,
    **When** the decoupling decision is made,
    **Then** the architecture is updated to reflect the change.
  - **Given** the decoupled ingestor,
    **When** it processes events,
    **Then** it persists data without tight coupling.
  - **Given** the new architecture,
    **When** integration tests run,
    **Then** they verify the decoupled behavior.
- **Technical Requirements**:
  - Decide on the decoupling strategy (e.g., event sourcing, message queues).
  - Implement the decoupled ingestor.
  - Add integration tests for the new architecture.

---

#### **3-6: Reconcile Superseded Snippets in `docs/README.md`**
- **User Story**: As a developer, I want the `docs/README.md` updated so that it reflects the current state of the project.
- **Acceptance Criteria (BDD):**
  - **Given** the `README.md`,
    **When** it is reviewed,
    **Then** all superseded snippets are removed or updated.
  - **Given** the updated `README.md`,
    **When** it is read,
    **Then** it accurately describes the project setup and usage.
- **Technical Requirements**:
  - Review and update `docs/README.md`.
  - Remove or update outdated snippets.

---

### **Epic Status**
- **Status**: `backlog`
- **Retrospective**: `optional`

---

## Epic 4: Interactive Permit Map (Deferred — UX-Gated)

### **Description**
Create an interactive map for visualizing building permits. *(Deferred until UX spec is ready.)*

### **Stories**

#### **4-1: Embeddable Permit Map**
- **User Story**: As a user, I want an embeddable permit map so that I can visualize permits geographically.
- **Acceptance Criteria (BDD):**
  - **Given** the UX spec,
    **When** the map is implemented,
    **Then** it displays permits based on location.
  - **Given** the map,
    **When** it is embedded,
    **Then** it renders correctly in external sites.
- **Technical Requirements**:
  - Implement an embeddable map using Leaflet or Mapbox.
  - Integrate with the Spatial Query API.

---

### **Epic Status**
- **Status**: `backlog`
- **Retrospective**: `optional`

---

## Epic 5: Technical Debt Cleanup

### **Description**
Address technical debt across the codebase, tooling, and processes to improve maintainability, reliability, and integration with external tools.

### **Stories**

#### **5-1: Generate JaCoCo Reports for All Modules**
- **User Story**: As a developer, I want JaCoCo coverage reports generated for every module so that I can track test coverage and ensure quality.
- **Acceptance Criteria (BDD):**
  - **Given** the Maven build process,
    **When** the build is executed,
    **Then** JaCoCo reports are generated for all modules.
  - **Given** a module,
    **When** the report is generated,
    **Then** it is accessible in `target/site/jacoco`.
  - **Given** the CI pipeline,
    **When** the build runs,
    **Then** JaCoCo reports are published as build artifacts.
- **Technical Requirements**:
  - Configure JaCoCo in the parent `pom.xml` and all submodules.
  - Ensure reports are generated during the `verify` phase.
  - Publish reports in GitHub Actions.

---

#### **5-2: Replace AssertJ with JUnit Native Assertions**
- **User Story**: As a developer, I want to use JUnit native assertions instead of AssertJ so that the codebase is consistent and reduces dependency overhead.
- **Acceptance Criteria (BDD):**
  - **Given** a test using AssertJ,
    **When** the test is refactored,
    **Then** it uses JUnit native assertions.
  - **Given** the codebase,
    **When** the refactoring is complete,
    **Then** no AssertJ imports remain.
  - **Given** the test suite,
    **When** tests are run,
    **Then** all tests pass without regressions.
- **Technical Requirements**:
  - Refactor all tests in `normalizer`, `contracts`, and other modules.
  - Remove AssertJ dependency from `pom.xml`.
  - Update imports to use JUnit assertions.

---

#### **5-3: Implement GitHub Actions for Each Submodule**
- **User Story**: As a developer, I want GitHub Actions workflows for each submodule so that changes are validated independently and quickly.
- **Acceptance Criteria (BDD):**
  - **Given** a submodule,
    **When** a push or pull request is made,
    **Then** its GitHub Actions workflow runs.
  - **Given** the workflow,
    **When** it executes,
    **Then** it runs tests, linting, and builds the module.
  - **Given** the CI pipeline,
    **When** a workflow fails,
    **Then** the failure is visible in GitHub.
- **Technical Requirements**:
  - Create `.github/workflows/<module>-ci.yml` for each submodule.
  - Configure workflows to trigger on push and pull requests.
  - Ensure workflows run tests and linting.

---

#### **5-4: Enforce Explicit Class Imports**
- **User Story**: As a developer, I want all dependent classes to be explicitly imported so that the codebase is clean and maintainable.
- **Acceptance Criteria (BDD):**
  - **Given** a Java file,
    **When** it is compiled,
    **Then** no fully-qualified class names remain.
  - **Given** the codebase,
    **When** the refactoring is complete,
    **Then** all classes are explicitly imported.
  - **Given** the build process,
    **When** the code is built,
    **Then** style checks enforce explicit imports.
- **Technical Requirements**:
  - Refactor all Java files to replace fully-qualified class names with imports.
  - Configure Spotless or Checkstyle to enforce this rule.

---

#### **5-5: Integrate Jira with BMad for State Synchronization**
- **User Story**: As a product owner, I want Jira Cloud Service integrated with BMad so that the state of the project is synchronized between both tools.
- **Acceptance Criteria (BDD):**
  - **Given** a BMad story or epic,
    **When** it is created or updated,
    **Then** a corresponding Jira issue is created or updated.
  - **Given** a Jira issue,
    **When** its status changes,
    **Then** the corresponding BMad story or epic is updated.
  - **Given** the integration,
    **When** it is configured,
    **Then** authentication with Jira Cloud is successful.
- **Technical Requirements**:
  - Configure Jira API integration in BMad.
  - Map BMad states (`ready-for-dev`, `done`) to Jira workflows.
  - Set up webhooks or polling for real-time synchronization.

---

#### **5-6: Integrate SonarQube for Code Quality Analysis**
- **User Story**: As a developer, I want SonarQube Cloud Service integrated into the CI pipeline so that code quality is automatically analyzed and enforced.
- **Acceptance Criteria (BDD):**
  - **Given** the CI pipeline,
    **When** the build runs,
    **Then** SonarQube scans the codebase.
  - **Given** the scan,
    **When** it completes,
    **Then** a report is available in the SonarQube dashboard.
  - **Given** the quality gate,
    **When** it fails,
    **Then** the build is marked as failed.
- **Technical Requirements**:
  - Configure SonarQube in GitHub Actions.
  - Set up quality gates for coverage, vulnerabilities, and code smells.
  - Document the integration process.

---

#### **5-7: Automate Minor Releases Using Git Flow**
- **User Story**: As a release manager, I want BMad to automate minor releases using Git Flow when an epic is completed so that releases are consistent and versioned correctly.
- **Acceptance Criteria (BDD):**
  - **Given** an epic marked as `done`,
    **When** the epic is completed,
    **Then** BMad triggers a Git Flow minor release.
  - **Given** the release,
    **When** it is created,
    **Then** it follows semantic versioning (e.g., `1.2.0`).
  - **Given** the release,
    **When** it is published,
    **Then** release notes are generated and included.
  - **Given** the release,
    **When** it is tagged,
    **Then** the tag is pushed to the repository.
- **Technical Requirements**:
  - Configure Git Flow in the repository.
  - Automate release notes generation.
  - Integrate with BMad to trigger releases on epic completion.

---

### **Epic Status**
- **Status**: `backlog`
- **Retrospective**: `optional`