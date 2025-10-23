%dw 2.0
import * from dw::util::Values

/**
 * Logger Builder - FIXED to avoid duplicate keys
 * Only initializes fields with config defaults, not mandatory fields
 */

/**
 * Initialize builder - only sets config defaults
 */
fun newLogger(): Object = 
  buildLogger({
    reportingRequest: {
      loggingEntry: {
        // DO NOT initialize mandatory fields - they'll be added by builder methods
        // Only config defaults here
        env: p('logging.defaultEnv'),
        logEntry: p('logging.defaultLogEntry') as Boolean,
        businessUnit: p('logging.p(',
        dateTimeStamp: now() as String { format: "MM/dd/yyyy" },
        errorMessage: ""
      },
      email: {
        sendEmail: p('logging.defaultSendEmail') as Boolean,
        emailTo: p('logging.defaultEmailTo')
      },
      serviceNow: {
        createSNowTicket: p('logging.defaultCreateTicket') as Boolean,
        shortDescription: "",
        description: ""
      }
    }
  })

/**
 * Builder function with all chainable methods
 */
fun buildLogger(loggerObj: Object) = {
  
  // ===== MANDATORY FIELDS (use ++ to ADD, not update) =====
  
  withProcessId: (processId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { processId: processId }
    }),
  
  withProcessName: (processName: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { processName: processName }
    }),
  
  withCorrelationId: (correlationId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { correlationId: correlationId }
    }),
  
  withApiName: (apiName: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { apiName: apiName }
    }),
  
  // ===== LOG TYPE METHODS =====
  
  /**
   * START: email=false, status=START, message="$(process) has started.", createTicket=false
   */
  asStart: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { 
          status: "START",
          message: "$(loggingEntry.processName) has started."
        }
    }),
  
  /**
   * SUCCESS: email=false, status=SUCCESS, message="$(process) has completed successfully!", createTicket=false
   */
  asSuccess: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { 
          status: "SUCCESS",
          message: "$(loggingEntry.processName) has completed successfully!"
        }
    }),
  
  /**
   * ERROR: email=true, status=ERROR, message="$(process) has completed with error.", createTicket=true
   */
  asError: (errorMessage: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { 
          status: "ERROR",
          message: "$(loggingEntry.processName) has completed with error.",
          errorMessage: errorMessage
        }
      case email at .reportingRequest.email -> 
        email update "sendEmail" with true
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow ++ { 
          createSNowTicket: true,
          shortDescription: "Error in $(loggerObj.reportingRequest.loggingEntry.apiName)",
          description: errorMessage
        }
    }),
  
  // ===== OVERRIDE EMAIL (use update since these exist) =====
  
  withEmail: (emailTo: String) -> 
    buildLogger(loggerObj update {
      case email at .reportingRequest.email -> 
        email update "emailTo" with emailTo update "sendEmail" with true
    }),
  
  withoutEmail: () -> 
    buildLogger(loggerObj update {
      case email at .reportingRequest.email -> 
        email update "sendEmail" with false
    }),
  
  // ===== OVERRIDE TICKET (use update since these exist) =====
  
  withTicket: (shortDesc: String, description: String) -> 
    buildLogger(loggerObj update {
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with true
          update "shortDescription" with shortDesc
          update "description" with description
    }),
  
  withoutTicket: () -> 
    buildLogger(loggerObj update {
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow update "createSNowTicket" with false
    }),
  
  // ===== TERMINAL METHOD =====
  
  build: () -> 
    loggerObj.reportingRequest filterObject (value, key) -> !isEmpty(value)
}
