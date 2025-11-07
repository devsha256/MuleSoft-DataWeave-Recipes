/*****************************************************
 * ErrorHandler.dwl
 * Functional DataWeave error-handling module
 * --------------------------------------------
 * Features:
 * - Supports type-safe builder syntax: from(error).ofType(SAPError).getMessage()
 * - Auto-detects error type when no type hint provided
 * - Functional, composable builder (no classes)
 * - Easily extensible with new error types
 * - Pattern-matching for optimized, type-safe extraction
 * - Terminal methods: getMessage(), raw(), errorType()
 *****************************************************/

%dw 2.0
output application/dw

////////////////////////////////////
// TYPE DEFINITIONS
////////////////////////////////////

type Error = {
  errorMessage?: {
    payload?: Any
  }
}

type RAMLError extends Error = {
  error?: {
    errorDescription?: String,
    errorType?: String,
    dateTimestamp?: String,
    errorMessage?: String
  }
}

type SAPError extends RAMLError = {
  error?: {
    message?: {
      value?: String
    }
  }
}

type SFError extends RAMLError = {
  errorCode?: String,
  errorMessage?: String
}

type KnownErrorTypes = SAPError | SFError | RAMLError | Error

////////////////////////////////////
// PRIVATE HELPERS
////////////////////////////////////

// Defensive extraction helpers
fun _safe(v) = if (v != null) v else ""
fun _flattenMessage(parts: Array<String>) = (parts filter ((p) -> p != null and p != "")) joinBy " | "

////////////////////////////////////
// MESSAGE EXTRACTORS (pattern-matched)
////////////////////////////////////

fun extractMessage(err: Any): String =
  err match {
    case e is SAPError -> _safe(e.error.message.value)
    case e is SFError -> _flattenMessage([e.errorMessage, e.errorCode])
    case e is RAMLError -> _flattenMessage([
                          e.error.errorMessage,
                          e.error.errorDescription,
                          e.error.errorType
                        ])
    case e is Error -> 
      _safe(e.errorMessage.payload default null) match {
        case p is String -> p
        else -> write(p, "application/json")
      }
    else -> write(err, "application/json")
  }

////////////////////////////////////
// ERROR TYPE DETECTION
////////////////////////////////////

fun detectType(err: Any): String =
  err match {
    case e is SAPError -> "SAPError"
    case e is SFError -> "SFError"
    case e is RAMLError -> "RAMLError"
    case e is Error -> "Error"
    else -> "UnknownError"
  }

////////////////////////////////////
// BUILDER FUNCTIONAL IMPLEMENTATION
////////////////////////////////////

fun from(err: Any) =
  do {
    var state = {
      raw: err,
      hintedType: null
    }

    fun builder(s) = {
      ofType: (t: Type) -> builder(s ++ { hintedType: t }),

      getMessage: () ->
        if (s.hintedType != null)
          do {
            var e = s.raw
            ---
            if (e is s.hintedType)
              extractMessage(e)
            else
              extractMessage(detectAuto(e))
          }
        else
          extractMessage(s.raw),

      raw: () -> s.raw,

      errorType: () ->
        if (s.hintedType != null)
          detectType({} as s.hintedType)
        else
          detectType(s.raw)
    }

    fun detectAuto(e) = 
      e match {
        case x is SAPError -> x
        case x is SFError -> x
        case x is RAMLError -> x
        case x is Error -> x
        else -> e
      }

    ---
    builder(state)
  }

////////////////////////////////////
// MODULE EXPORTS
////////////////////////////////////

---
{
  from: from
}
