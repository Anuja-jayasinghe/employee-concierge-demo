package com.wso2.employeeconcierge.payroll;

import dev.langchain4j.agent.tool.Tool;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** Real, in-memory payroll state the LLM agent's tool calls actually mutate. */
@ApplicationScoped
public class PayrollTools {

  private final AtomicInteger nextCorrectionId = new AtomicInteger(1000);
  private final Map<String, String> corrections = new ConcurrentHashMap<>();

  @Tool("Files a payslip correction request for the given employee, describing what's wrong. "
      + "Returns the correction request ID.")
  public String fileCorrectionRequest(final String employeeName, final String description) {
    String id = "PC-" + nextCorrectionId.getAndIncrement();
    corrections.put(id, employeeName + ": " + description);
    return id;
  }

  @Tool("Looks up the status of a previously filed payslip correction request by its ID.")
  public String getCorrectionStatus(final String correctionId) {
    String entry = corrections.get(correctionId);
    if (entry == null) {
      return "No correction request found with ID " + correctionId + ".";
    }
    return "Correction request " + correctionId + " (" + entry + ") is under review by Payroll.";
  }
}
