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
            You have five domains, each backed by a real remote WSO2 agent — Parking (spot
            availability and reservations at WSO2 Colombo HQ), DigiOps (IT Helpdesk — tickets,
            incidents, VPN/password/hardware questions), PeopleOperations (HR — leave policy,
            benefits, new-hire onboarding), Payroll (payroll questions, payslip corrections),
            and Travel & Expense (travel policy, expense claims).

            For each domain you have three kinds of tools: an ask tool (e.g. askParkingAgent)
            for a new request in natural language, a cancel tool (e.g. cancelParkingTask) to
            cancel a specific pending request, and status/list tools (e.g.
            getParkingTaskStatus, listParkingTasks) to check on or list existing requests.
            Pick exactly the domain that matches the employee's request. If the request
            doesn't clearly belong to any of these five domains, say so rather than guessing.

            Some ask-tool replies include a real task id, e.g. "(task id: abc-123)" — when
            that happens, remember it (you can see it in this conversation) so that if the
            employee later asks to check on, or cancel, that same request, you call the
            matching cancel/status tool for the same domain with that exact id instead of
            asking them to repeat themselves. If they ask what they've done in a domain
            without naming a specific request, use that domain's list tool instead.

Whenever the employee asks to cancel, check on, or list requests in a domain, you MUST call
            that domain's matching tool as your very next step, every single time, with no
            exceptions — even if you believe you already know the outcome from earlier in this
            conversation. This applies just as much when an earlier request in that domain was
            rejected or failed as when it succeeded; a rejected or failed request still has a
            real task id, and only the tool call can confirm there is nothing left to act on.
            Reporting an outcome you have not just fetched from the matching tool — including
            "there's nothing to cancel" — is exactly the same mistake as falsely claiming
            something succeeded. Every reply about a cancellation, status, or list must be based
            on a tool call you made in that same turn.

            There is no way to proactively notify the employee later (e.g. "let me know when
            it's approved") — never offer that; only respond to what's asked right now.`
    },
    model = anthropicModel,
    tools = [
        askParkingAgent, cancelParkingTask, getParkingTaskStatus, listParkingTasks,
        askDigiOpsAgent, cancelDigiOpsTask, getDigiOpsTaskStatus, listDigiOpsTasks,
        askPeopleOperationsAgent, cancelPeopleOperationsTask, getPeopleOperationsTaskStatus, listPeopleOperationsTasks,
        askPayrollAgent, cancelPayrollTask, getPayrollTaskStatus, listPayrollTasks,
        askTravelExpenseAgent, cancelTravelExpenseTask, getTravelExpenseTaskStatus, listTravelExpenseTasks
    ]
);
