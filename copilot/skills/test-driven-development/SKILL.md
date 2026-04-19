---
name: test-driven-development
description: "Use when implementing any feature or bugfix in orcasql-breadth. Enforces Red-Green-Refactor TDD discipline for both C# (MSTest/Moq) and Rust (cargo-nextest) code. Covers FSM operations, EntityFx entities, ARM APIs, VmAgentRust services, and all other code changes."
---

# Skill: Test-Driven Development (TDD)

**Applies to:** `orcasql-breadth` repository only (including worktrees like `orcasql-breadth-readonly`). Do not apply this skill to other repositories (Marlin, pgmongo, achintStuff, etc.).

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

---

## When to Use

**Always:**

- New features (ARM APIs, FSM operations, EntityFx entities, Rust services)
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask the user first):**

- Throwaway prototypes
- Generated code (T4 templates, code-gen output)
- Configuration files, SQL schema DDL
- XML doc comments or markdown docs

Thinking "skip TDD just this once"? Stop. That's rationalization.

---

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**

- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

---

## Red-Green-Refactor

### RED — Write Failing Test

Write one minimal test showing what should happen.

**Requirements:**

- One behavior per test
- Clear name describing the behavior
- Real code paths (mocks only for external dependencies)

### Verify RED — Watch It Fail

**MANDATORY. Never skip.**

Run the test. Confirm:

- Test **fails** (not errors/crashes)
- Failure message is the expected one
- Fails because the feature is missing (not typos or build errors)

**Test passes immediately?** You're testing existing behavior. Fix or delete the test.

**Test errors?** Fix the error, re-run until it fails correctly.

### GREEN — Minimal Code

Write the simplest code to pass the test. Don't add features, refactor other code, or "improve" beyond the test.

### Verify GREEN — Watch It Pass

**MANDATORY.**

Run the test. Confirm:

- The new test passes
- All other tests still pass
- Output is clean (no errors, no warnings)

**Test fails?** Fix the production code, not the test.

**Other tests fail?** Fix them now.

### REFACTOR — Clean Up

After green only:

- Remove duplication
- Improve names
- Extract helpers

Keep tests green throughout. Don't add behavior during refactor.

### Repeat

Next failing test for next behavior.

---

## C# Testing Conventions (MSTest + Moq)

### Test Project Locations

Tests in this repo follow these patterns:

| Pattern | Example |
|---------|---------|
| `src/*/Test/` | `src/VmAgentTests/` |
| `src/*/UnitTest/` | `src/Director/UnitTest/` |
| `src/*/MockTests/` | `src/OrcasBreadthRP/Test/MockTests/` |
| `MeruCommon/src/*/Test/` | `MeruCommon/src/VmAgent/VmAgent.Test/` |

### Test Class Structure

```csharp
// -----------------------------------------------------------------------
// <copyright file="MyComponentTests.cs" company="Microsoft">
//     Copyright (c) Microsoft Corporation. All rights reserved.
// </copyright>
// <author>your-alias</author>
// <purpose>
//   Tests for MyComponent behavior.
// </purpose>
// -----------------------------------------------------------------------
namespace Microsoft.SqlServer.OrcasBreadth.Tests
{
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Moq;

    /// <summary>
    /// Tests for <see cref="MyComponent"/>.
    /// </summary>
    [TestClass]
    public class MyComponentTests
    {
        /// <summary>
        /// Timeout for all tests in this class.
        /// </summary>
        private const int TestTimeOut = 30000;

        /// <summary>
        /// Mock logger for the component under test.
        /// </summary>
        private Mock<ILogger<MyComponent>> mockLogger;

        /// <summary>
        /// Initializes mocks before each test.
        /// </summary>
        [TestInitialize]
        public void Setup()
        {
            this.mockLogger = new Mock<ILogger<MyComponent>>();
        }

        /// <summary>
        /// Verifies that DoWork returns success when input is valid.
        /// </summary>
        [TestMethod]
        [Owner("your-alias")]
        [Timeout(TestTimeOut)]
        public void DoWork_WithValidInput_ReturnsSuccess()
        {
            // Arrange
            var component = new MyComponent(this.mockLogger.Object);

            // Act
            var result = component.DoWork("valid-input");

            // Assert
            Assert.IsTrue(result.IsSuccess);
        }
    }
}
```

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Test class | `{ComponentName}Tests` or `{ComponentName}MockTest` | `VirtualMachineControllerTests` |
| Test method | Descriptive behavior name | `DoWork_WithValidInput_ReturnsSuccess` |
| Mock fields | `mock{Dependency}` with `camelCase` | `mockSystemCommandService` |

### Mocking with Moq

```csharp
// Setup
this.mockService
    .Setup(s => s.GetData(It.IsAny<string>()))
    .Returns(expectedData);

// Verify
this.mockService.Verify(s => s.GetData("expected-key"), Times.Once);
```

