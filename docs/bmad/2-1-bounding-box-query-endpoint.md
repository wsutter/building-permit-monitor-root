---
story_key: 2-1-bounding-box-query-endpoint
epic: 2
story_num: 1
status: ready-for-dev
baseline_commit: $(git rev-parse HEAD)
feature_branch: feature/2-1-bounding-box-query-endpoint
---

# Story 2-1: Bounding Box Query Endpoint

## Story
**As an API consumer**, I want to query permits within a bounding box so that I can analyze permits in a specific geographic area.

## Acceptance Criteria (BDD)
- **Given** a bounding box (latitude/longitude coordinates),
  **When** the endpoint is called,
  **Then** it returns all permits within the box.
- **Given** invalid coordinates,
  **When** the endpoint is called,
  **Then** it returns a 400 Bad Request.
- **Given** the endpoint,
  **When** integration tests run,
  **Then** it returns the correct permits for valid inputs.

## Tasks
- [ ] Implement `/api/permits/bbox` endpoint in the `api` module.
- [ ] Add PostGIS spatial query for bounding box filtering.
- [ ] Add input validation for coordinates.
- [ ] Write integration tests for the endpoint.

## Dev Notes
### Architecture Context
- **Module**: `api` (Spring Boot)
- **Database**: PostGIS (spatial queries)
- **Endpoint**: `GET /api/permits/bbox?minLat={minLat}&minLon={minLon}&maxLat={maxLat}&maxLon={maxLon}`
- **Response**: JSON array of permits within the bounding box.

### Technical Requirements
- Use PostGIS `ST_MakeEnvelope` for bounding box queries.
- Validate coordinates: `minLat < maxLat`, `minLon < maxLon`, and within valid ranges.
- Return 400 Bad Request for invalid input.

### Files to Modify
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/controller/PermitController.java` (Add endpoint)
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/repository/PermitRepository.java` (Add spatial query)
- `api/src/test/java/ch/studior2/buildingpermitmonitor/api/controller/PermitControllerIT.java` (Add integration tests)

### Testing
- **Integration Tests**: Verify endpoint returns correct permits for valid/invalid inputs.
- **Edge Cases**: Empty results, invalid coordinates, large bounding boxes.

## Dev Agent Record
### Implementation Plan
1. Add `PermitRepository.findWithinBoundingBox` with PostGIS query.
2. Add `PermitController.getPermitsByBoundingBox` endpoint.
3. Add input validation and error handling.
4. Write integration tests.

### Completion Notes
- [ ] Endpoint implemented and tested.
- [ ] PostGIS query verified.
- [ ] Input validation added.

## File List
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/controller/PermitController.java`
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/repository/PermitRepository.java`
- `api/src/test/java/ch/studior2/buildingpermitmonitor/api/controller/PermitControllerIT.java`

## Change Log
- [Initial] Story created (Date: $(date +%Y-%m-%d))

## Status
ready-for-dev
