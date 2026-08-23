// The real ballerina/ai Agent (routing decision layer) on a real
// Anthropic model, wired with the five real tool functions from
// agent_tools.bal. Code-complete now, but actually invoking it means
// invoking the real model, so full routing verification (does it pick
// the right tool for a given request) happens in Phase 9 once a real
// ANTHROPIC_API_KEY is supplied — see agent_tools_test.bal for what's
// verified without one.
import ballerina/ai;
import ballerina/os;
import ballerinax/ai.anthropic;

// Falls back to this configurable when ANTHROPIC_API_KEY isn't in the
// process's environment -- e.g. launched via WSO2 Integrator: BI's
// Run/Debug, which spawns `bal run` directly without sourcing this
// repo's .env the way scripts/start-agents.sh and start-all.sh do. Set
// via orchestrator/Config.toml (gitignored, dev-time only), Ballerina's
// own standard mechanism for exactly this.
configurable string anthropicApiKey = "";

final string resolvedAnthropicApiKey = os:getEnv("ANTHROPIC_API_KEY") != ""
    ? os:getEnv("ANTHROPIC_API_KEY")
    : anthropicApiKey;

final ai:ModelProvider anthropicModel = check new anthropic:ModelProvider(
    resolvedAnthropicApiKey,
    anthropic:CLAUDE_SONNET_4_5
);

final ai:Agent concierge = check new (
    systemPrompt = {
        role: "WSO2 Employee Concierge",
        instructions: string `You help WSO2 employees by routing their requests to the right
            internal agent and relaying its real answer back, in your own words if useful.
            You have five tools, each a real remote WSO2 agent:

            - askParkingAgent: parking availability, reservations, and cancellations at
              WSO2 Colombo HQ
            - askDigiOpsAgent: IT Helpdesk — tickets, incidents, VPN/password/hardware questions
            - askPeopleOperationsAgent: HR — leave policy, benefits, new-hire onboarding
            - askPayrollAgent: payroll questions, payslip corrections
            - askTravelExpenseAgent: travel policy, expense claims

            Pick exactly the one tool that matches the employee's request. If the request
            doesn't clearly belong to any of these five domains, say so rather than guessing.`
    },
    model = anthropicModel,
    tools = [askParkingAgent, askDigiOpsAgent, askPeopleOperationsAgent, askPayrollAgent, askTravelExpenseAgent]
);
