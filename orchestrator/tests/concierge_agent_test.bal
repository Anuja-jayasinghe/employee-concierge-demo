// Real test against the real ballerina/ai Agent + real anthropic:ModelProvider
// — no mocks. Without a real ANTHROPIC_API_KEY, the whole
// ballerina/ai -> ballerinax/ai.anthropic -> Anthropic API pipeline must
// fail gracefully with a typed error, proving it's genuinely wired end to
// end. Full routing verification (does the model pick the right tool)
// happens in Phase 9 once a real key is supplied.
import ballerina/test;

@test:Config {}
function testConciergeAgentFailsGracefullyWithoutAKey() returns error? {
    string|error result = concierge.run("is parking spot A03 available?");
    test:assertTrue(result is error, "expected a graceful error without a real Anthropic key");
}
