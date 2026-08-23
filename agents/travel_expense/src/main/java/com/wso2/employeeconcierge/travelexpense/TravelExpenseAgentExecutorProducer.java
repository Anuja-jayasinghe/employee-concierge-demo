package com.wso2.employeeconcierge.travelexpense;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import org.a2aproject.sdk.server.agentexecution.AgentExecutor;
import org.a2aproject.sdk.server.agentexecution.RequestContext;
import org.a2aproject.sdk.server.tasks.AgentEmitter;
import org.a2aproject.sdk.spec.A2AError;

/**
 * Scaffolding only for now: the real langchain4j-anthropic agent, task
 * lifecycle, and push-notification config land in follow-up commits.
 */
@ApplicationScoped
public final class TravelExpenseAgentExecutorProducer {

  @Produces
  public AgentExecutor agentExecutor() {
    return new TravelExpenseAgentExecutor();
  }

  private static final class TravelExpenseAgentExecutor implements AgentExecutor {

    @Override
    public void execute(final RequestContext context, final AgentEmitter emitter) throws A2AError {
      throw new UnsupportedOperationException("not implemented yet");
    }

    @Override
    public void cancel(final RequestContext context, final AgentEmitter emitter) throws A2AError {
      throw new UnsupportedOperationException("not implemented yet");
    }
  }
}
