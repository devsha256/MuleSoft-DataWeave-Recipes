%dw 2.0

/**
 * Error Handler Module
 * Composable types for Mule/direct payload error extraction.
 */

// ============================================
// Type Definitions
// ============================================

/**
 * Base Mule Error structure - also used as fallback
 */
type MuleErrorMessage = {
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
 * RAML Error structure
 */
type RAMLErrorMessage = {
  error: {
    errorDescription: String,
    errorType: String,
    statusCode: String
  }
}

/**
 * SAP Error structure
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
 * Salesforce Error structure
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

// Composed Error Types
type MuleError = MuleErrorMessage
type RAMLError = MuleErrorMessage & RAMLErrorMessage
type SAPError = MuleErrorMessage & SAPErrorMessage
type SFError = MuleErrorMessage & SFErrorMessage

type ErrorPayload = RAMLError | SAPError | SFError | MuleError | Any

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
    case e is MuleError -> (e.description default (e.errorMessage.payload as String default "Mule error"))
    case e if (e.message?) -> e.message as String
    case e if (e.error?) -> e.error as String
    case e is String -> e
    else -> "Unknown error occurred"
  }

/**
 * Extracts error message using type hint for performance.
 * @param err The error object
 * @param typeHint The known error type constant
 * @return Error message string
 */
fun extractMessageByType(err: Any, typeHint: String): String =
  typeHint match {
    case "RAMLError" -> err.error.errorDescription
    case "SAPError" -> err.errorMessage.error.errorMessage.error.message.value
    case "SFError" -> (err.errorMessage.error.errorMessage default "Salesforce error")
    case "MuleError" -> (err.description default (err.errorMessage.payload as String default "Mule error"))
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
