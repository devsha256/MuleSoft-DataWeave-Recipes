%dw 2.0

/**
 * ==========================================================
 * ERROR HANDLER MODULE - UNIVERSAL ERROR PARSER
 * ==========================================================
 * @module ErrorHandler
 * * DESCRIPTION:
 * This module provides a single, type-safe API, from(input), to parse 
 * complex error structures, whether they are wrapped in a Mule Error Object 
 * (from an exception) or presented as a raw response payload (from on-error-continue).
 * * CORE MECHANISM:
 * It uses DataWeave's UNION TYPES (|) to define error types that match:
 * 1. The full MuleError object AND the system-specific payload.
 * 2. ONLY the raw system-specific payload.
 * * PUBLIC API (Fluent Builder Methods):
 * - from(data): Entry point.
 * - .getMessage(): Extracts the core human-readable message.
 * - .raw(): Returns the original input.
 * - .ofType("SystemError"): Performance hint for direct extraction.
 * - .isRAMLError(): Type checking for RAML error structure.
 * - .isSAPError(): Type checking for SAP error structure.
 * - .isMuleError(): Type checking for a generic Mule error.
 */

// ============================================
// Type Definitions
// ============================================

/**
 * The base structure for a standard Mule exception object.
 * NOTE: The raw system payload is nested inside the 'errorMessage' field.
 */
type MuleError = {
  description: String,
  detailedDescription: String,
  errorType: {
    namespace: String,
    identifier: String
  }
}

/**
 * RAML Error: Handles both Mule-wrapped error and raw payload.
 */
type RAMLError =
  MuleError & {
    errorMessage: { 
      error: {
        errorDescription: String,
        errorType: String,
        statusCode: String
      }
    }
  }
| {
  error: {
    errorDescription: String,
    errorType: String,
    statusCode: String
  }
}

/**
 * SAP Error: Handles both Mule-wrapped error and raw payload.
 */
type SAPError =
  MuleError & {
    errorMessage: {
      error: {
        errorDescription: String,
        errorType: String,
        statusCode: String,
        errorMessage: {
          error: {
            code: String,
            message: {
              lang: String,
              value: String
            }
          }
        }
      }
    }
  }
| {
  error: {
    errorDescription: String,
    errorType: String,
    statusCode: String,
    errorMessage: { 
      error: {
        code: String,
        message: {
          lang: String,
          value: String
        }
      }
    }
  }
}

/**
 * Union of all recognized error structures.
 */
type ErrorPayload = RAMLError | SAPError | MuleError | Any

// ============================================
// Extraction Functions
// ============================================

/**
 * Extracts error message handling both Mule error and direct payload paths.
 * @param err The error object (Mule Error or raw Payload).
 * @return The core human-readable error message.
 */
fun extractMessage(err: Any): String =
  err match {
    // RAML wrapped or payload (checks if 'errorMessage' exists)
    case e is RAMLError -> 
      if (e.errorMessage?)
        (e.errorMessage.error.errorDescription as String) default "RAML error"
      else
        (e.error.errorDescription as String) default "RAML error"

    // SAP wrapped or payload
    case e is SAPError ->
      if (e.errorMessage?)
        (e.errorMessage.error.errorMessage.error.message.value as String) default "SAP error"
      else
        (e.error.errorMessage.error.message.value as String) default "SAP error"

    // Mule error object
    case e is MuleError -> (e.description as String) default "Mule error"

    // Generic payloads (fallback)
    case e if (e.message?) -> (e.message as String)
    case e if (e.error?) -> (e.error as String)
    case e is String -> e
    else -> "Unknown error occurred"
  }

/**
 * Performance‑optimized extraction with type hint.
 * @param err The error object.
 * @param typeHint A string constant representing a known error type.
 * @return The core human-readable error message.
 */
