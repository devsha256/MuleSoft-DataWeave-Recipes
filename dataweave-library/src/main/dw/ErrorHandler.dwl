%dw 2.0

/**
 * ERROR HANDLER MODULE - TYPE COMPOSITION APPROACH
 * 
 * Solution to the type field override problem using DataWeave's type system
 * 
 * Key Innovation:
 * - Uses intersection types (&) for composition
 * - Provides base type with common fields
 * - Derives specific error types by redefining errorMessage
 * - Maintains full type safety and pattern matching support
 * 
 * Usage:
 *   import * from ErrorHandler
 *   
 *   from(error)
 *     .ofType(RAMLError)
 *     .withCorrelationId(vars.correlationId)
 *     .getMessage()
 */

// ============================================
// BASE TYPE DEFINITION
// ============================================

/**
 * Common error fields shared by all error types
 * This represents the "constant" part of the error structure
 */
type BaseErrorFields = {
  description?: String,
  errorType?: {
    namespace?: String,
    identifier?: String
  },
  detailedDescription?: String
}

// ============================================
// ERROR MESSAGE VARIANTS (The "variable" part)
// ============================================

/**
 * RAML Error Message Structure
 */
type RAMLErrorMessage = {
  errorMessage: {
    error: {
      errorDescription: String,
      errorType: String,
      message: String,
      dateTime?: String
    }
  }
}

/**
 * SAP Error Message Structure
 */
type SAPErrorMessage = {
  errorMessage: {
    error: {
      message: {
        error: {
          message: {
            value: String
          },
          code?: String,
          details?: String
        }
      }
    }
  }
}

/**
 * Salesforce Error Message Structure
 */
type SFErrorMessage = {
  errorMessage: {
    error: {
      errorCode: String,
      errorMessage?: String,
      resultCode?: String
    }
  }
}

/**
 * Generic Error Message Structure (fallback)
 */
type GenericErrorMessage = {
  errorMessage?: {
    payload?: Any
  }
}

// ============================================
// COMPOSED ERROR TYPES (Base + Specific Message)
// ============================================

/**
 * RAML Error = Base fields + RAML-specific errorMessage
 * This achieves the "update .errorMessage" effect
 */
type RAMLErrorType = BaseErrorFields & RAMLErrorMessage

/**
 * SAP Error = Base fields + SAP-specific errorMessage
 */
type SAPErrorType = BaseErrorFields & SAPErrorMessage

/**
 * Salesforce Error = Base fields + SF-specific errorMessage
 */
type SFErrorType = BaseErrorFields & SFErrorMessage

/**
 * Gateway Error = Base fields + Generic errorMessage
 */
type GatewayErrorType = BaseErrorFields & GenericErrorMessage

/**
 * Union type for all errors
 */
type ErrorPayload = RAMLErrorType | SAPErrorType | SFErrorType | GatewayErrorType | Any

// ============================================
// TYPE CONSTANTS (For clean syntax)
// ============================================

var RAMLError = "RAMLError"
var SAPError = "SAPError"
var GatewayError = "GatewayError"
var SFError = "SFError"

// ============================================
// EXTRACTION FUNCTIONS - USING COMPOSED TYPES
// ============================================

/**
 * Extract message using type literal pattern matching
 * Now works perfectly with composed types!
 */
fun extractMessageAuto(error: Any): String =
  error match {
    case e: RAMLErrorType -> e.errorMessage.error.errorDescription
    case e: SAPErrorType -> e.errorMessage.error.message.error.message.value
    case e: SFErrorType -> e.errorMessage.error.errorMessage default "Salesforce error"
    case e: GatewayErrorType -> e.description default (e.errorMessage.payload default "Gateway error")
    case e if (e.message?) -> e.message
    case e if (e.error?) -> e.error
    case e: String -> e
    case _ -> "Unknown error occurred"
  }

/**
 * Extract message with type hint (performance optimized)
 */
