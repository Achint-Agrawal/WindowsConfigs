**Load this reference when:** writing or changing tests, adding mocks (Moq or Rust trait mocks), or tempted to add test-only methods to production classes.

## Overview

Tests must verify real behavior, not mock behavior. Mocks are a means to isolate, not the thing being tested.

**Core principle:** Test what the code does, not what the mocks do.

**Following strict TDD prevents these anti-patterns.**

## The Iron Laws

```
1. NEVER test mock behavior
2. NEVER add test-only methods to production classes
3. NEVER mock without understanding dependencies
```

---

## Anti-Pattern 1: Testing Mock Behavior

**The violation (C# / Moq):**

```csharp
// ❌ BAD: Testing that the mock was configured, not that the component works
[TestMethod]
public void GetServer_ReturnsServer()
{
    var mockContext = new Mock<IFiniteStateMachineContext>();
    var mockEntity = new Mock<OrcasServer>();
    mockContext.Setup(c => c.GetEntity<OrcasServer>(It.IsAny<Guid>()))
        .Returns(mockEntity.Object);

    var result = mockContext.Object.GetEntity<OrcasServer>(serverId);

    // This just proves Moq works, not your code
    Assert.IsNotNull(result);
}
```

**The violation (Rust):**

```rust
// ❌ BAD: Testing that the mock returns what you told it to return
#[test]
fn container_service_returns_status() {
    let mock = MockContainerService::new("running");
    let status = mock.status("pg").await.unwrap();
    assert_eq!(status, "running"); // You're testing your own mock setup!
}
```

**Why this is wrong:**

- You're verifying the mock works, not that your production code works
- Test passes when mock is present, tells you nothing about real behavior
- Zero regression protection

**The fix:**

```csharp
// ✅ GOOD: Test your actual code, use mocks only for dependencies
[TestMethod]
public void GetServerAction_WithValidId_SetsTargetStateToCompleted()
{
    var mockContext = new Mock<IFiniteStateMachineContext>();
    mockContext.Setup(c => c.GetEntity<OrcasServer>(serverId))
        .Returns(CreateTestServer(serverId));

    var operation = CreateOperation(mockContext.Object);
    var actionOutcome = new ActionOutcome();

    operation.GetServerAction(ref actionOutcome);

    // Testing real operation behavior, not mock behavior
    Assert.AreEqual((int)States.Completed, actionOutcome.TargetState);
}
```

```rust
// ✅ GOOD: Test the code that USES the mock dependency
#[tokio::test]
async fn health_check_reports_unhealthy_when_container_stopped() {
    let mock_container = MockContainerService::new("exited");
    let health = HealthChecker::new(mock_container);

    let result = health.check().await.unwrap();

    assert_eq!(result.status, HealthStatus::Unhealthy);
}
```

### Gate Function

```
BEFORE asserting on any mock return value:
  Ask: "Am I testing my production code or just the mock setup?"

  IF testing mock setup:
    STOP - Delete the assertion
    Test the production code that USES the mocked dependency

  Test real behavior instead
```

---

## Anti-Pattern 2: Test-Only Methods in Production

**The violation (C# / FSM):**

```csharp
// ❌ BAD: ResetForTesting() only used in tests
public class FlexClusterCreateOperation : BaseOperation
{
    /// <summary>
    /// Resets internal state for testing.
    /// </summary>
    public void ResetForTesting()
    {
        this.RetryCount = SqlInt32.Null;
        this.ErrorMessage = SqlString.Null;
    }
}
```

**The violation (Rust):**

```rust
// ❌ BAD: pub method only used in tests
impl SidecarConfig {
    /// Creates a config with test defaults.
    pub fn test_default() -> Self {
        Self {
            protocol: "http".to_string(),
            host: "127.0.0.1".to_string(),
            port: 0,
            app_version: "test".to_string(),
        }
    }
}
```

**Why this is wrong:**

- Production class polluted with test-only code
- Dangerous if accidentally called in production (especially FSM state resets)
- Violates separation of concerns
- Confuses object lifecycle with test lifecycle

**The fix (C#):**

```csharp
// ✅ GOOD: Test helper method lives in the test project
// In TestHelpers/OperationTestFactory.cs
internal static FlexClusterCreateOperation CreateFreshOperation(
    Mock<IFiniteStateMachineContext> mockContext)
{
    return FlexClusterCreateOperation.CreateInstance(
        mockContext.Object, Guid.NewGuid(), /* clean params */);
}
```

**The fix (Rust):**

```rust
// ✅ GOOD: Test helper lives in #[cfg(test)] module
#[cfg(test)]
pub mod test_helpers {
    use super::*;

    pub fn test_sidecar_config() -> SidecarConfig {
        SidecarConfig {
            protocol: "http".to_string(),
            host: "127.0.0.1".to_string(),
            port: 0,
            app_version: "test".to_string(),
        }
    }
}
```

### Gate Function

```
BEFORE adding any method to a production class:
  Ask: "Is this only called from tests?"

  IF yes:
    STOP - Don't add it
    Put it in test helpers / #[cfg(test)] module instead

  Ask: "Does this class own this resource's lifecycle?"

  IF no:
    STOP - Wrong class for this method
```

---

## Anti-Pattern 3: Mocking Without Understanding

**The violation (C# / EntityContext):**

```csharp
// ❌ BAD: Mock prevents the state change that downstream code depends on
[TestMethod]
public void UpdateServer_SetsNewState()
{
    var mockEntityContext = new Mock<EntityContext>();
    // Mock prevents actual entity state tracking!
    mockEntityContext.Setup(e => e.GetEntityUpdate<OrcasServer>(It.IsAny<Guid>()))
        .Returns(new Mock<OrcasServer>().Object);

    operation.UpdateServerAction(ref actionOutcome);

    // Passes but never actually tested state transition
    Assert.AreEqual((int)States.Completed, actionOutcome.TargetState);
}
```

**The violation (Rust):**

```rust
// ❌ BAD: Over-mocking breaks the behavior chain
#[tokio::test]
async fn restart_container_succeeds() {
    let mock = MockContainerService {
        status_response: "running".to_string(),
        // Mocked away the actual restart logic that has side effects
        // the test depends on
    };

    let result = orchestrator.restart("pg", &mock).await;
    assert!(result.is_ok());
    // Passes but never tested that status changes from stopped → running
}
```

**Why this is wrong:**

- Mocked method had side effects the test depends on
- Over-mocking to "be safe" breaks actual behavior
- Test passes for wrong reason or fails mysteriously

**The fix:**

```csharp
// ✅ GOOD: Use a real entity object, mock only the context plumbing
[TestMethod]
public void UpdateServer_TransitionsEntityToSucceeded()
{
    var server = CreateTestServer(serverId, OrcasServer.EntityState.Updating);
    var mockEntityContext = new Mock<EntityContext>();
    mockEntityContext.Setup(e => e.GetEntityUpdate<OrcasServer>(serverId))
        .Returns(server);  // Real entity, real state tracking

    operation.UpdateServerAction(ref actionOutcome);

    Assert.AreEqual(OrcasServer.EntityState.Succeeded, server.State);
}
```

### Gate Function

```
BEFORE mocking any method:
  STOP - Don't mock yet

  1. Ask: "What side effects does the real method have?"
  2. Ask: "Does this test depend on any of those side effects?"
  3. Ask: "Do I fully understand what this test needs?"

  IF depends on side effects:
    Mock at a lower level (the actual slow/external operation)
    OR use real objects where possible (real entities, real configs)
    NOT the high-level method the test depends on

  IF unsure:
    Run test with real implementation FIRST
    Observe what actually needs to happen
    THEN add minimal mocking

  Red flags:
    - "I'll mock this to be safe"
    - "This might be slow, better mock it"
    - Mocking without understanding the dependency chain
    - Mock<EntityContext> that returns Mock<Entity> (double-mock smell)
```

---

## Anti-Pattern 4: Incomplete Mocks / Partial SQL Types

**The violation (C# / FSM Properties):**

```csharp
// ❌ BAD: Only set the properties you know about
var mockOperation = new TestOperation();
mockOperation.ServerId = new SqlGuid(serverId);
mockOperation.ServerName = new SqlString("test-server");
// Missing: SubscriptionId, ResourceGroup, Location...
// Downstream action reads Location.Value → NullReferenceException
```

**The violation (Rust):**

```rust
// ❌ BAD: Partial config mock
let config = AppConfig {
    port: 8080,
    host: "localhost".to_string(),
    // Missing: tls_cert_path, auth_token...
    // Code later unwraps tls_cert_path → panic
    ..Default::default()  // Only safe if Default is complete
};
```

**Why this is wrong:**

- Partial mocks hide structural assumptions
- Downstream code may depend on fields you didn't set
- SQL types with `.Value` on null → `SqlNullValueException` in FSM actions
- Tests pass in isolation but integration fails

**The fix (C#):**

```csharp
// ✅ GOOD: Factory that creates complete objects
internal static OrcasServer CreateTestServer(
    Guid serverId,
    OrcasServer.EntityState state = OrcasServer.EntityState.Succeeded)
{
    return new OrcasServer(serverId)
    {
        ServerName = new SqlString("test-server"),
        SubscriptionId = new SqlGuid(TestConstants.SubscriptionId),
        ResourceGroupName = new SqlString("test-rg"),
        Location = new SqlString("westus2"),
        State = state,
        // ALL required properties populated
    };
}
```

**The fix (Rust):**

```rust
// ✅ GOOD: Builder or complete constructor in test helpers
#[cfg(test)]
fn complete_test_config() -> AppConfig {
    AppConfig {
        port: 8080,
        host: "localhost".to_string(),
        tls_cert_path: "/tmp/test-cert.pem".to_string(),
        auth_token: "test-token".to_string(),
        // Every field explicitly set
    }
}
```

### Gate Function

```
BEFORE creating mock objects or test data:
  Ask: "Does this object have ALL the fields that downstream code accesses?"

  For C# SQL types: Every SqlGuid, SqlString, SqlDateTime, SqlInt32 that
  downstream code calls .Value on MUST be non-null.

  For Rust: Every field that downstream code unwraps or accesses MUST be set.

  Best practice: Create factory methods that return COMPLETE objects.
  Override only the fields your specific test cares about.
```

---

## Anti-Pattern 5: Over-Mocking FSM Context

**The violation (specific to this repo):**

```csharp
// ❌ BAD: Mocking so much that you're not testing anything real
var mockContext = new Mock<IFiniteStateMachineContext>();
var mockEntityContext = new Mock<EntityContext>();
var mockEntity = new Mock<OrcasServer>();
var mockWorkflow = new Mock<IWorkflow>();
var mockLogger = new Mock<ILogger>();

mockContext.Setup(c => c.GetEntityContext(/*...*/)).Returns(mockEntityContext.Object);
mockEntityContext.Setup(e => e.GetEntityUpdate<OrcasServer>(/*...*/)).Returns(mockEntity.Object);
mockEntity.Setup(e => e.State).Returns(OrcasServer.EntityState.Succeeded);

// 20 lines of mock setup for a 3-line test assertion
// What are you even testing at this point?
```

**Why this is wrong:**

- Mock setup longer than test logic — signal that design needs simplification or you're testing at the wrong level
- Multiple layers of mocks (mock returns mock returns mock) means zero confidence
- Fragile — any refactor breaks the mock chain, not because behavior changed

**The fix:**

```csharp
// ✅ GOOD: Use real objects where possible, mock only at boundaries
[TestMethod]
public void CreateClusterAction_WithValidParams_TransitionsToWaitingForInfra()
{
    // Real entity, real state tracking
    var cluster = TestEntityFactory.CreateFlexCluster(clusterId);

    // Mock only the context boundary (infrastructure)
    var mockContext = MockContextFactory.CreateWithEntity(cluster);

    var operation = CreateOperation(mockContext, clusterId);
    var outcome = new ActionOutcome();

    operation.CreateClusterAction(ref outcome);

    Assert.AreEqual((int)States.WaitingForInfra, outcome.TargetState);
    Assert.AreEqual(FlexCluster.EntityState.Provisioning, cluster.State);
}
```

---

## Anti-Pattern 6: Testing Implementation, Not Behavior (Rust)

**The violation:**

```rust
// ❌ BAD: Testing internal implementation details
#[test]
fn restart_calls_stop_then_start() {
    let mock = MockContainerService::new("running");
    let recorder = CallRecorder::new();

    orchestrator.restart("pg", &mock, &recorder).await;

    // Testing HOW it works, not WHAT it does
    assert_eq!(recorder.calls(), vec!["stop", "start"]);
}
```

**The fix:**

```rust
// ✅ GOOD: Test the observable outcome
#[tokio::test]
async fn restart_results_in_running_container() {
    let container = TestContainer::new_stopped("pg");
    let orchestrator = Orchestrator::new(container.service());

    orchestrator.restart("pg").await.unwrap();

    assert_eq!(container.current_status(), "running");
}
```

---

## Repo-Specific Smells

| Smell | What It Looks Like | Fix |
|-------|-------------------|-----|
| **Double-mock** | `Mock<EntityContext>` returns `Mock<Entity>` | Use real entity objects |
| **SqlNull surprise** | Test doesn't set `SqlString` property, action calls `.Value` | Factory methods with ALL properties |
| **Context mock chain** | `mockContext → mockEntityContext → mockEntity` (3+ layers) | Mock at the boundary, use real objects inside |
| **`#[allow(unused)]` in production** | Rust method only called from tests | Move to `#[cfg(test)]` module |
| **Moq `.Verify()` without behavior test** | Only assertion is `mock.Verify(x => x.Method(), Times.Once)` | Also assert on the observable outcome |
| **`[TestInitialize]` doing production work** | Setup creates real DB connections, real file I/O | Mock the I/O boundary, keep setup fast |

---

## TDD Prevents These Anti-Patterns

**Why TDD helps:**

1. **Write test first** → Forces you to think about what you're actually testing
2. **Watch it fail** → Confirms test tests real behavior, not mocks
3. **Minimal implementation** → No test-only methods creep in
4. **Real dependencies** → You see what the test actually needs before mocking

**If you're testing mock behavior, you violated TDD** — you added mocks without watching the test fail against real code first.

---

## Quick Reference

| Anti-Pattern | Fix |
|-------------|-----|
| Assert on mock return values | Test code that USES the mock dependency |
| Test-only methods in production | Move to test helpers / `#[cfg(test)]` |
| Mock without understanding | Understand dependencies first, mock minimally |
| Incomplete mocks / partial SQL types | Factory methods with ALL properties |
| Over-mocking FSM context | Real entities + mock only at boundaries |
| Testing implementation not behavior | Assert on observable outcomes |

## Red Flags

- Assertion only checks a value you put into the mock yourself
- Methods in production classes only called from test files
- `#[allow(unused)]` on production functions (Rust)
- Mock setup is >50% of the test method
- Test fails when you remove a mock (means real code should be tested)
- `Mock<X>` returning `Mock<Y>` (double-mock)
- Can't explain why a specific mock is needed
- Mocking "just to be safe"
- `.Verify()` as the only assertion (Moq)
- `SqlType.Null` properties accessed with `.Value` downstream

## The Bottom Line

**Mocks are tools to isolate, not things to test.**

If TDD reveals you're testing mock behavior, you've gone wrong.

Fix: Test real behavior or question why you're mocking at all.
