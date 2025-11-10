%dw 2.0

/**
 * Error Handler Module
 * 
 * Supports pattern-based extraction of error message and payload from 
 * Mule error objects and plain payloads, using composable type definitions.
 * 
 * - Uses builder pattern with .ofType() and .withCorrelationId()
 * - Supports fromPayload(payload) and fromError(error)
 * - All error matching uses literal type definitions
 */

// ============================================
// Type Definitions
// ============================================

/**
 * @typedef BaseErrorFields
 * Basic structure for Mule error; reusable for composition.
 */
type BaseErrorFields = {
  description: String,
  detailedDescription: String,
  errorType?: {
    namespace?: String,
    identifier?: String
  },
  errorMessage?: {
    payload: Any,
    attributes: Object
  }
}

/**
 * @typedef RAMLErrorMessage
 * Structure for common RAML error format.
 */
type RAMLErrorMessage = {
  error: {
    errorDescription: String,
    errorType: String,
    statusCode: String
  }
}

/**
 * @typedef SAPErrorMessage
 * Structure for SAP error format.
 */
type SAPErrorMessage = {
  errorMessage: {
    error: {
      errorDescription: String,
      errorMessage: {
        error: {
          code: String,
          message: {
            lang: String,
            value: String
          }
        }
      },
      errorType: String,
      statusCode: String
    }
  }
}

/**
 * @typedef SFErrorMessage
 * Structure for Salesforce Apex/API errors.
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
 * @typedef GenericErrorMessage
 * Structure for gateway/fallback errors.
 */
type GenericErrorMessage = {
  errorMessage?: {
    payload?: Any
  }
}

// Composed Error Types
type RAMLError = BaseErrorFields & RAMLErrorMessage
type SAPError = BaseErrorFields & SAPErrorMessage
type SFError = BaseErrorFields & SFErrorMessage
type GatewayError = BaseErrorFields & GenericErrorMessage

/**
 * @typedef ErrorPayload
 * Union type for all supported error types and fallback.
 */
type ErrorPayload = RAMLError | SAPError | SFError | GatewayError | Any

// ============================================
// Extraction Functions
// ============================================

/**
 * Extracts the error message from any error object using literal type pattern matching.
 * Only returns based on known type structures.
 * @param err Any error object
 * @return String error message
 */
fun extractMessage(err: Any): String =
  err match {
    case e is RAMLError -> e.error.errorDescription
    case e is SAPError -> e.errorMessage.error.errorMessage.error.message.value
    case e is SFError -> (e.errorMessage.error.errorMessage default "Salesforce error")
    case e is GatewayError -> (e.description default (e.errorMessage.payload as String default "Gateway error"))
    case e if (e.message?) -> e.message as String
    case e if (e.error?) -> e.error as String
    case e is String -> e
    else -> "Unknown error occurred"
  }

/**
 * Creates a builder state for chained error extraction, given an error object.
 * Allows chaining .ofType(typeLiteral) and .withCorrelationId(id).
 */
fun createBuilderState(
  errorPayload: Any,
  typeHint: Any = null,
  correlationId: String = null
): Object = {
  errorPayload: errorPayload,
  typeHint: typeHint,
  correlationId: correlationId,
  ofType: (hint: Any) -> createBuilderState(errorPayload, hint, correlationId),
  withCorrelationId: (id: String) -> createBuilderState(errorPayload, typeHint, id),
  getMessage: () -> 
    if (typeHint == null)
      extractMessage(errorPayload)
    else
      extractMessage(typeHint),
  raw: () -> errorPayload
}

/**
 * Entrypoint for extracting error details from a Mule error object.
 * @param error Mule error object as provided in MuleSoft flows
 * @return Builder state object with chainable API
 */
fun fromError(error: Any): Object = createBuilderState(error)

/**
 * Entrypoint for extracting error details from a direct payload (not Mule error).
 * Wraps payload as error.errorMessage for correct matching.
 * @param payload The error message payload
 * @return Builder state object with chainable API
 */
fun fromPayload(payload: Any): Object = createBuilderState({ errorMessage: payload })
