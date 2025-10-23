%dw 2.0
import * from dw::util::Values

/**
 * ExceptionSObjectBuilder - Optimized implementation
 * Uses update for default fields, ++ for new fields
 */

/**
 * Initialize Exception builder with configuration defaults
 */
fun newException(config: Object) = 
  buildException({
    attributes: {
      "type": "Exception__c"
    },
    // These 5 fields with defaults ALWAYS exist
    Severity__c: config.defaultSeverity,
    Status__c: config.defaultStatus,
    Environment__c: config.defaultEnvironment,
    Retry_Count__c: config.defaultRetryCount,
    Exception_Timestamp__c: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"}
  })

/**
 * Core builder function
 */
fun buildException(exceptionObj: Object) = {
  
  // NEW FIELDS - Use ++ operator (these don't exist yet)
  
  withExceptionCode: (code: String) -> 
    buildException(exceptionObj ++ { Exception_Code__c: code }),
  
  withExceptionMessage: (message: String) -> 
    buildException(exceptionObj ++ { Exception_Message__c: message }),
  
  withExceptionType: (exceptionType: String) -> 
    buildException(exceptionObj ++ { Exception_Type__c: exceptionType }),
  
  withSourceSystem: (source: String) -> 
    buildException(exceptionObj ++ { Source_System__c: source }),
  
  withTransactionId: (transactionId: String) -> 
    buildException(exceptionObj ++ { Transaction_Id__c: transactionId }),
  
  withStackTrace: (stackTrace: String) -> 
    buildException(exceptionObj ++ { Stack_Trace__c: stackTrace }),
  
  withErrorDetails: (details: String) -> 
    buildException(exceptionObj ++ { Error_Details__c: details }),
  
  withRequestPayload: (payload: String) -> 
    buildException(exceptionObj ++ { Request_Payload__c: payload }),
  
  withResponsePayload: (response: String) -> 
    buildException(exceptionObj ++ { Response_Payload__c: response }),
  
  withUserId: (userId: String) -> 
    buildException(exceptionObj ++ { User_Id__c: userId }),
  
  // DEFAULT FIELDS - Use update operator (these always exist)
  
  withSeverity: (severity: String) -> 
    buildException(exceptionObj update "Severity__c" with severity),
  
  withStatus: (status: String) -> 
    buildException(exceptionObj update "Status__c" with status),
  
  withEnvironment: (environment: String) -> 
    buildException(exceptionObj update "Environment__c" with environment),
  
  withRetryCount: (retryCount: Number) -> 
    buildException(exceptionObj update "Retry_Count__c" with retryCount),
  
  withTimestamp: (timestamp: String) -> 
    buildException(exceptionObj update "Exception_Timestamp__c" with timestamp),
  
  // Terminal methods
  
  build: () -> 
    exceptionObj filterObject (value, key) -> value != null,
  
  buildWithNulls: () -> 
    exceptionObj,
  
  getRaw: () -> 
    exceptionObj
}
