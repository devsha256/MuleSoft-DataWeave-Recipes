%dw 2.0
output application/java
---
{
    /* ---- Environment / App identity ---- */
    env: p("env"),
    businessUnit: p("businessUnit"),
    apiName: p("app.name"),

    /* ---- Process identity ---- */
    // These typically come from your specific process configuration
    processId: Mule::p("esiidVerification.processId"),
    processName: Mule::p("esiidVerification.processName"),
    correlationId: correlationId,

    /* ---- Logger routing defaults ---- */
    emailTo: p("logging.policy.error.emailTo"),

    /* ---- Feature flags exposed to policy layer ---- */
    errorTicketEnabled: (p("logging.policy.error.createTicket") default "false") as Boolean,
    
    /* ---- Policy References (Optional but helpful for debug) ---- */
    policyStart: {
        logEntry: (p("logging.policy.start.logEntry") default "false") as Boolean,
        sendEmail: (p("logging.policy.start.sendEmail") default "false") as Boolean,
        createTicket: (p("logging.policy.start.createTicket") default "false") as Boolean
    },
    policySuccess: {
        logEntry: (p("logging.policy.success.logEntry") default "false") as Boolean,
        sendEmail: (p("logging.policy.success.sendEmail") default "false") as Boolean,
        createTicket: (p("logging.policy.success.createTicket") default "false") as Boolean
    },
    policyError: {
        logEntry: (p("logging.policy.error.logEntry") default "false") as Boolean,
        sendEmail: (p("logging.policy.error.sendEmail") default "false") as Boolean,
        createTicket: (p("logging.policy.error.createTicket") default "false") as Boolean
    }
}
