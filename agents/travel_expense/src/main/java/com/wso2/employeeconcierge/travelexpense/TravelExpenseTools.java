package com.wso2.employeeconcierge.travelexpense;

import dev.langchain4j.agent.tool.Tool;
import jakarta.enterprise.context.ApplicationScoped;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/** Real, in-memory expense-claim state the LLM agent's tool calls actually mutate. */
@ApplicationScoped
public class TravelExpenseTools {

  private final AtomicInteger nextClaimId = new AtomicInteger(2000);
  private final Map<String, String> claims = new ConcurrentHashMap<>();

  @Tool("Files a travel or expense reimbursement claim for the given employee, with the "
      + "amount (including currency) and a description of the expense. Returns the claim ID.")
  public String fileExpenseClaim(final String employeeName, final String amount, final String description) {
    String id = "EX-" + nextClaimId.getAndIncrement();
    claims.put(id, employeeName + ": " + amount + " — " + description);
    return id;
  }

  @Tool("Looks up the status of a previously filed expense claim by its ID.")
  public String getClaimStatus(final String claimId) {
    String entry = claims.get(claimId);
    if (entry == null) {
      return "No expense claim found with ID " + claimId + ".";
    }
    return "Claim " + claimId + " (" + entry + ") is pending Travel & Expense approval.";
  }
}
