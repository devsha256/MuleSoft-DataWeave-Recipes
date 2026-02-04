%dw 2.0
import * from dw::util::Values

/**
 * Logger Builder - Corrected to prevent duplicate 'message' keys
 */

// Helper: Safely resolve nested paths
var getNestedValue = (obj: Any, path: String) -> (
    (path replace "'" with "") splitBy "." reduce (key, acc = obj) -> 
        if (acc is Object) acc[key] else null
)

fun newLogger(): Object = 
  buildLogger({
    reportingRequest: {
      loggingEntry: {
        env: p('logging.defaultEnv'),
        logEntry: p('logging.defaultLogEntry') as Boolean,
        businessUnit: p('logging.defaultBusinessUnit'),
        dateTimeStamp: now() as String { format: "MM/dd/yyyy" },
        errorMessage: "",
        message: "" // Initialized here
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

fun buildLogger(loggerObj: Object) = {
  
  // ===== MANDATORY FIELDS =====
  
  withProcessId: (processId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { processId: processId }
    }),
  
  withProcessName: (processName: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { processName: processName }
    }),
  
  withCorrelationId: (correlationId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { correlationId: correlationId }
    }),
  
  withApiName: (apiName: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { apiName: apiName }
    }),
  
  // ===== INTERMEDIATE CONTEXT (Using UPDATE to avoid duplicates) =====

  withQueryParams: (queryParams: Object) -> buildLogger(loggerObj update {
    case m at .reportingRequest.loggingEntry.message -> do {
        var paramsStr = if (!isEmpty(queryParams)) write(queryParams, "application/java") else ""
        ---
        if (paramsStr != "") m ++ " | Params: " ++ paramsStr else m
    }
  }),

  withPayloadFields: (payload: Any, fieldsInput: String) -> buildLogger(loggerObj update {
    case m at .reportingRequest.loggingEntry.message -> do {
        var fieldList = (fieldsInput splitBy ",") map (trim($) replace "'" with "")
        var flatObj = fieldList reduce (path, acc = {}) -> 
            acc ++ { (path): getNestedValue(payload, path) }
        var dataStr = write(flatObj, "application/java")
        ---
        m ++ " | Data: " ++ dataStr
    }
  }),

  // ===== LOG TYPE METHODS (Using UPDATE for message) =====
  
  asStart: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          update "status" with "START"
          update "message" with "$(loggingEntry.processName) has started" ++ (loggingEntry.message default "")
          update "errorMessage" with ""
      case email at .reportingRequest.email -> email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow update "createSNowTicket" with false update "shortDescription" with "" update "description" with ""
    }),
  
  asSuccess: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          update "status" with "SUCCESS"
          update "message" with "$(loggingEntry.processName) has completed successfully" ++ (loggingEntry.message default "")
          update "errorMessage" with ""
      case email at .reportingRequest.email -> email update "sendEmail" with false
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow update "createSNowTicket" with false update "shortDescription" with "" update "description" with ""
    }),
  
  asError: (errorMessage: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          update "status" with "ERROR"
          update "message" with "$(loggingEntry.processName) has completed with error" ++ (loggingEntry.message default "")
          update "errorMessage" with errorMessage
      case email at .reportingRequest.email -> email update "sendEmail" with true
      case serviceNow at .reportingRequest.serviceNow -> 
        serviceNow 
          update "createSNowTicket" with true
          update "shortDescription" with "Error in $(loggerObj.reportingRequest.loggingEntry.apiName)"
          update "description" with errorMessage
    }),
  
  // ===== OPTIONAL FIELDS =====
  
  withUserId: (userId: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { userId: userId }
    }),
  
  withPayload: (payload: Any) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> loggingEntry ++ { payload: write(payload, "application/json") }
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
