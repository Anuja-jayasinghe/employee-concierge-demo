// Discover-and-delegate tools: a small, generic set the real ballerina/ai
// Agent uses to reach any of the five real downstream agents, instead of
// twenty named per-agent, per-operation tools. Mirrors the real pattern
// WSO2 Integrator: BI itself generates (see
// ~/WSO2Integrator/wso2-integrator-a2a/a2ademoassistant/functions.bal) --
// a small KnownAgent registry, real AgentCards resolved on demand via
// discoverAgents, and delegateToAgent/cancelAgentTask/getAgentTaskStatus/
// listAgentTasks acting on whichever agent name the model picks.
//
// No agent's real Agent Card is resolved until something actually
// delegates to it -- unlike the previous module-level `final a2a:Client`
// per agent, which resolved all five eagerly at module init and meant the
// whole orchestrator failed to boot if any one agent was down.
import ballerina/a2a;
import ballerina/ai;
import ballerina/lang.runtime;
import ballerina/os;
import ballerina/uuid;

type KnownAgent record {|
    string name;
    string url;
|};

// Local-process defaults (127.0.0.1); each is overridable via its own env
// var to the real Docker Compose service name (e.g. "http://parking:8000")
// in containerized deployment, since 127.0.0.1 inside a container refers
// to that container itself, not a sibling one.
final KnownAgent[] & readonly knownAgents = [
    {name: "Parking", url: os:getEnv("PARKING_URL") != "" ? os:getEnv("PARKING_URL") : "http://127.0.0.1:8000"},
    {name: "DigiOps", url: os:getEnv("DIGIOPS_URL") != "" ? os:getEnv("DIGIOPS_URL") : "http://127.0.0.1:8001"},
    {name: "PeopleOperations", url: os:getEnv("PEOPLEOPS_URL") != "" ? os:getEnv("PEOPLEOPS_URL") : "http://127.0.0.1:8002"},
    {name: "Payroll", url: os:getEnv("PAYROLL_URL") != "" ? os:getEnv("PAYROLL_URL") : "http://127.0.0.1:8003"},
    {name: "TravelExpense", url: os:getEnv("TRAVEL_EXPENSE_URL") != "" ? os:getEnv("TRAVEL_EXPENSE_URL") : "http://127.0.0.1:8004"}
];

isolated map<a2a:Client> agentClients = {};

isolated function findKnownAgent(string agentName) returns KnownAgent|error {
    foreach KnownAgent known in knownAgents {
        if known.name == agentName {
            return known;
        }
    }
    return error("Unknown agent: " + agentName);
}

// Resolves (and caches) a real a2a:Client for the named agent, only when
// something actually needs to talk to it.
isolated function getAgentClient(string agentName) returns a2a:Client|error {
    KnownAgent known = check findKnownAgent(agentName);
    lock {
        a2a:Client? existing = agentClients[agentName];
        if existing is a2a:Client {
            return existing;
        }
        a2a:Client fresh = check new (known.url);
        agentClients[agentName] = fresh;
        return fresh;
    }
}

isolated function joinPartsText(a2a:Part[] parts) returns string {
    string[] texts = [];
    foreach a2a:Part part in parts {
        string? text = part?.text;
        if text is string {
            texts.push(text);
        }
    }
    return string:'join(" ", ...texts);
}

isolated function taskText(a2a:Task task) returns string {
    a2a:Artifact[] artifacts = task.artifacts;
    if artifacts.length() > 0 {
        return joinPartsText(artifacts[artifacts.length() - 1].parts);
    }
    a2a:Message? statusMessage = task.status?.message;
    if statusMessage is a2a:Message {
        return joinPartsText(statusMessage.parts);
    }
    return "(no textual response from the agent — task state: " + task.status.state.toString() + ")";
}

// Includes the real task id in every Task-backed reply so the model can
// recall it (via its own conversation memory) if the employee later asks
// to check on, or cancel, the same request.
isolated function summarizeTask(a2a:Task task) returns string {
    return "[" + task.status.state.toString() + "] " + taskText(task) + " (task id: " + task.id + ")";
}

isolated function summarizeTasks(a2a:Task[] tasks) returns string {
    if tasks.length() == 0 {
        return "No tasks found.";
    }
    string[] lines = [];
    foreach a2a:Task task in tasks {
        lines.push(summarizeTask(task));
    }
    return string:'join("\n", ...lines);
}

isolated function extractResponseText(a2a:Task|a2a:Message result) returns string {
    if result is a2a:Message {
        return joinPartsText(result.parts);
    } else if result is a2a:Task {
        return summarizeTask(result);
    }
    panic error("unreachable: result is always a2a:Task or a2a:Message");
}

