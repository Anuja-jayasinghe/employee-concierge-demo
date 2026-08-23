// The push-notification webhook receiver the orchestrator hosts. Agents
// with pushNotifications capability (Parking, Payroll, Travel & Expense)
// are registered with a config pointing here; this logs every real
// delivery so Phase 6's verification script can assert it actually
// happened, not just that the config CRUD succeeded.
import ballerina/http;
import ballerina/log;
import ballerina/time;

public const string WEBHOOK_PATH = "/webhooks/push";

public type NotificationReceipt record {|
    string taskId;
    string? state;
    string token;
    string receivedAt;
|};

isolated NotificationReceipt[] receivedNotifications = [];

isolated function recordNotification(NotificationReceipt receipt) {
    lock {
        receivedNotifications.push(receipt.clone());
    }
}

isolated function extractTaskId(json payload) returns string? {
    if payload is map<json> {
        json? id = payload["id"];
        if id is string {
            return id;
        }
        json? taskId = payload["taskId"];
        if taskId is string {
            return taskId;
        }
    }
    return ();
}

isolated function extractState(json payload) returns string? {
    if payload is map<json> {
        json? status = payload["status"];
        if status is map<json> {
            json? state = status["state"];
            if state is string {
                return state;
            }
        }
    }
    return ();
}

service on new http:Listener(9090) {

    resource function post webhooks/push(http:Request req) returns http:Ok|http:BadRequest {
        json|error payload = req.getJsonPayload();
        if payload is error {
            return <http:BadRequest>{body: "expected a JSON push-notification payload"};
        }
        string? taskId = extractTaskId(payload);
        if taskId is () {
            return <http:BadRequest>{body: "payload has neither 'id' nor 'taskId'"};
        }
        string|http:HeaderNotFoundError tokenHeader = req.getHeader("X-A2A-Notification-Token");
        string token = tokenHeader is string ? tokenHeader : "";
        NotificationReceipt receipt = {
            taskId,
            state: extractState(payload),
            token,
            receivedAt: time:utcToString(time:utcNow())
        };
        recordNotification(receipt);
        log:printInfo("received push notification", taskId = taskId, state = receipt.state);
        return <http:Ok>{};
    }

    resource function get webhooks/received() returns NotificationReceipt[] {
        lock {
            return receivedNotifications.clone();
        }
    }
}

