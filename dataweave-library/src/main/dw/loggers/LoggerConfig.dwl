%dw 2.0

fun baseLoggerConfig(ctx: Object) = {
    reportingRequest: {
        loggingEntry: {
            logEntry: true, // Default to true, updated by policy
            env: ctx.env,
            processName: ctx.processName,
            apiName: ctx.apiName,
            dateTimeStamp: now() as String {format: "yyyy-MM-dd HH:mm:ss.SSS"},
            businessUnit: ctx.businessUnit,
            processId: ctx.processId,
            correlationId: ctx.correlationId,
            message: "",
            status: "",
            errorMessage: ""
        },
        email: {
            sendEmail: false,
            emailTo: ctx.emailTo
        },
        serviceNow: {
            createSNowTicket: false,
            shortDescription: "",
            description: ""
        }
    }
}
