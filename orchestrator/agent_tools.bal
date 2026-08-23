// Five real tool functions, one per downstream Employee Concierge agent.
// Each resolves its target's Agent Card once at module init and holds a
// reusable ballerina/a2a Client — real client, real card, real target
// agent, no bypass. Wired into a real ballerina/ai Agent in the next
// commit; these are directly callable and testable on their own before
// that, since they don't depend on the AI layer at all.
import ballerina/a2a;
import ballerina/ai;
import ballerina/os;
import ballerina/uuid;

// Local-process defaults (127.0.0.1); each is overridable via its own env
// var to the real Docker Compose service name (e.g. "http://parking:8000")
// in containerized deployment, since 127.0.0.1 inside a container refers
// to that container itself, not a sibling one.
final string PARKING_URL = os:getEnv("PARKING_URL") != "" ? os:getEnv("PARKING_URL") : "http://127.0.0.1:8000";
final string DIGIOPS_URL = os:getEnv("DIGIOPS_URL") != "" ? os:getEnv("DIGIOPS_URL") : "http://127.0.0.1:8001";
final string PEOPLEOPS_URL = os:getEnv("PEOPLEOPS_URL") != "" ? os:getEnv("PEOPLEOPS_URL") : "http://127.0.0.1:8002";
final string PAYROLL_URL = os:getEnv("PAYROLL_URL") != "" ? os:getEnv("PAYROLL_URL") : "http://127.0.0.1:8003";
final string TRAVEL_EXPENSE_URL = os:getEnv("TRAVEL_EXPENSE_URL") != "" ? os:getEnv("TRAVEL_EXPENSE_URL") : "http://127.0.0.1:8004";

final a2a:Client parkingClient = check new (PARKING_URL);
final a2a:Client digiopsClient = check new (DIGIOPS_URL);
final a2a:Client peopleOpsClient = check new (PEOPLEOPS_URL);
final a2a:Client payrollClient = check new (PAYROLL_URL);
final a2a:Client travelExpenseClient = check new (TRAVEL_EXPENSE_URL);

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

isolated function askAgent(a2a:Client agentClient, string message) returns string|error {
    a2a:Message msg = {messageId: uuid:createType4AsString(), role: a2a:ROLE_USER, parts: [{text: message}]};
    a2a:Task|a2a:Message result = check agentClient->sendMessage(msg);
    return extractResponseText(result);
}

isolated function cancelAgentTask(a2a:Client agentClient, string taskId) returns string|error {
    a2a:Task result = check agentClient->cancelTask(taskId);
    return summarizeTask(result);
}

isolated function getAgentTaskStatus(a2a:Client agentClient, string taskId) returns string|error {
    a2a:Task result = check agentClient->getTask(taskId);
    return summarizeTask(result);
}

isolated function listAgentTasks(a2a:Client agentClient) returns string|error {
    a2a:ListTasksResult result = check agentClient->listTasks();
    return summarizeTasks(result.tasks);
}

# Asks the WSO2 Parking Manager agent about parking availability, or to
# reserve or cancel a parking spot at WSO2 Colombo HQ.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function askParkingAgent(string message) returns string|error {
    return askAgent(parkingClient, message);
}

# Cancels a pending Parking task (e.g. a reservation still in progress) by
# its task id, from an earlier reply.
#
# + taskId - the task id from an earlier Parking reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelParkingTask(string taskId) returns string|error {
    return cancelAgentTask(parkingClient, taskId);
}

# Checks the real current status of a Parking task by its task id, from an
# earlier reply.
#
# + taskId - the task id from an earlier Parking reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getParkingTaskStatus(string taskId) returns string|error {
    return getAgentTaskStatus(parkingClient, taskId);
}

# Lists every real Parking task this agent knows about (reservation
# attempts and their outcomes).
#
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listParkingTasks() returns string|error {
    return listAgentTasks(parkingClient);
}

# Asks the WSO2 DigiOps (IT Helpdesk) agent an IT question, or to raise or
# check the status of a support ticket, or to investigate a reported
# incident.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function askDigiOpsAgent(string message) returns string|error {
    return askAgent(digiopsClient, message);
}

