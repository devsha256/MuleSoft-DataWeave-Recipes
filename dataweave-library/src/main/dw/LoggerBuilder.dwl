%dw 2.0
import * from dw::util::Values

/**
 * Logger Builder - Updated with proper field handling
 * Initializes errorMessage, shortDescription, description as empty strings
 * Uses update for these fields in asStart/asSuccess/asError
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
        businessUnit: p('logging.defaultBusinessUnit'),
        dateTimeStamp: now() as String { format: "MM/dd/yyyy" },
        errorMessage: ""  // Initialize as empty string
      },
      email: {
        sendEmail: p('logging.defaultSendEmail') as Boolean,
        emailTo: p('logging.defaultEmailTo')
      },
      serviceNow: {
        createSNowTicket: p('logging.defaultCreateTicket') as Boolean,
        shortDescription: "",  // Initialize as empty string
        description: ""        // Initialize as empty string
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
   * Updates errorMessage to empty, shortDescription to empty, description to empty
   */
  asStart: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "START",
            message: "$(loggingEntry.processName) has started."
          }
          update "errorMessage" with ""
      case email at .reportingRequest.email -> 
        email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with false
          update "shortDescription" with ""
          update "description" with ""
    }),
  
  /**
   * SUCCESS: email=false, status=SUCCESS, message="$(process) has completed successfully!", createTicket=false
   * Updates errorMessage to empty, shortDescription to empty, description to empty
   */
  asSuccess: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "SUCCESS",
            message: "$(loggingEntry.processName) has completed successfully!"
          }
          update "errorMessage" with ""
      case email at .reportingRequest.email -> 
        email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with false
          update "shortDescription" with ""
          update "description" with ""
    }),
  
  /**
   * ERROR: email=true, status=ERROR, message="$(process) has completed with error.", createTicket=true
   * Updates errorMessage with error, shortDescription and description with error details
   */
  asError: (errorMessage: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "ERROR",
            message: "$(loggingEntry.processName) has completed with error."
          }
          update "errorMessage" with errorMessage
      case email at .reportingRequest.email -> 
        email update "sendEmail" with true
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with true
          update "shortDescription" with "Error in $(loggerObj.reportingRequest.loggingEntry.apiName)"
          update "description" with errorMessage
    }),
  
  // ===== OPTIONAL FIELDS (use ++ to ADD) =====
  
  withUserId: (userId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { userId: userId }
    }),
  
  withPayload: (payload: Any) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { payload: write(payload, "application/json") }
    }),
  
  withStackTrace: (stackTrace: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { stackTrace: stackTrace }
    }),
  
  withErrorDetails: (details: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { errorDetails: details }
    }),
  
  withRequestId: (requestId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry ++ { requestId: requestId }
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