fun extractMessageByType(err: Any, typeHint: String): String =
  (typeHint match {
    case "RAMLError" -> 
      if (err.errorMessage?)
        (err.errorMessage.error.errorDescription as String) default "RAML error"
      else
        (err.error.errorDescription as String) default "RAML error"

    case "SAPError" ->
      if (err.errorMessage?)
        (err.errorMessage.error.errorMessage.error.message.value as String) default "SAP error"
      else
        (err.error.errorMessage.error.message.value as String) default "SAP error"

    case "MuleError" -> (err.description as String) default "Mule error"

    else -> extractMessage(err)
  }) as String


// ============================================
// Builder Pattern (Fluent API)
// ============================================

/**
 * Creates builder state for chained error handling.
 * @param errorPayload The input object (error or payload).
 * @param typeHint Internal performance hint state.
 * @return An object containing all chainable methods.
 */
fun createBuilderState(
  errorPayload: Any,
  typeHint: String = "Auto"
): Object = {
  errorPayload: errorPayload,
  typeHint: typeHint,
  
  /** * Builder method: Sets error type hint for performance.
   * @param hint String constant: "RAMLError" or "SAPError".
   */
  ofType: (hint: String) -> createBuilderState(errorPayload, hint),
  
  /** * Terminal method: Extracts the message using auto-detection or hint.
   */
  getMessage: () -> 
    if (typeHint == "Auto")
      extractMessage(errorPayload)
    else
      extractMessageByType(errorPayload, typeHint),
  
  /** * Terminal method: Returns the raw input object.
   */
  raw: () -> errorPayload,
  
  /** * Terminal method: Checks if the input is a RAML error structure.
   */
  isRAMLError: () -> (errorPayload is RAMLError),
  
  /** * Terminal method: Checks if the input is an SAP error structure.
   */
  isSAPError: () -> (errorPayload is SAPError),
  
  /** * Terminal method: Checks if the input is a generic Mule error.
   */
  isMuleError: () -> (errorPayload is MuleError)
}

/**
 * Factory method: Single entry point for the module.
 * @param data The input (Mule error object or raw payload).
 * @return A new builder object.
 */
fun from(data: Any): Object = createBuilderState(data)

// ============================================
// EXTENSIBILITY GUIDE
// ============================================

/**
 * GUIDE: HOW TO ADD NEW ERROR TYPES (e.g., WorkDay)
 * * STEP 1: DEFINE THE TYPE STRUCTURES
 * ----------------------------------
 * 1.1 Define the raw payload structure (WorkDayRaw):
 * * type WorkDayRaw = {
 * Fault: {
 * Errors: {
 * Error: Array<{
 * Message: String,
 * Code: String
 * }>
 * }
 * }
 * }
 * * 1.2 Define the Composite Error Type (WorkDayError) using the UNION:
 * * type WorkDayError =
 * MuleError & { errorMessage: WorkDayRaw } // Mule-wrapped
 * | WorkDayRaw // Raw payload
 * * 1.3 Update the main union type (ErrorPayload) by adding WorkDayError.
 * * * STEP 2: UPDATE THE EXTRACTION LOGIC
 * -----------------------------------
 * 2.1 Update fun extractMessage(err: Any) (Auto-Detection):
 * Add a new 'case' to match WorkDayError and safely extract the message:
 * * case e is WorkDayError -> 
 * if (e.errorMessage?)
 * (e.errorMessage.Fault.Errors.Error[0].Message as String) default "WorkDay error"
 * else
 * (e.Fault.Errors.Error[0].Message as String) default "WorkDay error"
 * * 2.2 Update fun extractMessageByType(err: Any, typeHint: String) (Optimized):
 * Add a new 'case' for "WorkDayError" with the same extraction logic.
 * (Remember to define a constant: var WorkDayErrorConstant = "WorkDayError")
 * * * STEP 3: UPDATE THE BUILDER PATTERN
 * ----------------------------------
 * 3.1 Add the new check method to fun createBuilderState:
 * * isWorkDayError: () -> (errorPayload is WorkDayError)
 */