**Mock only what you must** — external services, I/O, infrastructure. Test real code paths whenever possible.

### FSM / EntityFx Testing

When testing FSM operations or EntityFx entities:

- Mock `IFiniteStateMachineContext` and `EntityContext` as needed
- Test action methods by verifying `ActionOutcome.TargetState`
- Test state transitions explicitly
- Test entity state changes through operations
- Use `GetSecondaryReadOnlyEntityContext()` patterns in mocks

### Building

**Ask the user to build** from an elevated Developer PowerShell for VS 2022. Do NOT run builds yourself.

```powershell
cd C:\Repos\orcasql-breadth-readonly  # or orcasql-breadth
msbuild dirs.proj /p:Configuration=Debug /p:Platform=x64 /m /p:SkipTestsOnBuild=true /verbosity:minimal 2>&1 | Tee-Object -FilePath $env:TEMP\build-output.txt
```

After the user says done, read `$env:TEMP\build-output.txt` to check for errors.

### Running C# Tests

**Ask the user to run tests** from an elevated Developer PowerShell for VS 2022. FSM unit tests require admin elevation for certificate installation.

```powershell
$dll = "out\Debug\x64\Microsoft.SqlServer.Management.OrcasBreadth.FSM.UnitTest.csproj\Microsoft.SqlServer.OrcasBreadth.Management.FSM.UnitTests.dll"
vstest.console.exe $dll /Tests:"TestTransitionMarkDatabaseReadOnly" 2>&1 | Tee-Object -FilePath $env:TEMP\test-output.txt
```

After the user says done, read `$env:TEMP\test-output.txt` to analyze results.

> **Note:** Use `Tee-Object` (not `Out-File`) so the user sees output in the terminal AND it's saved to the file for the agent to read.

---

## Rust Testing Conventions (cargo-nextest)

### Test Locations

| Type | Location | Example |
|------|----------|---------|
| Unit tests | Inline `#[cfg(test)]` modules in source files | `src/config.rs` |
| Integration tests | `tests/` directory | `tests/integration_api_test.rs` |
| Shared test utilities | `tests/common/` | `tests/common/test_utils.rs` |

### Unit Test Pattern (Inline)

```rust
#[cfg(test)]
#[allow(clippy::unwrap_used, clippy::expect_used)]
mod tests {
    use super::*;

    #[test]
    fn parse_config_with_valid_input_returns_expected_values() {
        let config = SidecarConfig {
            protocol: "http".to_string(),
            host: "127.0.0.1".to_string(),
            port: 5001,
            app_version: "1.0.0".to_string(),
        };

        let result = SidecarConfig::from_config_with_env_override(&config);
        assert_eq!(result.protocol, "http");
        assert_eq!(result.port, 5001);
    }

    #[test]
    #[serial_test::serial] // Use when test modifies env vars or shared state
    fn config_respects_env_override() {
        std::env::set_var("SIDECAR_PORT", "9999");
        let config = SidecarConfig::from_config_with_env_override(&default_config());
        assert_eq!(config.port, 9999);
        std::env::remove_var("SIDECAR_PORT");
    }
}
```

### Async Test Pattern

```rust
#[tokio::test]
async fn api_returns_health_check_ok() {
    let app = create_test_app().await;
    let resp = app.get("/health").await;
    assert_eq!(resp.status(), 200);
}
```

### Mock Service Pattern

```rust
#[cfg(test)]
pub mod mocks {
    use async_trait::async_trait;

    pub struct MockContainerService {
        pub status_response: String,
    }

    impl MockContainerService {
        pub fn new(status_response: &str) -> Self {
            Self { status_response: status_response.to_string() }
        }

        pub fn default_exited() -> Self {
            Self::new("exited")
        }
    }

    #[async_trait]
    impl ContainerService for MockContainerService {
        async fn status(&self, _name: &str) -> anyhow::Result<String> {
            Ok(self.status_response.clone())
        }
    }
}
```

**Prefer trait-based mocking** — define traits for services, implement mock structs in `#[cfg(test)]` modules.

### Running Rust Tests

All Rust commands run from `MeruCommon/src/VmAgentRust/`:

```bash
# Run all tests
make check

# Filter by test name pattern
make check TESTS="cert"

# Run all tests in a specific binary
make check TESTS="binary(integration_api_test)"

# Boolean filter expressions
make check TESTS="test(cert) or test(parity)"
make check TESTS="test(cert) and not test(slow)"

# Verbose output
make check-verbose

# Build only (no tests)
make build

# Lint + format check
make sanitize
```

**Important:** This repo requires `cargo-nextest` — do not use bare `cargo test`.

### Post-Change Validation

After any Rust change, always run:

