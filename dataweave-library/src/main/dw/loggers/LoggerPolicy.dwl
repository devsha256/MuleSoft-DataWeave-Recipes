%dw 2.0
import * from dw::util::Values

/* -------- START policy -------- */
fun startPolicy(): Object = {
    logEntry: (Mule::p("logging.policy.start.logEntry") default "false") as Boolean,
    sendEmail: (Mule::p("logging.policy.start.sendEmail") default "false") as Boolean,
    createTicket: (Mule::p("logging.policy.start.createTicket") default "false") as Boolean
}

/* -------- SUCCESS policy -------- */
fun successPolicy(): Object = {
    logEntry: (Mule::p("logging.policy.success.logEntry") default "false") as Boolean,
    sendEmail: (Mule::p("logging.policy.success.sendEmail") default "false") as Boolean,
    createTicket: (Mule::p("logging.policy.success.createTicket") default "false") as Boolean
}

/* -------- ERROR policy (context aware) -------- */
fun errorPolicy(ctx: Object): Object = {
    logEntry: (Mule::p("logging.policy.error.logEntry") default "false") as Boolean,
    sendEmail: (Mule::p("logging.policy.error.sendEmail") default "false") as Boolean,
    createTicket: ((Mule::p("logging.policy.error.createTicket") default "false") as Boolean) 
                  and (ctx.errorTicketEnabled default false)
}

/* -------- Apply overrides deterministically -------- */
fun applyOverrides(base: Object, overrides: Object): Object =
    base update {
        case v at .logEntry -> overrides.logEntry default v
        case v at .sendEmail -> overrides.sendEmail default v
        case v at .createTicket -> overrides.createTicket default v
    }

/* -------- Public resolver -------- */
fun policy(name: String, ctx: Object, overrides: Object = {}): Object = 
    do {
        var base = upper(name) match {
            case "START" -> startPolicy()
            case "SUCCESS" -> successPolicy()
            case "ERROR" -> errorPolicy(ctx)
            else -> {}
        }
        ---
        applyOverrides(base, overrides)
    }
