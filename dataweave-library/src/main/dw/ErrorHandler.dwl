%dw 2.0

/**
 * ERROR HANDLER MODULE - SIMPLIFIED BUILDER PATTERN
 * 
 * Features:
 * - Type composition using intersection types (&)
 * - Builder pattern with method chaining
 * - Optional type hint to skip pattern matching
 * - Clean syntax: from(error).ofType(RAMLError).getMessage()
 * 
 * Core Methods:
 * - getMessage(): String - Extract error message
 * - raw(): Any - Get raw error object
 * - errorType(): String - Get error type identifier
 */

// ============================================
// BASE TYPE DEFINITION
// ============================================

/**
 * Common error fields shared by all error types
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
// ERROR MESSAGE VARIANTS
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
// COMPOSED ERROR TYPES
// ============================================

/**
 * RAML Error = Base fields + RAML-specific errorMessage
 */
type RAMLError = BaseErrorFields & RAMLErrorMessage

/**
 * SAP Error = Base fields + SAP-specific errorMessage
 */
type SAPError = BaseErrorFields & SAPErrorMessage

/**
 * Salesforce Error = Base fields + SF-specific errorMessage
 */
type SFError = BaseErrorFields & SFErrorMessage

/**
 * Gateway Error = Base fields + Generic errorMessage
 */
type GatewayError = BaseErrorFields & GenericErrorMessage

/**
 * Union type for all errors
 */
type ErrorPayload = RAMLError | SAPError | SFError | GatewayError | Any

// ============================================
// TYPE CONSTANTS (For clean syntax)
// ============================================

var RAMLErrorConstant = "RAMLError"
var SAPErrorConstant = "SAPError"
var GatewayErrorConstant = "GatewayError"
var SFErrorConstant = "SFError"

// ============================================
// CORE EXTRACTION FUNCTIONS
// ============================================

/**
 * Extract message using auto-detection (pattern matching with predefined types)
 */
fun extractMessageAuto(error: Any): String =
  error match {
    case e is RAMLError -> e.errorMessage.error.errorDescription
    case e is SAPError -> e.errorMessage.error.message.error.message.value
    case e is SFError -> e.errorMessage.error.errorMessage default "Salesforce error"
    case e is GatewayError -> e.description default (e.errorMessage.payload default "Gateway error")
    case e if (e.message?) -> e.message
    case e if (e.error?) -> e.error
    case e: String -> e
    case _ -> "Unknown error occurred"
  }

/**
 * Extract message using known type hint (direct access - faster)
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
 * Detect error type using pattern matching
 */
fun detectErrorType(error: Any): String =
  error match {
    case e is RAMLError -> "RAML_ERROR"
    case e is SAPError -> "SAP_ERROR"
    case e is SFError -> "SF_ERROR"
    case e is GatewayError -> "GATEWAY_ERROR"
    case _ -> "UNKNOWN_ERROR"
  }

/**
 * Extract error code (known type)
 */
fun extractCodeByType(error: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> error.errorMessage.error.errorType
    case "SAPError" -> error.errorMessage.error.message.error.code default "SAP_ERROR"
    case "GatewayError" -> error.errorType.identifier default "GATEWAY_ERROR"
    case "SFError" -> error.errorMessage.error.errorCode
    case _ -> "UNKNOWN_ERROR"
  }

/**
 * Extract error details (known type)
 */
fun extractDetailsByType(error: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> error.errorMessage.error.message
    case "SAPError" -> error.errorMessage.error.message.error.details default ""
    case "GatewayError" -> error.detailedDescription default ""
    case "SFError" -> error.errorMessage.error.resultCode default ""
    case _ -> ""
  }

// ============================================
// BUILDER PATTERN - FUNCTIONAL APPROACH
// ============================================

/**
 * Creates builder state object (immutable)
 */
fun createBuilderState(
  errorPayload: Any,
  typeHint: String = "Auto",
  correlationId: String = uuid()
): Object = {
  errorPayload: errorPayload,
  typeHint: typeHint,
  correlationId: correlationId,
  
  // ============================================
  // BUILDER METHODS (return new state)
  // ============================================
  
  /**
   * CHAIN: Set error type hint for performance optimization
   * Use type constants: RAMLErrorConstant, SAPErrorConstant, etc.
   */
  ofType: (hint: String) -> createBuilderState(errorPayload, hint, correlationId),
  
  /**
   * CHAIN: Set correlation ID
   */
  withCorrelationId: (id: String) -> createBuilderState(errorPayload, typeHint, id),
  
  // ============================================
  // TERMINAL METHODS (return final values)
  // ============================================
  
  /**
   * TERMINAL: Extract error message
   */
  getMessage: () -> 
    if (typeHint == "Auto")
      extractMessageAuto(errorPayload)
    else
      extractMessageByType(errorPayload, typeHint),
  
  /**
   * TERMINAL: Get raw error object
   */
  raw: () -> errorPayload,
  
  /**
   * TERMINAL: Get error type identifier
   */
  errorType: () -> 
    if (typeHint == "Auto")
      detectErrorType(errorPayload)
    else
      typeHint match {
        case "RAMLError" -> "RAML_ERROR"
        case "SAPError" -> "SAP_ERROR"
        case "GatewayError" -> "GATEWAY_ERROR"
        case "SFError" -> "SF_ERROR"
        case _ -> detectErrorType(errorPayload)
      }
}

// ============================================
// PUBLIC API - FACTORY FUNCTION
// ============================================

/**
 * Factory function - Entry point for builder pattern
 * Creates new builder state
 */
fun from(error: Any): Object = 
  createBuilderState(error, "Auto", uuid())
