%dw 2.0

/**
 * QueryParamValidator Module - Builder Pattern for Sequential Query Parameter Validation
 * 
 * This module provides a fluent builder pattern API for validating query parameters
 * in a fail-fast manner with support for dynamic error descriptions.
 * 
 * Validations are executed immediately in the order they are chained, and execution 
 * stops at the first validation failure.
 * 
 * === Key Features
 * 
 * - *Fail-fast validation*: Stops immediately at the first validation failure
 * - *Builder pattern*: Fluent API with method chaining using dot notation
 * - *Immediate execution*: Each validation executes as soon as it's called
 * - *Dynamic error messages*: Template strings with variable injection using ${variable}
 * - *Custom transform functions*: Flexible lambda-based validation logic
 * 
 * === Dependencies
 * 
 * This module requires:
 * - DataWeave 2.0+
 * - dw::Runtime module (for fail() function)
 * 
 * @author Your Name
 * @version 2.0.0
 * @since 2025-11-04
 */

import * from dw::Runtime

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
 * === Example - Basic Usage
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from QueryParamValidator
 * output application/json
 * ---
 * validate(attributes.queryParams)
 *     .withValidation("apiKey", "API Key is required", (v) -> v != null and !isEmpty(v))
 *     .withValidation("userId", "User ID must be numeric", (v) -> v matches /^[0-9]+$/)
 *     .getQueryParams()
 * ----
 * 
 * === Example - Dynamic Error Messages
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from QueryParamValidator
 * output application/json
 * ---
 * validate(attributes.queryParams)
 *     .withValidation("limit", "Limit must be between 1 and ${maxLimit}", 
 *         (v) -> (v as Number) <= 100,
 *         { maxLimit: 100 })
 *     .withValidation("apiKey", "API Key '${apiKey}' is invalid format", 
 *         (v) -> v matches /^[A-Z0-9]{20}$/,
 *         { apiKey: attributes.queryParams.apiKey })
 *     .getQueryParams()
 * ----
 * 
 * === Template Variables
 * 
 * Use `${variableName}` syntax in error descriptions to inject dynamic values.
 * The last parameter (optional) accepts an Object with key-value pairs for variable substitution.
 * 
 * Common template variables:
 * - `${fieldName}`: The name of the field being validated
 * - `${fieldValue}`: The actual value of the field
 * - `${maxLength}`: Maximum allowed length
 * - `${minLength}`: Minimum allowed length
 * - `${allowedValues}`: List of allowed values
 */
fun validate(queryParams: Object) = {
    withValidation: (field: String, descriptionTemplate: String, transform: (value: Any) -> Boolean, variables: Object = {}) -> do {
        var fieldValue = queryParams[field]
        var defaultVars = {
            fieldName: field,
            fieldValue: fieldValue,
            fieldValueType: typeOf(fieldValue)
        }
        var allVariables = defaultVars ++ variables
        var finalDescription = interpolateTemplate(descriptionTemplate, allVariables)
        ---
        if (transform(fieldValue))
            validate(queryParams)
        else
            fail(finalDescription)
    },
    getQueryParams: () -> queryParams
}

/**
 * Helper function to interpolate template strings with variables
 * Replaces ${variableName} with corresponding values from the variables object
 * 
 * === Parameters
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `template` | `String` | The template string containing ${variable} placeholders
 * | `variables` | `Object` | Object containing variable names and their values
 * |===
 * 
 * === Returns
 * 
 * Returns the interpolated string with all variables replaced
 * 
 * === Example
 * 
 * [source,DataWeave,linenums]
 * ----
 * interpolateTemplate("Field ${fieldName} with value ${fieldValue} is invalid", 
 *     { fieldName: "email", fieldValue: "test@example.com" })
 * // Returns: "Field email with value test@example.com is invalid"
 * ----
 */
fun interpolateTemplate(template: String, variables: Object) = do {
    var variableKeys = keysOf(variables)
    ---
    variableKeys reduce (key, result = template) ->
        result replace /\$\{$(key)\}/ with (variables[key] as String)
}

/**
 * Adds a validation rule to the validation chain and executes it immediately.
 * 
 * This function is exposed as a method on the builder object returned by `validate()`.
 * It validates the specified field using the provided transform function and either
 * continues the chain (if validation passes) or throws an error (if validation fails).
 * 
 * === Parameters
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `field` | `String` | The name of the query parameter field to validate
 * | `descriptionTemplate` | `String` | The error message template with optional ${variable} placeholders
 * | `transform` | `(value: Any) -> Boolean` | A lambda function that receives the field value and returns `true` if valid, `false` otherwise
 * | `variables` | `Object` (optional) | Object containing key-value pairs for template variable substitution
 * |===
 * 
 * === Returns
 * 
 * Returns the same builder object to enable method chaining, or throws an exception
 * if the validation fails.
 * 
 * === Example - Static Error Message
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(attributes.queryParams)
 *     .withValidation("email", "Email is required", (v) -> v != null)
 * ----
 * 
 * === Example - Dynamic Error Message with Field Value
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(attributes.queryParams)
 *     .withValidation("apiKey", "Invalid API Key format: '${fieldValue}'", 
 *         (v) -> v matches /^[A-Z0-9]{20}$/)
 * ----
 * 
 * === Example - Dynamic Error Message with Custom Variables
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(attributes.queryParams)
 *     .withValidation("limit", "Limit '${fieldValue}' exceeds maximum of ${maxLimit}", 
 *         (v) -> (v as Number) <= 100,
 *         { maxLimit: 100 })
 * ----
 */
// Note: withValidation is defined inline within the validate() function
// and is automatically available as a method on the returned builder object

/**
 * Returns the validated query parameters object.
 * 
 * This is the terminal function in the builder chain. It should be called after
 * all validation rules have been added via `withValidation()`. If all validations
 * passed, this function returns the original query parameters object.
 * 
 * === Returns
 * 
 * Returns the original query parameters object that was passed to `validate()`.
 * 
 * === Example
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from QueryParamValidator
 * output application/json
 * ---
 * {
 *     validatedParams: validate(attributes.queryParams)
 *         .withValidation("apiKey", "API Key is required", (v) -> v != null)
 *         .getQueryParams()
 * }
 * ----
 */
// Note: getQueryParams is defined inline within the validate() function
// and is automatically available as a method on the returned builder object