fun extractMessageByType(error: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> error.errorMessage.error.errorDescription
    case "SAPError" -> error.errorMessage.error.message.error.message.value
    case "SFError" -> error.errorMessage.error.errorMessage default "Salesforce error"
    case "GatewayError" -> error.description default (error.errorMessage.payload default "Gateway error")
    case _ -> extractMessageAuto(error)
  }

/**
 * Detect error type using composed types
 */
fun detectErrorType(error: Any): String =
  error match {
    case _: RAMLErrorType -> "RAML_ERROR"
    case _: SAPErrorType -> "SAP_ERROR"
    case _: SFErrorType -> "SF_ERROR"
    case _: GatewayErrorType -> "GATEWAY_ERROR"
    case _ -> "UNKNOWN_ERROR"
  }

/**
 * Extract error code
 */
fun extractCodeAuto(error: Any): String =
  error match {
    case e: RAMLErrorType -> e.errorMessage.error.errorType
    case e: SAPErrorType -> e.errorMessage.error.message.error.code default "SAP_ERROR"
    case e: GatewayErrorType -> e.errorType.identifier default "GATEWAY_ERROR"
    case e: SFErrorType -> e.errorMessage.error.errorCode
    case _ -> "UNKNOWN_ERROR"
  }

fun extractCodeByType(error: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> error.errorMessage.error.errorType
    case "SAPError" -> error.errorMessage.error.message.error.code default "SAP_ERROR"
    case "GatewayError" -> error.errorType.identifier default "GATEWAY_ERROR"
    case "SFError" -> error.errorMessage.error.errorCode
    case _ -> extractCodeAuto(error)
  }

/**
 * Extract error details
 */
fun extractDetailsAuto(error: Any): String =
  error match {
    case e: RAMLErrorType -> e.errorMessage.error.message
    case e: SAPErrorType -> e.errorMessage.error.message.error.details default ""
    case e: GatewayErrorType -> e.detailedDescription default ""
    case e: SFErrorType -> e.errorMessage.error.resultCode default ""
    case _ -> ""
  }

fun extractDetailsByType(error: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> error.errorMessage.error.message
    case "SAPError" -> error.errorMessage.error.message.error.details default ""
    case "GatewayError" -> error.detailedDescription default ""
    case "SFError" -> error.errorMessage.error.resultCode default ""
    case _ -> extractDetailsAuto(error)
  }

/**
 * Extract source system
 */
fun extractSourceAuto(error: Any): String =
  error match {
    case _: RAMLErrorType -> "RAML"
    case _: SAPErrorType -> "SAP"
    case _: GatewayErrorType -> "GATEWAY"
    case _: SFErrorType -> "SALESFORCE"
    case _ -> "UNKNOWN"
  }

fun getSourceFromType(typeHint: String): String =
  typeHint match {
    case "RAMLError" -> "RAML"
    case "SAPError" -> "SAP"
    case "GatewayError" -> "GATEWAY"
    case "SFError" -> "SALESFORCE"
    case _ -> "UNKNOWN"
  }

fun getTypeIdentifier(typeHint: String): String =
  typeHint match {
    case "RAMLError" -> "RAML_ERROR"
    case "SAPError" -> "SAP_ERROR"
    case "GatewayError" -> "GATEWAY_ERROR"
    case "SFError" -> "SF_ERROR"
    case _ -> "UNKNOWN_ERROR"
  }

fun mapCodeToHttpStatus(code: String): Number =
  code match {
    case c if (c contains "CONNECTIVITY") -> 503
    case c if (c contains "TIMEOUT") -> 504
    case c if (c contains "VALIDATION") -> 400
    case c if (c contains "UNAUTHORIZED") -> 401
    case c if (c contains "FORBIDDEN") -> 403
    case c if (c contains "NOT_FOUND") -> 404
    case c if (c == "SAP_ERROR") -> 502
    case c if (c contains "SALESFORCE") -> 502
    case _ -> 500
  }

