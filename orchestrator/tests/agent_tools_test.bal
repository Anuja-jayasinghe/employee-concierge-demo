// Real bal test suite exercising the five tool functions directly — no
// mocks. Start all five real agent processes before running `bal test`:
// each tool holds a real ballerina/a2a Client, and module init itself
// resolves all five real Agent Cards, so the whole test package fails to
// even start if any target agent isn't reachable (see agent_tools.bal).
//
// All five agents are real LLM-backed agents and need a real Anthropic
// key to answer meaningfully: with ANTHROPIC_API_KEY unset, they're
// asserted to fail gracefully — proof the tool -> ballerina/a2a -> real
// agent wire is genuinely connected, not a bypass. With a real key
// present (Phase 9), they're asserted for real, non-empty content
// instead — see docs/DEMO_SCRIPT.md for the actual real answers these
// produced.
import ballerina/os;
import ballerina/test;

final boolean hasRealKey = os:getEnv("ANTHROPIC_API_KEY") != "";

@test:Config {}
function testAskParkingAgent() returns error? {
    string|error result = askParkingAgent("is spot A03 available?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskDigiOpsAgent() returns error? {
    string|error result = askDigiOpsAgent("how do I reset my VPN password?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskPeopleOperationsAgent() returns error? {
    string|error result = askPeopleOperationsAgent("how many annual leave days do I have?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskPayrollAgent() returns error? {
    string|error result = askPayrollAgent("when is the next pay date?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

@test:Config {}
function testAskTravelExpenseAgent() returns error? {
    string|error result = askTravelExpenseAgent("what's the per-diem rate?");
    if hasRealKey {
        test:assertTrue(result is string && result.length() > 0, "expected a real, non-empty reply with a real key");
    } else {
        test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
    }
}

// cancelTask/getTask/listTasks never touch the LLM -- pure a2a:Client
// calls -- so these run unconditionally, no key needed. One
// representative agent per transport binding (Parking: REST, DigiOps:
// JSON-RPC, Payroll: gRPC) is enough to prove the shared
// cancelAgentTask/getAgentTaskStatus/listAgentTasks helpers work over
// each real wire; the other two agents share the same helpers.

@test:Config {}
function testListParkingTasks() returns error? {
    string result = check listParkingTasks();
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}

@test:Config {}
function testGetParkingTaskStatusUnknownId() returns error? {
    string|error result = getParkingTaskStatus("does-not-exist");
    test:assertTrue(result is error, "expected a graceful error for an unknown task id");
}

@test:Config {}
function testCancelParkingTaskUnknownId() returns error? {
    string|error result = cancelParkingTask("does-not-exist");
    test:assertTrue(result is error, "expected a graceful error for an unknown task id");
}

@test:Config {}
function testListDigiOpsTasks() returns error? {
    string result = check listDigiOpsTasks();
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}

@test:Config {}
function testListPayrollTasks() returns error? {
    string result = check listPayrollTasks();
    test:assertTrue(result.length() > 0, "expected a real, non-empty summary (even if it's just \"No tasks found.\")");
}
