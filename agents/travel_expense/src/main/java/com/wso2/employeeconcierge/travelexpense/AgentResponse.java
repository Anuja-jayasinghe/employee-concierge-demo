package com.wso2.employeeconcierge.travelexpense;

/**
 * Structured reply the LLM must produce, mirroring the status-driven pattern the three Python
 * agents already use (google-adk's output_schema / LangGraph's response_format) -- lets the
 * executor genuinely branch (complete vs. requiresInput vs. fail) instead of always completing.
 *
 * @param message reply text for the employee -- the only thing they ever see
 * @param status one of "completed", "input-required", "failed"
 */
public record AgentResponse(String message, String status) {}