```bash
make check      # Tests pass
make sanitize   # No lint warnings, formatting clean
```

---

## TDD Workflow by Change Type

### New ARM API Endpoint

1. **RED:** Write a MockTest in `src/OrcasBreadthRP/Test/MockTests/` for the controller action
2. **Verify RED:** Ask user to build and run: `vstest.console.exe <dll> /Tests:"NewEndpointMockTest"`
3. **GREEN:** Implement controller, ARM entities, internal model
4. **Verify GREEN:** All MockTests pass
5. Continue RED-GREEN for: workflow logic, MOSM handler, child FSM, entity state transitions

### New FSM Operation

1. **RED:** Write test verifying `ActionOutcome.TargetState` for the happy path
2. **Verify RED:** Test fails because the action method doesn't exist
3. **GREEN:** Implement the action with minimal logic
4. **Verify GREEN:** Test passes
5. Continue RED-GREEN for: error paths, state transitions, child FSM subscriptions

### New EntityFx Entity

1. **RED:** Write test for entity creation with required properties
2. **Verify RED:** Entity class doesn't exist yet
3. **GREEN:** Implement entity class with state enum and properties
4. Continue RED-GREEN for: state transitions, terminal states, operation coordination

### Rust Service Change

1. **RED:** Write `#[test]` or `#[tokio::test]` in inline `mod tests` or `tests/`
2. **Verify RED:** `make check TESTS="my_new_test"`
3. **GREEN:** Implement minimal code
4. **Verify GREEN:** `make check` (all tests)
5. **REFACTOR:** Clean up, then `make sanitize`

### Bug Fix (Any Language)

1. **RED:** Write a test that reproduces the bug (test must fail, proving the bug exists)
2. **Verify RED:** Confirm the failure matches the reported bug behavior
3. **GREEN:** Fix the bug with minimal change
4. **Verify GREEN:** Bug-reproducing test passes, all other tests pass
5. The test now permanently guards against regression

---

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One behavior per test. "and" in the name? Split it. | `TestValidatesEmailAndDomainAndWhitespace` |
| **Clear** | Name describes the behavior being tested | `Test1`, `TestIt`, `TestStuff` |
| **Shows intent** | Demonstrates the desired API and expected outcome | Obscures what code should do |
| **Real code** | Tests actual production code paths | Tests only mock behavior |
| **Arrange-Act-Assert** | Clear separation of setup, action, assertion | Everything jumbled together |

---

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours of work is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing-after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test is hard to write = skip it" | Hard to test = hard to use. Listen to the test — simplify the design. |
| "FSM code is too complex to test" | Mock the context, test action outcomes and state transitions. |

---

## Red Flags — STOP and Start Over

- Code written before test
- Test written after implementation
- Test passes immediately (not testing new behavior)
- Can't explain why the test failed
- Tests deferred to "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Keep as reference" or "adapt existing code"
- "This FSM action is too simple to test"

**All of these mean: Delete the production code. Start over with TDD.**

---

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method/action has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass (`vstest.console.exe` for C# / `make check` for Rust)
- [ ] Output is clean (no errors, no warnings)
- [ ] Tests use real code (mocks only for external deps / infrastructure)
- [ ] Edge cases and error paths covered
- [ ] `make sanitize` passes (Rust changes)
- [ ] Arrange-Act-Assert pattern followed (C# tests)

Can't check all boxes? You skipped TDD. Start over.

---

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test it | Write the wished-for API first. Write the assertion. Ask the user. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Use dependency injection / traits. |
| Test setup is huge | Extract test helpers into `[TestInitialize]` / `mod tests`. Still complex? Simplify the design. |
| FSM action hard to test | Mock `IFiniteStateMachineContext`, focus on `ActionOutcome.TargetState` and entity state changes. |
| EntityContext hard to test | Use the existing mock patterns in `MockTests/`. Focus on entity state transitions. |

---

## Testing Anti-Patterns

When adding mocks or test utilities, read @testing-anti-patterns.md to avoid common pitfalls:

- Testing mock behavior instead of real behavior (Moq `.Verify()` as only assertion, asserting on mock return values)
- Adding test-only methods to production classes (move to test helpers / `#[cfg(test)]`)
- Mocking without understanding dependencies (double-mocking `Mock<EntityContext>` → `Mock<Entity>`)
- Incomplete mocks with null `SqlType` properties that crash downstream `.Value` calls
- Over-mocking FSM context (3+ layers of mocks — use real entities instead)

---

## Debugging Integration

Bug found? Write a failing test reproducing it. Follow the TDD cycle. The test proves the fix and prevents regression.

**Never fix bugs without a test.**

---

## Final Rule

```
Production code → a test exists that failed first
Otherwise → not TDD
```

No exceptions without the user's explicit permission.
