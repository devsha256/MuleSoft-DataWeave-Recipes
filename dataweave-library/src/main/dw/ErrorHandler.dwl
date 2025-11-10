%dw 2.0

/**
 * Error Handler Module
 * Composable types for Mule/direct payload error extraction.
 */

// ============================================
// Type Definitions
// ============================================

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

type RAMLErrorMessage = {
  error: {
    errorDescription: String,
    errorType: String,
    statusCode: String
  }
}

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

type SFErrorMessage = {
  errorMessage: {
    error: {
      errorCode: String,
      errorMessage?: String,
      resultCode?: String
    }
  }
}

type GenericErrorMessage = {
  errorMessage?: {
    payload?: Any
  }
}

type RAMLError = BaseErrorFields & RAMLErrorMessage
type SAPError = BaseErrorFields & SAPErrorMessage
type SFError = BaseErrorFields & SFErrorMessage
type GatewayError = BaseErrorFields & GenericErrorMessage
type ErrorPayload = RAMLError | SAPError | SFError | GatewayError | Any

// ============================================
// Extraction Functions
// ============================================

/**
 * Extracts error message from error payload using type pattern matching.
 * @param err The error object
 * @return Error message string
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
 * Extracts error message using type hint for performance.
 * Directly accesses the field based on known type.
 * @param err The error object
 * @param typeHint The known error type constant
 * @return Error message string
 */
fun extractMessageByType(err: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> err.error.errorDescription
    case "SAPError" -> err.errorMessage.error.errorMessage.error.message.value
    case "SFError" -> (err.errorMessage.error.errorMessage default "Salesforce error")
    case "GatewayError" -> (err.description default (err.errorMessage.payload as String default "Gateway error"))
    else -> extractMessage(err)
  }

/**
 * Creates builder state for chained error handling.
 */
fun createBuilderState(
  errorPayload: Any,
  typeHint: String = "Auto"
): Object = {
  errorPayload: errorPayload,
  typeHint: typeHint,
  ofType: (hint: String) -> createBuilderState(errorPayload, hint),
  getMessage: () -> 
    if (typeHint == "Auto")
      extractMessage(errorPayload)
    else
      extractMessageByType(errorPayload, typeHint),
  raw: () -> errorPayload
}

/**
 * Entrypoint for Mule error objects.
 * @param error Mule error object
 * @return Builder state
 */
fun fromError(error: Any): Object = createBuilderState(error)

/**
 * Entrypoint for direct payload (wraps as errorMessage).
 * @param payload Error payload
 * @return Builder state
 */
fun fromPayload(payload: Any): Object = createBuilderState({ errorMessage: payload })
