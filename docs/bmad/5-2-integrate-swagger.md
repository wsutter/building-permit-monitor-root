---
story_key: 5-2-integrate-swagger
epic: 5
story_num: 2
status: ready-for-dev
baseline_commit: $(git rev-parse HEAD)
feature_branch: feature/5-2-integrate-swagger
---

# Story 5-2: Integrate Swagger (OpenAPI)

## Story
**As a developer**, I want to integrate Swagger (OpenAPI) into the project so that I can generate API documentation and an `openapi.json` for all REST endpoints.

## Acceptance Criteria (BDD)
- **Given** the Swagger dependencies,
  **When** the project is built,
  **Then** an `openapi.json` is generated.
- **Given** a running application,
  **When** Swagger UI is accessed,
  **Then** all REST endpoints are documented.
- **Given** the Maven plugin,
  **When** the build runs,
  **Then** API documentation is generated automatically.

## Tasks
- [ ] Add SpringDoc OpenAPI dependencies to the `api` module.
- [ ] Configure Swagger UI and OpenAPI generation.
- [ ] Add Maven plugin to generate `openapi.json`.
- [ ] Document all REST endpoints with Swagger annotations.
- [ ] Verify Swagger UI at `/swagger-ui.html`.

## Dev Notes
### Architecture Context
- **Tool**: SpringDoc OpenAPI (v2.5.0+).
- **Module**: `api` (Spring Boot).
- **Output**: `openapi.json` and Swagger UI.

### Technical Requirements
- Add `springdoc-openapi-starter-webmvc-ui` to `api/pom.xml`.
- Configure OpenAPI metadata (title, version, description).
- Add Maven plugin to generate `openapi.json` during build.
- Annotate all REST endpoints with `@Tag`, `@Operation`, etc.

### Files to Modify
- `api/pom.xml`
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/config/OpenApiConfig.java`
- All REST controllers in `api/src/main/java/ch/studior2/buildingpermitmonitor/api/controller/`

### Testing
- **Swagger UI**: Verify endpoints at `/swagger-ui.html`.
- **OpenAPI JSON**: Confirm `openapi.json` is generated.

## Dev Agent Record
### Implementation Plan
1. Add SpringDoc dependencies to `api/pom.xml`.
2. Configure OpenAPI metadata.
3. Add Maven plugin for `openapi.json` generation.
4. Annotate REST endpoints.
5. Verify Swagger UI and `openapi.json`.

### Completion Notes
- [ ] Swagger UI accessible.
- [ ] `openapi.json` generated.
- [ ] All endpoints documented.

## File List
- `api/pom.xml`
- `api/src/main/java/ch/studior2/buildingpermitmonitor/api/config/OpenApiConfig.java`
- All REST controllers

## Change Log
- [Initial] Story created (Date: $(date +%Y-%m-%d))

## Status
ready-for-dev
