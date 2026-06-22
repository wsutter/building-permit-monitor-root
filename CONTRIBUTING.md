# Contributing to Building Permit Monitor

Thank you for contributing! This project uses Git Flow for branch management and GitHub Actions for CI/CD automation.

## Git Flow Workflow

### Branch Types

| Branch Type      | Purpose                                                                                     | Example Name               |
|------------------|---------------------------------------------------------------------------------------------|----------------------------|
| `main`           | Production-ready code. Always reflects the latest stable release.                          | `main`                     |
| `develop`        | Integration branch for features, releases, and hotfixes. Always deployable to staging.     | `develop`                  |
| `feature/*`      | New functionality or improvements. Branched from `develop`, merged back via PR.            | `feature/3-2-bounding-box-filter` |
| `release/*`      | Preparation for a new production release. Branched from `develop`, merged to `main`.        | `release/v1.0.0`           |
| `hotfix/*`       | Critical production fixes. Branched from `main`, merged to `main` and `develop`.            | `hotfix/v1.0.1`            |

### Creating a Feature Branch

1. Start a new feature:
   ```bash
git flow feature start 3-2-bounding-box-filter
```
2. Implement your changes and commit:
   ```bash
git add .
git commit -m "Add bounding-box filter to API"
```
3. Push the branch:
   ```bash
git push origin feature/3-2-bounding-box-filter
```
4. Create a PR to `develop` and request a review.

### Creating a Release

1. Start a release:
   ```bash
git flow release start v1.0.0
```
2. Bump versions in `pom.xml` and update the changelog.
3. Push the branch:
   ```bash
git push origin release/v1.0.0
```
4. CI/CD deploys to staging. Test thoroughly.
5. Finish the release:
   ```bash
git flow release finish v1.0.0
git push origin main develop --tags
```

### Creating a Hotfix

1. Start a hotfix:
   ```bash
git flow hotfix start v1.0.1
```
2. Implement the fix and commit.
3. Push the branch:
   ```bash
git push origin hotfix/v1.0.1
```
4. CI/CD deploys to production.
5. Finish the hotfix:
   ```bash
git flow hotfix finish v1.0.1
git push origin main develop --tags
```

## CI/CD

GitHub Actions workflows run on every push/PR:
- **Feature branches**: Build, test, lint, and code coverage.
- **Release branches**: Build, test, lint, and deploy to staging.
- **Hotfix branches**: Build, test, lint, and deploy to production.
- **Main/Develop branches**: Build, test, lint, and deploy (production/staging).

### Required Status Checks
- Build (`mvn clean verify`).
- Lint (`mvn spotless:check`).
- Tests (100% pass).
- Code coverage (80% minimum via JaCoCo).

## Code Style

- Follow the [coding standards](docs/bmad/coding-standards.md).
- Use `mvn spotless:apply` to format code before committing.

## Branch Protection

- **`main`**: Require PR review, status checks, signed commits, linear history.
- **`develop`**: Require PR review, status checks, signed commits.

## Questions?

Open an issue or contact the maintainers.