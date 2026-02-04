%dw 2.0
import * from dw::util::Values

/**
 * Logger Builder - Enhanced with Java-style serialization for DB readability
 * Initializes errorMessage, shortDescription, description as empty strings
 * Uses update for these fields in asStart/asSuccess/asError
 */

// Helper to resolve nested paths safely (e.g., "customer.name")
var getNestedValue = (obj: Any, path: String) -> (
    (path replace "'" with "") splitBy "." reduce (key, acc = obj) -> 
        if (acc is Object) acc[key] else null
)

/**
 * Initialize builder - sets config defaults
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
        message: ""
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
  
  // ===== MANDATORY FIELDS =====
  
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
  
  // ===== NEW INTERMEDIATE CHAIN FUNCTIONS =====

  /**
   * Appends Query Params as a Java-serialized string to the message
   */
  withQueryParams: (queryParams: Object) -> buildLogger(loggerObj update {
    case entry at .reportingRequest.loggingEntry -> do {
        var paramsStr = if (!isEmpty(queryParams)) write(queryParams, "application/java") else ""
        ---
        entry ++ { 
            message: (entry.message default "") ++ (if (paramsStr != "") " | Params: " ++ paramsStr else "")
        }
    }
  }),

  /**
   * Extracts fields from payload using a property string (e.g. "brand, 'user.id'")
   * Flattens and serializes via application/java for DB readability
   */
  withPayloadFields: (payload: Any, fieldsInput: String) -> buildLogger(loggerObj update {
    case entry at .reportingRequest.loggingEntry -> do {
        var fieldList = (fieldsInput splitBy ",") map (trim($) replace "'" with "")
        var flatObj = fieldList reduce (path, acc = {}) -> 
            acc ++ { (path): getNestedValue(payload, path) }
        var dataStr = write(flatObj, "application/java")
        ---
        entry ++ { 
            message: (entry.message default "") ++ " | Data: " ++ dataStr
        }
    }
  }),

  // ===== LOG TYPE METHODS (Including Flag Overrides) =====
  
  asStart: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "START",
            message: "$(loggingEntry.processName) has started" ++ (loggingEntry.message default "")
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
  
  asSuccess: () -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "SUCCESS",
            message: "$(loggingEntry.processName) has completed successfully" ++ (loggingEntry.message default "")
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
  
  asError: (errorMessage: String) -> 
    buildLogger(loggerObj update {
      case loggingEntry at .reportingRequest.loggingEntry -> 
        loggingEntry 
          ++ { 
            status: "ERROR",
            message: "$(loggingEntry.processName) has completed with error" ++ (loggingEntry.message default "")
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
