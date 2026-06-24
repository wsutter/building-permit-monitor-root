# Git Flow with CI/CD Automation Specification — Building Permit Monitor

> BMAD planning artifact · Author: opencode · Date: 2026-06-22 · Status: draft

## 1. Branch Strategy

### Branch Types & Purposes
| Branch Type      | Purpose                                                                                     | Example Name               |
|------------------|---------------------------------------------------------------------------------------------|----------------------------|
| `main`           | Production-ready code. Always reflects the latest stable release.                          | `main`                     |
| `develop`        | Integration branch for features, releases, and hotfixes. Always deployable to staging.     | `develop`                  |
| `feature/*`      | New functionality or improvements. Branched from `develop`, merged back via PR.            | `feature/3-2-bounding-box-filter` |
| `release/*`      | Preparation for a new production release. Branched from `develop`, merged to `main` and `develop`. | `release/v1.0.0`           |
| `hotfix/*`       | Critical production fixes. Branched from `main`, merged to `main` and `develop`.            | `hotfix/v1.0.1`            |

### Naming Conventions
- **Feature branches**: `feature/<issue-id>-<kebab-case-description>` (e.g., `feature/42-add-geocoding-cache`).
- **Release branches**: `release/v<semver>` (e.g., `release/v1.0.0`).
- **Hotfix branches**: `hotfix/v<semver>` (e.g., `hotfix/v1.0.1`).

### Merge Strategies
| Branch Type      | Merge Strategy       | Reason                                                                                     |
|------------------|----------------------|-------------------------------------------------------------------------------------------|
| `feature/*`      | Squash merge         | Clean history, atomic changes.                                                            |
| `release/*`      | Merge commit         | Preserve release context and changelog.                                                  |
| `hotfix/*`       | Merge commit         | Preserve hotfix context and changelog.                                                   |
| `develop` → `main`| Merge commit         | Preserve release context and changelog.                                                  |

## 2. CI/CD Automation (GitHub Actions)

