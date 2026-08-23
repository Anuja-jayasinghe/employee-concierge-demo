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
        instructions: string `You route WSO2 employee requests to the right domain and relay
            the real answer back. Five domains: Parking (spot availability, reservations),
            DigiOps (IT tickets, incidents, VPN/password/hardware), PeopleOperations (HR
            policy, onboarding), Payroll (payroll, payslip corrections), Travel & Expense
            (travel policy, expense claims). If a request doesn't clearly belong to one of
            these, say so instead of guessing.

            Each domain has one ask tool (e.g. askParkingAgent) for any request in natural
            language — availability, reservations, cancellations, status checks, listing,
            who-did-what, everything. Call it exactly once per employee turn and answer from
            what it actually returns; do not call it again for the same question, and do not
            answer from your own assumptions instead of calling it. There is also a separate
            cancel/status/list tool per domain (e.g. cancelParkingTask) for acting on a task
            id from an earlier reply in this conversation.

            Reservations, tickets, corrections, and claims are tied to a real employee name.
            If you don't already have it from this conversation, ask for it before making the
            request, then reuse it for later requests without asking again. Read-only
            questions don't need a name. These agents do track and will reveal who made a
            request when asked — never assume that's private and refuse on your own.

            No proactive notifications ("let me know when...") — only respond to what's asked.`
    },
    model = anthropicModel,
    // A real, verified, pre-existing behavior of this model+framework
    // combination, not something prompt wording or tool count control:
    // the concierge sometimes re-calls an ask tool multiple times for one
    // question even where the underlying tool result is unambiguous --
    // reproduced this down to a single tool and a one-sentence prompt on a
    // freshly started process, ruling out this project's own config as the
    // cause. ai:Agent's own default maxIter (max(tools.length(), 10) = 20
    // with the current 20 tools) let that tendency run for 100s+ on some
    // real queries. A lower cap (tried 6, then 8) fails fast instead but
    // was tight enough to reject some legitimate single-tool-call queries
    // outright -- 15 is a real, tested middle ground: enough headroom for
    // the observed redundant-call range without the old unbounded cost.
    maxIter = 15,
    tools = [
        askParkingAgent, cancelParkingTask, getParkingTaskStatus, listParkingTasks,
        askDigiOpsAgent, cancelDigiOpsTask, getDigiOpsTaskStatus, listDigiOpsTasks,
        askPeopleOperationsAgent, cancelPeopleOperationsTask, getPeopleOperationsTaskStatus, listPeopleOperationsTasks,
        askPayrollAgent, cancelPayrollTask, getPayrollTaskStatus, listPayrollTasks,
        askTravelExpenseAgent, cancelTravelExpenseTask, getTravelExpenseTaskStatus, listTravelExpenseTasks
    ]
);
