// Real ballerina/a2a client verification against the real, running Parking
// Manager Agent (agents/parking) — no mocks, no stubs. Start the agent first:
//
//   cd agents/parking && uv run __main__.py
//
// then run this script from this directory: bal run --sticky
import ballerina/a2a;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/uuid;

const string AGENT_URL = "http://127.0.0.1:8000";

function mkMessage(string text) returns a2a:Message => {
    messageId: uuid:createType4AsString(),
    role: a2a:ROLE_USER,
    parts: [{text}]
};

public function main() returns error? {
    a2a:Client c = check new (AGENT_URL);
    int failures = 0;

    io:println("=== Parking Manager Agent — real ballerina/a2a verification ===\n");

    // 1. sendMessage: availability Q&A, no task created.
    a2a:Task|a2a:Message freeCheck = check c->sendMessage(mkMessage("is spot A03 free?"));
    if freeCheck is a2a:Message {
        io:println("[ok] sendMessage (availability): ", freeCheck.parts[0]?.text ?: "");
    } else {
        io:println("[FAIL] expected a plain Message for an availability query, got a Task");
        failures += 1;
    }

    // 2. Reservation + cancelTask mid-flight.
    a2a:Task|a2a:Message pending = check c->sendMessage(mkMessage("reserve spot A01"), config = {returnImmediately: true});
    if pending is a2a:Task {
        runtime:sleep(1);
        a2a:Task cancelled = check c->cancelTask(pending.id);
        if cancelled.status.state == a2a:TASK_STATE_CANCELED {
            io:println("[ok] cancelTask mid-reservation -> CANCELED");
        } else {
            io:println("[FAIL] expected CANCELED, got ", cancelled.status.state);
            failures += 1;
        }
    } else {
        io:println("[FAIL] expected a Task for a reservation request");
        failures += 1;
    }

    // 3. Reservation resolving naturally to COMPLETED.
    a2a:Task|a2a:Message completed = check c->sendMessage(mkMessage("reserve spot A04"));
    if completed is a2a:Task && completed.status.state == a2a:TASK_STATE_COMPLETED {
        io:println("[ok] reservation resolves naturally -> COMPLETED");
    } else {
        io:println("[FAIL] expected a completed reservation Task");
        failures += 1;
    }

    // 4. Reserving an already-taken spot -> REJECTED.
    a2a:Task|a2a:Message rejected = check c->sendMessage(mkMessage("reserve spot A02"));
    if rejected is a2a:Task && rejected.status.state == a2a:TASK_STATE_REJECTED {
        io:println("[ok] reserving a taken spot -> REJECTED");
    } else {
        io:println("[FAIL] expected a rejected reservation Task");
        failures += 1;
    }

    // 5. Negative case: canceling an already-terminal task must fail gracefully.
    if completed is a2a:Task {
        a2a:Task|error afterTerminalCancel = c->cancelTask(completed.id);
        if afterTerminalCancel is error {
            io:println("[ok] canceling a terminal task correctly fails: ", afterTerminalCancel.message());
        } else {
            io:println("[FAIL] canceling a terminal task should have failed");
            failures += 1;
        }
    }

    // 6. Push-notification config create + delete.
    a2a:Task|a2a:Message forConfig = check c->sendMessage(mkMessage("reserve spot B01"));
    if forConfig is a2a:Task {
        a2a:TaskPushNotificationConfig created = check c->createTaskPushNotificationConfig({
            taskId: forConfig.id,
            url: "http://127.0.0.1:9999/webhook"
        });
        string? configId = created?.id;
        if configId is string {
            check c->deleteTaskPushNotificationConfig(forConfig.id, configId);
            io:println("[ok] push-notification config create + delete round-trip");
        } else {
            io:println("[FAIL] created push-notification config had no id");
            failures += 1;
        }
    } else {
        io:println("[FAIL] expected a Task to attach a push-notification config to");
        failures += 1;
    }

    io:println("\n=== ", failures == 0 ? "ALL PASSED" : failures.toString() + " FAILURE(S)", " ===");
    if failures > 0 {
        return error(failures.toString() + " verification check(s) failed");
    }
}