// Some downstream agents (onboarding, hardware provisioning) run for
// real minutes; most finish in well under a second. returnImmediately
// makes every sendMessage call return as soon as the task is created
// (SUBMITTED), regardless of how long the real work takes -- so the
// only way to keep today's fast agents feeling synchronous is to poll
// here, bounded, rather than block on sendMessage itself (which the
// underlying http:Client's stock 30s timeout would risk on a slow one
// anyway). A still-non-terminal task after the window just falls
// through to extractResponseText/summarizeTask as-is -- that already
// produces an honest "still working, here's the task id" reply with no
// new formatting needed.
final decimal MAX_INITIAL_WAIT_SECONDS = 20d;
final decimal POLL_INTERVAL_SECONDS = 0.5d;

isolated function isSettled(a2a:TaskState state) returns boolean {
    return state == a2a:TASK_STATE_COMPLETED || state == a2a:TASK_STATE_FAILED
        || state == a2a:TASK_STATE_CANCELED || state == a2a:TASK_STATE_REJECTED
        || state == a2a:TASK_STATE_INPUT_REQUIRED || state == a2a:TASK_STATE_AUTH_REQUIRED;
}

// Polls a still-in-progress task, checking immediately first (no leading
// sleep -- returnImmediately means the very first check happens right at
// task-creation time regardless of work duration, so a fixed sleep before
// it would just be dead latency on every call), then sleeping between
// subsequent attempts, up to MAX_INITIAL_WAIT_SECONDS total.
isolated function pollUntilSettled(a2a:Client agentClient, a2a:Task initial) returns a2a:Task|error {
    a2a:Task task = initial;
    decimal elapsed = 0d;
    boolean first = true;
    while !isSettled(task.status.state) && elapsed < MAX_INITIAL_WAIT_SECONDS {
        if !first {
            runtime:sleep(POLL_INTERVAL_SECONDS);
            elapsed += POLL_INTERVAL_SECONDS;
        }
        first = false;
        task = check agentClient->getTask(task.id);
    }
    return task;
}

isolated function sendToAgent(a2a:Client agentClient, string message) returns string|error {
    a2a:Message msg = {messageId: uuid:createType4AsString(), role: a2a:ROLE_USER, parts: [{text: message}]};
    a2a:Task|a2a:Message result = check agentClient->sendMessage(msg, config = {returnImmediately: true});
    if result is a2a:Task {
        a2a:Task settled = check pollUntilSettled(agentClient, result);
        return extractResponseText(settled);
    }
    return extractResponseText(result);
}

isolated function cancelTaskOn(a2a:Client agentClient, string taskId) returns string|error {
    a2a:Task result = check agentClient->cancelTask(taskId);
    return summarizeTask(result);
}

isolated function getTaskStatusOn(a2a:Client agentClient, string taskId) returns string|error {
    a2a:Task result = check agentClient->getTask(taskId);
    return summarizeTask(result);
}

isolated function listTasksOn(a2a:Client agentClient) returns string|error {
    a2a:ListTasksResult result = check agentClient->listTasks();
    return summarizeTasks(result.tasks);
}

# Fetches the real Agent Card (name, description, skills) for every known
# WSO2 agent, so you can see what each one actually does and pick the
# right one to delegate to. Call this once near the start of a
# conversation, not before every request.
#
# + return - a JSON array of {name, description, skills} per agent, or an
# error if a card couldn't be fetched
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function discoverAgents() returns json|error {
    json[] cards = [];
    foreach KnownAgent known in knownAgents {
        a2a:AgentCard|error card = a2a:resolveAgentCard(known.url);
        if card is a2a:AgentCard {
            cards.push({name: known.name, description: card.description, skills: card.skills});
        } else {
            cards.push({name: known.name, 'error: "Failed to fetch this agent's card: " + card.message()});
        }
    }
    return cards;
}

# Sends a new request, in natural language, to a specific known WSO2
# agent by its exact name (from discoverAgents — not a URL).
#
# + agentName - the target agent's exact name, e.g. "Parking"
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function delegateToAgent(string agentName, string message) returns string|error {
    a2a:Client agentClient = check getAgentClient(agentName);
    return sendToAgent(agentClient, message);
}

# Cancels a pending task on a specific known agent, by its task id from an
# earlier reply.
#
# + agentName - the agent's exact name that the task belongs to
# + taskId - the task id from an earlier reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelAgentTask(string agentName, string taskId) returns string|error {
    a2a:Client agentClient = check getAgentClient(agentName);
    return cancelTaskOn(agentClient, taskId);
}

# Checks the real current status of a task on a specific known agent, by
# its task id from an earlier reply.
#
# + agentName - the agent's exact name that the task belongs to
# + taskId - the task id from an earlier reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getAgentTaskStatus(string agentName, string taskId) returns string|error {
    a2a:Client agentClient = check getAgentClient(agentName);
    return getTaskStatusOn(agentClient, taskId);
}

# Lists every real task a specific known agent has, e.g. every
# reservation, ticket, correction, or claim it's seen.
#
# + agentName - the agent's exact name
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listAgentTasks(string agentName) returns string|error {
    a2a:Client agentClient = check getAgentClient(agentName);
    return listTasksOn(agentClient);
}
