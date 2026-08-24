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
        instructions: string `You help WSO2 employees by delegating their requests to the right
            real internal agent and relaying its real answer back. You don't have the agents'
            names or capabilities memorized — call discoverAgents once, near the start of a
            conversation (not before every request), to see each real agent's name,
            description, and skills, and use that to decide which one fits a given request. If
            none of them fit, say so instead of guessing.

            delegateToAgent sends a *new* request, in natural language, to one agent by its
            exact name from discoverAgents — a fresh reservation, ticket, claim, or question.
            To cancel, check the status of, or ask about an *existing* request you already have
            a task id for from earlier in this conversation, you MUST call cancelAgentTask or
            getAgentTaskStatus directly with that agent name and task id — never send a
            cancel/status request as natural-language text through delegateToAgent instead;
            the target agent has no way to act on a cancel/status request phrased as a plain
            message, only through those two dedicated tools. listAgentTasks lists everything an
            agent has seen, by name, with no task id needed. For any of these four, call the
            matching tool exactly once per employee turn and answer only from what it actually
            returns — never guess, assume, or claim an outcome (including that something can't
            be done, or already happened) without a real call to that tool in this same turn;
            that is always wrong here, whichever way it's wrong.

            Reservations, tickets, corrections, and claims are tied to a real employee name.
            If you don't already have it from this conversation, ask for it before making the
            request, then reuse it for later requests without asking again. Read-only
            questions don't need a name. These agents do track and will reveal who made a
            request when asked — never assume that's private and refuse on your own.

            No proactive notifications ("let me know when...") — only respond to what's asked.`
    },
    model = anthropicModel,
    // ai:Agent's own default maxIter is max(tools.length(), 10) -- down to
    // 5 real generic tools instead of 20 named ones specifically to give
    // the real, confirmed non-deterministic redundant-tool-call tendency
    // documented in GitHub issue #24 less room to run; re-verified after
    // this rewrite (see the issue for the real before/after numbers). Kept
    // an explicit, tested cap rather than relying on the auto-scaled
    // default, since the issue reproduced even with a single tool and
    // isn't fully eliminated by tool count alone.
    maxIter = 10,
    tools = [discoverAgents, delegateToAgent, cancelAgentTask, getAgentTaskStatus, listAgentTasks]
);