### Workflow Overview
| Workflow File               | Trigger Events                     | Jobs                                                                                     |
|---------------------------|------------------------------------|------------------------------------------------------------------------------------------|
| `feature-ci.yml`           | `push`, `pull_request` (feature/*) | Build, test, lint, code coverage.                                                        |
| `release-ci.yml`           | `push` (release/*)                | Build, test, lint, deploy to staging.                                                    |
| `hotfix-ci.yml`            | `push` (hotfix/*)                 | Build, test, lint, deploy to production.                                                 |
| `main-ci.yml`              | `push` (main)                     | Build, test, lint, deploy to production, tag release.                                    |
| `develop-ci.yml`           | `push` (develop)                  | Build, test, lint, deploy to staging.                                                    |

### Workflow Definitions

#### `feature-ci.yml`
```yaml
name: Feature Branch CI

on:
  push:
    branches: [ "feature/**" ]
  pull_request:
    branches: [ "develop" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl contracts install
      - run: mvn -pl ${{ matrix.module }} clean verify
        env:
          MODULE: ${{ matrix.module }}
    strategy:
      matrix:
        module: [ingestor, normalizer, enricher, persistence, api]

  lint:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl ${{ matrix.module }} spotless:check
        env:
          MODULE: ${{ matrix.module }}
    strategy:
      matrix:
        module: [ingestor, normalizer, enricher, persistence, api]

  test-coverage:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl ${{ matrix.module }} jacoco:report
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.module }}-coverage-report
          path: ${{ matrix.module }}/target/site/jacoco
    strategy:
      matrix:
        module: [ingestor, normalizer, enricher, persistence, api]
```

#### `release-ci.yml`
```yaml
name: Release Branch CI/CD

on:
  push:
    branches: [ "release/**" ]

jobs:
  build-test-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl contracts install
      - run: mvn clean verify
      - run: mvn spotless:check

  deploy-staging:
    needs: build-test-lint
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl platform deploy -DskipTests
        env:
          DOCKER_REGISTRY: ${{ secrets.DOCKER_REGISTRY }}
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

#### `hotfix-ci.yml`
```yaml
name: Hotfix Branch CI/CD

on:
  push:
    branches: [ "hotfix/**" ]

jobs:
  build-test-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl contracts install
      - run: mvn clean verify
      - run: mvn spotless:check

  deploy-production:
    needs: build-test-lint
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl platform deploy -DskipTests
        env:
          DOCKER_REGISTRY: ${{ secrets.DOCKER_REGISTRY }}
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

#### `main-ci.yml`
```yaml
name: Main Branch CI/CD

on:
  push:
    branches: [ "main" ]

jobs:
  build-test-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl contracts install
      - run: mvn clean verify
      - run: mvn spotless:check

  deploy-production:
    needs: build-test-lint
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl platform deploy -DskipTests
        env:
          DOCKER_REGISTRY: ${{ secrets.DOCKER_REGISTRY }}
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}

  tag-release:
    needs: deploy-production
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          git tag -a v${{ github.run_number }} -m "Release v${{ github.run_number }}"
          git push origin v${{ github.run_number }}
```

#### `develop-ci.yml`
```yaml
name: Develop Branch CI/CD

on:
  push:
    branches: [ "develop" ]

jobs:
  build-test-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl contracts install
      - run: mvn clean verify
      - run: mvn spotless:check

  deploy-staging:
    needs: build-test-lint
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '25'
          distribution: 'temurin'
      - run: mvn -pl platform deploy -DskipTests
        env:
          DOCKER_REGISTRY: ${{ secrets.DOCKER_REGISTRY }}
          DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Required Status Checks
- **Build**: `mvn clean verify` must pass.
- **Lint**: `mvn spotless:check` must pass.
- **Tests**: All unit and integration tests must pass.
- **Code Coverage**: Minimum 80% line coverage (enforced via JaCoCo).

## 3. Branch Protection Rules

### `main` Branch
- Require PR review (1 approval).
- Require status checks to pass (`build`, `lint`, `test-coverage`).
- Require signed commits.
- Restrict push access to repository admins.
- Require linear history (no merge commits).

### `develop` Branch
- Require PR review (1 approval).
- Require status checks to pass (`build`, `lint`, `test-coverage`).
- Require signed commits.
- Restrict push access to repository admins.
- Allow merge commits (for release/hotfix merges).

## 4. Release Process

### Steps to Create a Release
1. **Create release branch**: `git checkout -b release/v1.0.0 develop`.
2. **Bump version**: Update `pom.xml` versions to `1.0.0` (remove `-SNAPSHOT`).
3. **Update changelog**: Generate changelog using `git log --oneline --no-merges develop..release/v1.0.0`.
4. **Commit changes**: `git commit -am "Prepare release v1.0.0"`.
5. **Push branch**: `git push origin release/v1.0.0`.
6. **CI/CD pipeline**: Automatically deploys to staging.
7. **Testing**: Manually verify staging environment.
8. **Merge to `main`**: Create PR from `release/v1.0.0` to `main`.
9. **Tag release**: `git tag -a v1.0.0 -m "Release v1.0.0"`.
10. **Merge back to `develop`**: Create PR from `main` to `develop` to sync changes.

### Versioning Strategy
- **Semantic Versioning (SemVer)**: `MAJOR.MINOR.PATCH`.
- **Pre-release**: Use `-SNAPSHOT` for `develop` and feature branches.

### Changelog Generation
- Use `git-chglog` or similar tool to generate changelog from commit messages.
- Include:
  - New features.
  - Bug fixes.
  - Breaking changes.
  - Dependency updates.

## 5. Hotfix Process

### Steps to Create a Hotfix
1. **Create hotfix branch**: `git checkout -b hotfix/v1.0.1 main`.
2. **Bump version**: Update `pom.xml` versions to `1.0.1`.
3. **Implement fix**: Commit changes to address the issue.
4. **Commit changes**: `git commit -am "Hotfix for critical issue"`.
5. **Push branch**: `git push origin hotfix/v1.0.1`.
6. **CI/CD pipeline**: Automatically deploys to production.
7. **Merge to `main`**: Create PR from `hotfix/v1.0.1` to `main`.
8. **Tag release**: `git tag -a v1.0.1 -m "Hotfix v1.0.1"`.
9. **Merge back to `develop`**: Create PR from `main` to `develop` to sync changes.

## 6. Implementation Plan

### Step 1: Set Up Git Flow Locally
1. Initialize Git Flow: `git flow init -d`.
2. Verify branches: `git branch`.
3. Push branches: `git push origin main develop`.

### Step 2: Configure GitHub Actions
1. Create `.github/workflows/` directory.
2. Add workflow files (`feature-ci.yml`, `release-ci.yml`, `hotfix-ci.yml`, `main-ci.yml`, `develop-ci.yml`).
3. Push to `develop`: `git add .github/workflows && git commit -m "Add GitHub Actions workflows" && git push origin develop`.

### Step 3: Enforce Branch Protection
1. Go to **Repository Settings > Branches > Branch protection rules**.
2. Add rules for `main` and `develop` as specified above.

### Step 4: Update Documentation
1. Update `README.md` with Git Flow and CI/CD instructions.
2. Add `CONTRIBUTING.md` with contribution guidelines.

### Step 5: Verify Setup
1. Create a test feature branch: `git flow feature start test-ci`.
2. Make a small change, commit, and push.
3. Verify CI pipeline runs and passes.
4. Create PR to `develop` and verify branch protection rules.

---