// ============================================
// BUILDER PATTERN
// ============================================

fun createBuilderState(
  errorPayload: Any,
  typeHint: String = "Auto",
  correlationId: String = uuid()
): Object = {
  errorPayload: errorPayload,
  typeHint: typeHint,
  correlationId: correlationId,
  
  ofType: (hint: String) -> createBuilderState(errorPayload, hint, correlationId),
  withCorrelationId: (id: String) -> createBuilderState(errorPayload, typeHint, id),
  
  getMessage: () -> 
    if (typeHint == "Auto")
      extractMessageAuto(errorPayload)
    else
      extractMessageByType(errorPayload, typeHint),
  
  raw: () -> errorPayload,
  
  errorType: () ->
    if (typeHint == "Auto")
      detectErrorType(errorPayload)
    else
      getTypeIdentifier(typeHint),
  
  errorCode: () ->
    if (typeHint == "Auto")
      extractCodeAuto(errorPayload)
    else
      extractCodeByType(errorPayload, typeHint),
  
  details: () ->
    if (typeHint == "Auto")
      extractDetailsAuto(errorPayload)
    else
      extractDetailsByType(errorPayload, typeHint),
  
  source: () ->
    if (typeHint == "Auto")
      extractSourceAuto(errorPayload)
    else
      getSourceFromType(typeHint),
  
  info: () -> do {
    var state = createBuilderState(errorPayload, typeHint, correlationId)
    ---
    {
      errorType: state.errorType(),
      message: state.getMessage(),
      code: state.errorCode(),
      details: state.details(),
      source: state.source(),
      timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"},
      correlationId: correlationId
    }
  },
  
  toHttpResponse: () -> do {
    var state = createBuilderState(errorPayload, typeHint, correlationId)
    var errorInfo = state.info()
    var status = mapCodeToHttpStatus(errorInfo.code)
    ---
    {
      httpStatus: status,
      error: errorInfo
    }
  },
  
  toMinimalResponse: () -> do {
    var state = createBuilderState(errorPayload, typeHint, correlationId)
    ---
    {
      error: {
        correlationId: correlationId,
        message: state.getMessage()
      }
    }
  },
  
  isRetryable: () -> do {
    var state = createBuilderState(errorPayload, typeHint, correlationId)
    var errType = state.errorType()
    ---
    errType match {
      case "GATEWAY_ERROR" -> true
      case "SAP_ERROR" -> true
      case t if (t contains "CONNECTIVITY") -> true
      case t if (t contains "TIMEOUT") -> true
      case _ -> false
    }
  },
  
  retryConfig: () -> do {
    var state = createBuilderState(errorPayload, typeHint, correlationId)
    ---
    if (state.isRetryable())
      {
        shouldRetry: true,
        maxRetries: 3,
        backoffMillis: 2000,
        strategy: "exponential"
      }
    else
      {
        shouldRetry: false,
        maxRetries: 0,
        backoffMillis: 0,
        strategy: "none"
      }
  }
}

fun from(error: Any): Object =
  createBuilderState(error, "Auto", uuid())

// ============================================
// STATIC METHODS
// ============================================

fun getMessage(error: Any): String =
  extractMessageAuto(error)

fun getErrorType(error: Any): String =
  detectErrorType(error)

fun getErrorCode(error: Any): String =
  extractCodeAuto(error)

fun getErrorInfo(error: Any): Object = {
  errorType: detectErrorType(error),
  message: extractMessageAuto(error),
  code: extractCodeAuto(error),
  details: extractDetailsAuto(error),
  source: extractSourceAuto(error),
  timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"},
  correlationId: uuid()
}

fun createHttpResponse(error: Any, correlationId: String = uuid()): Object = do {
  var errorInfo = {
    errorType: detectErrorType(error),
    message: extractMessageAuto(error),
    code: extractCodeAuto(error),
    details: extractDetailsAuto(error),
    source: extractSourceAuto(error),
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"},
    correlationId: correlationId
  }
  var status = mapCodeToHttpStatus(errorInfo.code)
  ---
  {
    httpStatus: status,
    error: errorInfo
  }
}

