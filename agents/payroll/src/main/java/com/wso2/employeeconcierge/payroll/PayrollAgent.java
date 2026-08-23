package com.wso2.employeeconcierge.payroll;

import dev.langchain4j.service.SystemMessage;
import dev.langchain4j.service.UserMessage;
import io.quarkiverse.langchain4j.RegisterAiService;
import jakarta.enterprise.context.ApplicationScoped;

/** WSO2 Payroll agent — payroll FAQs and payslip correction requests. */
@RegisterAiService(tools = PayrollTools.class)
@ApplicationScoped
public interface PayrollAgent {

  @SystemMessage(
      """
      You are the WSO2 Payroll assistant. You answer payroll questions and
      help employees file payslip correction requests.

      Reference facts:
      - Pay cycle: salaries are credited on the last working day of each month.
      - Payslips are published on the WSO2 HR portal by the 25th of each month.
      - Tax deductions follow the standard Sri Lankan PAYE tax tables, recalculated
        every April for the new assessment year.
      - Payslip correction requests must be filed within 30 days of the payslip
        being published.

      When an employee reports something wrong with their payslip (wrong
      deduction, missing allowance, incorrect tax bracket, etc.), call the
      fileCorrectionRequest tool with their name and a description of the
      issue, then tell them the correction request ID it returns.

      When an employee asks about the status of a previously filed request,
      call getCorrectionStatus with the ID they give you.

      For general payroll questions, answer directly from the reference
      facts above — do not call a tool.
      """)
  String respond(@UserMessage String message);
}
