%dw 2.0
import * from dw::util::Values

/**
 * Logger Builder - Final Version
 * Fixes: Parentheses syntax, dynamic field addition, and duplicate key prevention.
 */

// Helper: Safely resolve nested paths
var getNestedValue = (obj: Any, path: String) -> (
    (path replace "'" with "") splitBy "." reduce (key, acc = obj) -> 
        if (acc is Object) acc[key] else null
)

/**
 * Initialize builder - sets config defaults
 * Ensures 'message' is initialized so 'update' works later.
 */
fun newLogger(): Object = 
  buildLogger({
    reportingRequest: {
      loggingEntry: {
        env: p('logging.defaultEnv'),
        logEntry: p('logging.defaultLogEntry') as Boolean,
        businessUnit: p('logging.defaultBusinessUnit'),
        dateTimeStamp: now() as String { format: "MM/dd/yyyy" },
        errorMessage: "",
        message: "" // Initialized for intermediate updates
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
  
  // ===== MANDATORY FIELDS (use ++ to ensure addition if missing) =====
  
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
  
  // ===== INTERMEDIATE CONTEXT =====

  withQueryParams: (queryParams: Object) -> buildLogger(loggerObj update {
    case m at .reportingRequest.loggingEntry.message -> do {
        var paramsStr = if (!isEmpty(queryParams)) write(queryParams, "application/java") else ""
        ---
        if (paramsStr != "") (m ++ " | Params: " ++ paramsStr) else m
    }
  }),

  withPayloadFields: (payload: Any, fieldsInput: String) -> buildLogger(loggerObj update {
    case m at .reportingRequest.loggingEntry.message -> do {
        var fieldList = (fieldsInput splitBy ",") map (trim($) replace "'" with "")
        var flatObj = fieldList reduce (path, acc = {}) -> 
            acc ++ { (path): getNestedValue(payload, path) }
        var dataStr = write(flatObj, "application/java")
        ---
        (m ++ " | Data: " ++ dataStr)
    }
  }),

  // ===== LOG TYPE METHODS (Using ++ for addition, update for existing) =====
  
  asStart: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        (loggingEntry ++ { status: "START" })
          update "message" with ("$(loggingEntry.processName) has started" ++ (loggingEntry.message default ""))
          update "errorMessage" with ""
      case email at .reportingRequest.email -> 
        email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with false
          update "shortDescription" with ""
          update "description" with ""
    }),
  
  asSuccess: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        (loggingEntry ++ { status: "SUCCESS" })
          update "message" with ("$(loggingEntry.processName) has completed successfully" ++ (loggingEntry.message default ""))
          update "errorMessage" with ""
      case email at .reportingRequest.email -> 
        email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with false
          update "shortDescription" with ""
          update "description" with ""
    }),
  
  asError: (errorMessage: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        (loggingEntry ++ { status: "ERROR" })
          update "message" with ("$(loggingEntry.processName) has completed with error" ++ (loggingEntry.message default ""))
          update "errorMessage" with errorMessage
      case email at .reportingRequest.email -> 
        email update "sendEmail" with true
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with true
          update "shortDescription" with ("Error in " ++ (loggerObj.reportingRequest.loggingEntry.apiName default "API"))
          update "description" with errorMessage
    }),
  
  // ===== OPTIONAL FIELDS =====
  
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
  
  // ===== OVERRIDES =====
  
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
