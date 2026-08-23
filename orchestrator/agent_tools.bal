// Five real tool functions, one per downstream Employee Concierge agent.
// Each resolves its target's Agent Card once at module init and holds a
// reusable ballerina/a2a Client — real client, real card, real target
// agent, no bypass. Wired into a real ballerina/ai Agent in the next
// commit; these are directly callable and testable on their own before
// that, since they don't depend on the AI layer at all.
import ballerina/a2a;
import ballerina/ai;
import ballerina/uuid;

const string PARKING_URL = "http://127.0.0.1:8000";
const string DIGIOPS_URL = "http://127.0.0.1:8001";
const string PEOPLEOPS_URL = "http://127.0.0.1:8002";
const string PAYROLL_URL = "http://127.0.0.1:8003";
const string TRAVEL_EXPENSE_URL = "http://127.0.0.1:8004";

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

isolated function extractResponseText(a2a:Task|a2a:Message result) returns string {
    if result is a2a:Message {
        return joinPartsText(result.parts);
    } else if result is a2a:Task {
        a2a:Task task = result;
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
    panic error("unreachable: result is always a2a:Task or a2a:Message");
}

isolated function askAgent(a2a:Client agentClient, string message) returns string|error {
    a2a:Message msg = {messageId: uuid:createType4AsString(), role: a2a:ROLE_USER, parts: [{text: message}]};
    a2a:Task|a2a:Message result = check agentClient->sendMessage(msg);
    return extractResponseText(result);
}

# Asks the WSO2 Parking Manager agent about parking availability, or to
# reserve or cancel a parking spot at WSO2 Colombo HQ.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
isolated function askParkingAgent(string message) returns string|error {
    return askAgent(parkingClient, message);
}

# Asks the WSO2 DigiOps (IT Helpdesk) agent an IT question, or to raise or
# check the status of a support ticket, or to investigate a reported
# incident.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
isolated function askDigiOpsAgent(string message) returns string|error {
    return askAgent(digiopsClient, message);
}

# Asks the WSO2 PeopleOperations (HR) agent an HR policy question, or to
# run a new-hire onboarding checklist.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
isolated function askPeopleOperationsAgent(string message) returns string|error {
    return askAgent(peopleOpsClient, message);
}

# Asks the WSO2 Payroll agent a payroll question, or to file or check the
# status of a payslip correction request.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
isolated function askPayrollAgent(string message) returns string|error {
    return askAgent(payrollClient, message);
}

# Asks the WSO2 Travel & Expense agent a travel/expense policy question,
# or to file or check the status of an expense claim.
#
# + message - the employee's request, in natural language
# + return - the agent's real reply, or an error if the request failed
@ai:AgentTool
isolated function askTravelExpenseAgent(string message) returns string|error {
    return askAgent(travelExpenseClient, message);
}
