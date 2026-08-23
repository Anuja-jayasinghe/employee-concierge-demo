package com.wso2.employeeconcierge.payroll;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import java.util.List;
import org.a2aproject.sdk.server.PublicAgentCard;
import org.a2aproject.sdk.spec.AgentCapabilities;
import org.a2aproject.sdk.spec.AgentCard;
import org.a2aproject.sdk.spec.AgentInterface;
import org.a2aproject.sdk.spec.AgentSkill;
import org.a2aproject.sdk.spec.TransportProtocol;
import org.eclipse.microprofile.config.inject.ConfigProperty;

/** Produces the public agent card for the WSO2 Payroll Agent. */
@ApplicationScoped
public final class PayrollAgentCardProducer {

  @Inject
  @ConfigProperty(name = "quarkus.grpc.server.port")
  private int grpcPort;

  @Produces
  @PublicAgentCard
  public AgentCard agentCard() {
    return AgentCard.builder()
        .name("Payroll Agent")
        .description("WSO2 Payroll — payslip corrections and payroll lookups.")
        .version("0.1.0")
        .capabilities(
            AgentCapabilities.builder()
                .streaming(false)
                .pushNotifications(true)
                .extendedAgentCard(true)
                .build())
        .defaultInputModes(List.of("text"))
        .defaultOutputModes(List.of("text"))
        .skills(
            List.of(
                AgentSkill.builder()
                    .id("payslip-correction")
                    .name("Request a payslip correction")
                    .description("Files a payslip correction request for review.")
                    .tags(List.of("payroll", "payslip"))
                    .examples(List.of("my payslip shows the wrong tax deduction"))
                    .build(),
                AgentSkill.builder()
                    .id("payroll-lookup")
                    .name("Answer payroll questions")
                    .description("Answers common payroll questions — pay cycle, deductions.")
                    .tags(List.of("payroll", "faq"))
                    .examples(List.of("when is the next pay date?"))
                    .build()))
        .supportedInterfaces(
            List.of(new AgentInterface(TransportProtocol.GRPC.asString(), "localhost:" + grpcPort)))
        .build();
  }
}
