package com.wso2.employeeconcierge.travelexpense;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import java.util.List;
import org.a2aproject.sdk.server.agentexecution.AgentExecutor;
import org.a2aproject.sdk.server.agentexecution.RequestContext;
import org.a2aproject.sdk.server.tasks.AgentEmitter;
import org.a2aproject.sdk.spec.A2AError;
import org.a2aproject.sdk.spec.Part;
import org.a2aproject.sdk.spec.Task;
import org.a2aproject.sdk.spec.TaskNotCancelableError;
import org.a2aproject.sdk.spec.TextPart;

/** Wires the real langchain4j-anthropic TravelExpenseAgent into a genuine A2A task lifecycle. */
@ApplicationScoped
public final class TravelExpenseAgentExecutorProducer {

  @Inject private TravelExpenseAgent travelExpenseAgent;

  @Produces
  public AgentExecutor agentExecutor() {
    return new TravelExpenseAgentExecutor(travelExpenseAgent);
  }

  private static final class TravelExpenseAgentExecutor implements AgentExecutor {

    private final TravelExpenseAgent agent;

    TravelExpenseAgentExecutor(final TravelExpenseAgent agentInstance) {
      this.agent = agentInstance;
    }

    @Override
    public void execute(final RequestContext context, final AgentEmitter emitter) throws A2AError {
      if (context.getTask() == null) {
        emitter.submit();
      }
      emitter.startWork();

      final String userInput = context.getUserInput();
      // A real Anthropic call: the model itself decides, via its own tool
      // calling, whether this is an expense claim (fileExpenseClaim), a
      // status check (getClaimStatus), or a plain policy FAQ answered from
      // the system prompt's reference facts — same shared-path pattern as
      // Payroll/DigiOps/PeopleOperations.
      final String response = agent.respond(userInput);

      final List<Part<?>> parts = List.of(new TextPart(response, null));
      emitter.addArtifact(parts, null, null, null);
      emitter.complete();
    }

    @Override
    public void cancel(final RequestContext context, final AgentEmitter emitter) throws A2AError {
      final Task task = context.getTask();
      if (task == null || task.status().state().isFinal()) {
        throw new TaskNotCancelableError();
      }
      emitter.cancel();
    }
  }
}