# Cancels a pending DigiOps task (e.g. a ticket or incident investigation
# still in progress) by its task id, from an earlier reply.
#
# + taskId - the task id from an earlier DigiOps reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelDigiOpsTask(string taskId) returns string|error {
    return cancelAgentTask(digiopsClient, taskId);
}

# Checks the real current status of a DigiOps task by its task id, from an
# earlier reply.
#
# + taskId - the task id from an earlier DigiOps reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getDigiOpsTaskStatus(string taskId) returns string|error {
    return getAgentTaskStatus(digiopsClient, taskId);
}

# Lists every real DigiOps task this agent knows about (tickets and
# incident investigations).
#
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listDigiOpsTasks() returns string|error {
    return listAgentTasks(digiopsClient);
}

# Asks the WSO2 PeopleOperations (HR) agent an HR policy question, or to
# run a new-hire onboarding checklist.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function askPeopleOperationsAgent(string message) returns string|error {
    return askAgent(peopleOpsClient, message);
}

# Cancels a pending PeopleOperations task (e.g. an onboarding run still in
# progress) by its task id, from an earlier reply.
#
# + taskId - the task id from an earlier PeopleOperations reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelPeopleOperationsTask(string taskId) returns string|error {
    return cancelAgentTask(peopleOpsClient, taskId);
}

# Checks the real current status of a PeopleOperations task by its task
# id, from an earlier reply.
#
# + taskId - the task id from an earlier PeopleOperations reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getPeopleOperationsTaskStatus(string taskId) returns string|error {
    return getAgentTaskStatus(peopleOpsClient, taskId);
}

# Lists every real PeopleOperations task this agent knows about (e.g.
# onboarding runs).
#
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listPeopleOperationsTasks() returns string|error {
    return listAgentTasks(peopleOpsClient);
}

# Asks the WSO2 Payroll agent a payroll question, or to file or check the
# status of a payslip correction request.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function askPayrollAgent(string message) returns string|error {
    return askAgent(payrollClient, message);
}

# Cancels a pending Payroll task (e.g. a payslip correction request still
# in progress) by its task id, from an earlier reply.
#
# + taskId - the task id from an earlier Payroll reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelPayrollTask(string taskId) returns string|error {
    return cancelAgentTask(payrollClient, taskId);
}

# Checks the real current status of a Payroll task by its task id, from an
# earlier reply.
#
# + taskId - the task id from an earlier Payroll reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getPayrollTaskStatus(string taskId) returns string|error {
    return getAgentTaskStatus(payrollClient, taskId);
}

# Lists every real Payroll task this agent knows about (payslip correction
# requests and their outcomes).
#
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listPayrollTasks() returns string|error {
    return listAgentTasks(payrollClient);
}

# Asks the WSO2 Travel & Expense agent a travel/expense policy question,
# or to file or check the status of an expense claim.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function askTravelExpenseAgent(string message) returns string|error {
    return askAgent(travelExpenseClient, message);
}

# Cancels a pending Travel & Expense task (e.g. an expense claim still in
# progress) by its task id, from an earlier reply.
#
# + taskId - the task id from an earlier Travel & Expense reply
# + return - the task's real resulting state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function cancelTravelExpenseTask(string taskId) returns string|error {
    return cancelAgentTask(travelExpenseClient, taskId);
}

# Checks the real current status of a Travel & Expense task by its task
# id, from an earlier reply.
#
# + taskId - the task id from an earlier Travel & Expense reply
# + return - the task's real current state, or an error if it failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function getTravelExpenseTaskStatus(string taskId) returns string|error {
    return getAgentTaskStatus(travelExpenseClient, taskId);
}

# Lists every real Travel & Expense task this agent knows about (expense
# claims and their outcomes).
#
# + return - a real summary of every task, or an error if the request failed
@ai:AgentTool
@display {label: "", iconPath: ""}
isolated function listTravelExpenseTasks() returns string|error {
    return listAgentTasks(travelExpenseClient);
}
