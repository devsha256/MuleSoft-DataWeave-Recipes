%dw 2.0
import * from dw::util::Values
import baseLoggerConfig from dwl::common::LoggerConfig
import policy from dwl::common::LoggerPolicy

/**
 * LoggerBuilder.dwl
 */

fun newLogger(ctx: Object) = 
    buildLogger({
        ctx: ctx,
        state: baseLoggerConfig(ctx)
    })

fun buildLogger(logger) = {

    /* ----------- Enrichment ----------- */

    withPayloadFields: (obj: Object) -> 
        buildLogger(logger update {
            case le at .state.reportingRequest.loggingEntry -> 
                le update {
                    // Update message by appending formatted data
                    case v at .message -> (v default "") ++ " | Data: " ++ write(obj, "application/dw", {"indent": false})
                }
        }),

    /* ----------- State Transitions ----------- */

    asStart: () -> 
        buildLogger(applyPolicy(logger, "START") update {
            case le at .state.reportingRequest.loggingEntry -> 
                le update {
                    case .status -> "START"
                    // FIX: Wrapped concatenation in parentheses to resolve Trace error
                    case v at .message -> (logger.ctx.processName ++ " has started.") ++ (v default "")
                }
        }),

    asSuccess: () -> 
        buildLogger(applyPolicy(logger, "SUCCESS") update {
            case le at .state.reportingRequest.loggingEntry -> 
                le update {
                    case .status -> "SUCCESS"
                    case v at .message -> (logger.ctx.processName ++ " completed successfully.") ++ (v default "")
                }
        }),

    asError: (errMsg: String, overrides: Object = {}) -> 
        buildLogger(applyPolicy(logger, "ERROR", overrides) update {
            case le at .state.reportingRequest.loggingEntry -> 
                le update {
                    case .status -> "ERROR"
                    case .errorMessage -> errMsg
                    case v at .message -> (logger.ctx.processName ++ " failed.") ++ (v default "")
                }
            case sn at .state.reportingRequest.serviceNow -> 
                sn update {
                    case .shortDescription -> "$(logger.ctx.env) - $(logger.ctx.apiName default 'API') - Error"
                    case .description -> errMsg
                }
        }),

    /* ----------- Terminal ----------- */

    build: () -> 
        logger.state.reportingRequest
}

/* ----------- Internal ----------- */

fun applyPolicy(logger, name: String, overrides: Object = {}) = 
    do {
        var p = policy(name, logger.ctx, overrides)
        ---
        logger update {
            case email at .state.reportingRequest.email -> 
                email update { case .sendEmail -> p.sendEmail }
            case sn at .state.reportingRequest.serviceNow -> 
                sn update { case .createSNowTicket -> p.createTicket }
            case le at .state.reportingRequest.loggingEntry -> 
                le update { case .logEntry -> p.logEntry }
        }
    }