// ============================================
// TYPE COMPOSITION EXPLANATION
// ============================================

/**
 * HOW TYPE COMPOSITION SOLVES THE PROBLEM:
 * 
 * Instead of trying to "update" a field in an existing type (not possible),
 * we use intersection types (&) to compose types from parts:
 * 
 * 1. BaseErrorFields = Common fields (description, errorType, etc.)
 * 2. RAMLErrorMessage = RAML-specific errorMessage structure
 * 3. RAMLErrorType = BaseErrorFields & RAMLErrorMessage
 * 
 * This achieves the same effect as:
 *   type RAMLError = BaseError update .errorMessage with {...}
 * 
 * Benefits:
 * - Valid DataWeave syntax
 * - Full type safety
 * - Pattern matching works perfectly
 * - Easy to extend with new error types
 * - No runtime overhead
 * - DRY principle maintained
 */

// ============================================
// EXTENSIBILITY - ADDING NEW ERROR TYPES
// ============================================

/**
 * TO ADD NEW ERROR TYPE (e.g., Workday):
 * 
 * Step 1: Define the error message structure
 * type WorkdayErrorMessage = {
 *   errorMessage: {
 *     Fault: {
 *       Errors: {
 *         Error: Array<{
 *           Message: String,
 *           Code: String
 *         }>
 *       }
 *     }
 *   }
 * }
 * 
 * Step 2: Compose with base fields
 * type WorkdayErrorType = BaseErrorFields & WorkdayErrorMessage
 * 
 * Step 3: Add type constant
 * var WorkdayError = "WorkdayError"
 * 
 * Step 4: Add to union type
 * type ErrorPayload = RAMLErrorType | SAPErrorType | ... | WorkdayErrorType | Any
 * 
 * Step 5: Add pattern matching cases
 * - extractMessageAuto: case e: WorkdayErrorType -> e.errorMessage.Fault.Errors.Error[0].Message
 * - extractMessageByType: case "WorkdayError" -> error.errorMessage.Fault.Errors.Error[0].Message
 * - detectErrorType: case _: WorkdayErrorType -> "WORKDAY_ERROR"
 * - And similar for other extraction functions
 * 
 * Done! Use: from(error).ofType(WorkdayError).getMessage()
 */

// ============================================
// USAGE EXAMPLES
// ============================================

/**
 * Example 1: RAML Error
 */
/*
var ramlError = {
  description: "Validation failed",
  errorType: {
    namespace: "API",
    identifier: "VALIDATION_ERROR"
  },
  errorMessage: {
    error: {
      errorDescription: "Invalid customer ID",
      errorType: "VALIDATION_ERROR",
      message: "Customer 12345 does not exist",
      dateTime: "2025-11-07T19:00:00.000Z"
    }
  }
}

from(ramlError)
  .ofType(RAMLError)
  .getMessage()
// Returns: "Invalid customer ID"
*/

/**
 * Example 2: SAP Error
 */
/*
var sapError = {
  description: "SAP system error",
  errorType: {
    namespace: "SAP",
    identifier: "MATERIAL_NOT_FOUND"
  },
  errorMessage: {
    error: {
      message: {
        error: {
          message: {
            value: "Material not found in SAP"
          },
          code: "SAP_MATERIAL_NOT_FOUND",
          details: "Material XYZ123 does not exist in plant 1000"
        }
      }
    }
  }
}

from(sapError)
  .ofType(SAPError)
  .withCorrelationId("abc-123")
  .toHttpResponse()
*/

/**
 * Example 3: Clean syntax usage
 */
/*
%dw 2.0
import * from ErrorHandler
output application/json
---
from(error)
  .ofType(RAMLError)
  .withCorrelationId(vars.correlationId)
  .toHttpResponse()
*/