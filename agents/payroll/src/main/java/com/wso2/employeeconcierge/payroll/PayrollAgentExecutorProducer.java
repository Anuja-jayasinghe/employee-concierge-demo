package com.wso2.employeeconcierge.payroll;

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

/** Wires the real langchain4j-anthropic PayrollAgent into a genuine A2A task lifecycle. */
@ApplicationScoped
public final class PayrollAgentExecutorProducer {

  @Inject private PayrollAgent payrollAgent;

  @Produces
  public AgentExecutor agentExecutor() {
    return new PayrollAgentExecutor(payrollAgent);
  }

  private static final class PayrollAgentExecutor implements AgentExecutor {

    private final PayrollAgent agent;

    PayrollAgentExecutor(final PayrollAgent agentInstance) {
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
      // calling, whether this is a payslip correction (fileCorrectionRequest),
      // a status check (getCorrectionStatus), or a plain FAQ answered from
      // the system prompt's reference facts.
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
