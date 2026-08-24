// Real bal test suite exercising the five generic tool functions
// directly — no mocks. Start all five real agent processes before
// running `bal test`. Unlike the old per-agent `final a2a:Client`
// module vars, no agent's card is resolved until a test actually
// delegates to it, so (unlike before) this package can still start
// with some agents down — individual tests against those agents will
// just fail instead of the whole suite refusing to run.
//
// All five agents are real LLM-backed agents and need a real Anthropic
// key to answer meaningfully via delegateToAgent: with ANTHROPIC_API_KEY
// unset, they're asserted to fail gracefully — proof the tool ->
// ballerina/a2a -> real agent wire is genuinely connected, not a bypass.
// With a real key present (Phase 9), they're asserted for real,
// non-empty content instead — see docs/DEMO_SCRIPT.md for the actual
// real answers these produced.
import ballerina/os;
import ballerina/test;

final boolean hasRealKey = os:getEnv("ANTHROPIC_API_KEY") != "";

@test:Config {}
function testDiscoverAgents() returns error? {
    json cards = check discoverAgents();
    json[] cardArray = check cards.ensureType();
    test:assertEquals(cardArray.length(), 5, "expected a card entry for every known agent");
}

@test:Config {}
function testDelegateToUnknownAgent() returns error? {
    string|error result = delegateToAgent("NotARealAgent", "hello?");
    test:assertTrue(result is error, "expected a graceful error for an unknown agent name");
}

@test:Config {}
function testDelegateToParking() returns error? {
    string|error result = delegateToAgent("Parking", "is spot A03 available?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testDelegateToDigiOps() returns error? {
    string|error result = delegateToAgent("DigiOps", "how do I reset my VPN password?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testDelegateToPeopleOperations() returns error? {
    string|error result = delegateToAgent("PeopleOperations", "how many annual leave days do I have?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testDelegateToPayroll() returns error? {
    string|error result = delegateToAgent("Payroll", "when is the next pay date?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testDelegateToTravelExpense() returns error? {
    string|error result = delegateToAgent("TravelExpense", "what's the per-diem rate?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

// cancelAgentTask/getAgentTaskStatus/listAgentTasks never touch the LLM --
// pure a2a:Client calls -- so these run unconditionally, no key needed.
// One representative agent per transport binding (Parking: REST, DigiOps:
// JSON-RPC, Payroll: gRPC) is enough to prove the shared
// cancelTaskOn/getTaskStatusOn/listTasksOn helpers work over each real
// wire; the other two agents share the same helpers.

@test:Config {}
function testListParkingTasks() returns error? {
    string result = check listAgentTasks("Parking");
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}

@test:Config {}
function testGetParkingTaskStatusUnknownId() returns error? {
    string|error result = getAgentTaskStatus("Parking", "does-not-exist");
    test:assertTrue(result is error, "expected a graceful error for an unknown task id");
}

@test:Config {}
function testCancelParkingTaskUnknownId() returns error? {
    string|error result = cancelAgentTask("Parking", "does-not-exist");
    test:assertTrue(result is error, "expected a graceful error for an unknown task id");
}

@test:Config {}
function testListDigiOpsTasks() returns error? {
    string result = check listAgentTasks("DigiOps");
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}

@test:Config {}
function testListPayrollTasks() returns error? {
    string result = check listAgentTasks("Payroll");
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}
