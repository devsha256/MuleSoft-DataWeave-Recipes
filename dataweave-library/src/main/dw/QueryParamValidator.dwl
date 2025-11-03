/**
 * QueryParamValidator - Builder Pattern Module for Sequential Query Parameter Validation
 * 
 * This module provides a fluent builder pattern API for validating query parameters
 * in a fail-fast manner. Validations are executed immediately in the order they are
 * chained, and execution stops at the first validation failure.
 * 
 * The module exposes a single entry point function `validate()` which returns a builder
 * object with chainable validation methods.
 * 
 * === Key Features
 * 
 * - *Fail-fast validation*: Stops immediately at the first validation failure
 * - *Builder pattern*: Fluent API with method chaining using dot notation
 * - *Immediate execution*: Each validation executes as soon as it's called
 * - *Custom transform functions*: Flexible lambda-based validation logic
 * - *Descriptive error messages*: Each validation provides a custom error description
 * 
 * === Dependencies
 * 
 * This module requires:
 * - DataWeave 2.0+
 * - dw::Runtime module (for fail() function)
 */
%dw 2.0

import fail from dw::Runtime

/**
 * Initializes the query parameter validator with a builder pattern interface.
 * 
 * Returns a builder object that exposes two methods:
 * - `withValidation()`: Adds and executes a validation rule (chainable)
 * - `getQueryParams()`: Returns the validated query parameters object (terminal)
 * 
 * === Parameters
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `queryParams` | `Object` | The query parameters object to validate (typically from `attributes.queryParams`)
 * |===
 * 
 * === Example
 * 
 * This example validates five query parameters sequentially and fails fast if any validation fails.
 * 
 * ==== Source
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from QueryParamValidator
 * output application/json
 * ---
 * validate(attributes.queryParams)
 *     .withValidation("apiKey", "API Key is required", 
 *         (v) -> v != null and !isEmpty(v))
 *     .withValidation("apiKey", "API Key must be at least 20 characters", 
 *         (v) -> sizeOf(v) >= 20)
 *     .withValidation("userId", "User ID is required", 
 *         (v) -> v != null)
 *     .withValidation("userId", "User ID must be numeric", 
 *         (v) -> v matches /^[0-9]+$/)
 *     .withValidation("limit", "Limit must be between 1 and 100", 
 *         (v) -> v != null and (v as Number) >= 1 and (v as Number) <= 100)
 *     .getQueryParams()
 * ----
 * 
 * ==== Input
 * 
 * [source,JSON,linenums]
 * ----
 * {
 *   "apiKey": "valid-key-12345678901234567890",
 *   "userId": "12345",
 *   "limit": "50"
 * }
 * ----
 * 
 * ==== Output
 * 
 * [source,JSON,linenums]
 * ----
 * {
 *   "apiKey": "valid-key-12345678901234567890",
 *   "userId": "12345",
 *   "limit": "50"
 * }
 * ----
 * 
 * === Example
 * 
 * This example demonstrates fail-fast behavior when a validation fails.
 * 
 * ==== Source
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from QueryParamValidator
 * output application/json
 * ---
 * validate(attributes.queryParams)
 *     .withValidation("apiKey", "API Key is required", (v) -> v != null)
 *     .withValidation("userId", "User ID is required", (v) -> v != null)
 *     .withValidation("limit", "Limit is required", (v) -> v != null)
 *     .getQueryParams()
 * ----
 * 
 * ==== Input
 * 
 * [source,JSON,linenums]
 * ----
 * {
 *   "apiKey": "valid-key",
 *   "userId": null,
 *   "limit": "50"
 * }
 * ----
 * 
 * ==== Output
 * 
 * Throws exception with message: "User ID is required"
 * (The validation for "limit" is never executed due to fail-fast behavior)
 */
fun validate(queryParams: Object) = {
    withValidation: (field: String, description: String, transform: (value: Any) -> Boolean) -> do {
        var fieldValue = queryParams[field]
        ---
        if (transform(fieldValue))
            validate(queryParams)
        else
            fail(description)
    },
    getQueryParams: () -> queryParams
}
