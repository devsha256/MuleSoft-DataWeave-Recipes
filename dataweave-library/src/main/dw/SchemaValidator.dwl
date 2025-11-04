%dw 2.0

/**
 * FieldValidator Module - Universal Field Validation with Builder Pattern
 * 
 * Comprehensive field validation module supporting query parameters, request bodies, and any object fields.
 * Provides a fluent builder pattern API for fail-fast validation with dynamic error messages.
 */

import * from dw::Runtime

/**
 * Initializes the field validator with a builder pattern interface.
 * 
 * === Parameters
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `data` | `Object` | The object to validate (query parameters, payload, any object, etc.)
 * |===
 * 
 * === Returns
 * 
 * Returns a builder object with two chainable methods:
 * - `withValidation()`: Adds and executes a validation rule (chainable)
 * - `getData()`: Returns the validated object (terminal method)
 * 
 * === Example
 * 
 * [source,DataWeave,linenums]
 * ----
 * %dw 2.0
 * import * from FieldValidator
 * output application/json
 * ---
 * validate(attributes.queryParams)
 *     .withValidation("apiKey", "API Key is required")
 *     .withValidation("userId", "User ID is required")
 *     .getData()
 * ----
 */
fun validate(data: Object) = {
    withValidation: (
        field: String, 
        config: Object | String
    ) -> do {
        // Parse config - if string, treat as description with defaults
        var configObj = if (config is String) 
            { description: config, transform: null, variables: {} }
        else 
            config
        
        var descriptionTemplate = configObj.description
        var transform = configObj.transform default (v) -> !isEmpty(v)
        var variables = configObj.variables default {}
        
        var fieldValue = getNestedValue(data, field)
        var defaultVars = {
            fieldName: field,
            fieldValue: fieldValue,
            fieldValueType: typeOf(fieldValue)
        }
        var allVariables = defaultVars ++ variables
        var finalDescription = interpolateTemplate(descriptionTemplate, allVariables)
        ---
        if (transform(fieldValue))
            validate(data)
        else
            fail(finalDescription)
    },
    getData: () -> data
}

/**
 * Adds a validation rule to the validation chain and executes it immediately.
 * 
 * This function is exposed as a method on the builder object returned by `validate()`.
 * The second parameter `config` can be:
 * 1. A simple String (just the error description)
 * 2. An Object with configuration (most explicit - recommended)
 * 
 * === Parameters (String Form)
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `field` | `String` | Field name or path (supports nested: "user.address.city")
 * | `description` | `String` | Error message if validation fails
 * |===
 * 
 * === Parameters (Object Form - Recommended)
 * 
 * [%header, cols="1,1,3"]
 * |===
 * | Name | Type | Description
 * | `field` | `String` | Field name or path
 * | `config.description` | `String` | Error message template (supports \${variable})
 * | `config.transform` | `(value: Any) -> Boolean` (optional) | Validation function. Default: `(v) -> !isEmpty(v)`
 * | `config.variables` | `Object` (optional) | Variables for message interpolation
 * |===
 * 
 * === Example - Simple String
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(data)
 *     .withValidation("email", "Email is required")
 * ----
 * 
 * === Example - Config Object with Custom Transform
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(data)
 *     .withValidation("email", {
 *         description: "Invalid email format",
 *         transform: (v) -> v matches /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
 *     })
 * ----
 * 
 * === Example - Dynamic Error Message with Variables
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(data)
 *     .withValidation("limit", {
 *         description: "Limit '${fieldValue}' exceeds maximum of ${maxLimit}",
 *         transform: (v) -> (v as Number) <= 100,
 *         variables: { maxLimit: 100 }
 *     })
 * ----
 */
// Note: withValidation is defined inline within the validate() function

/**
 * Returns the validated object (terminal method in the builder chain).
 * 
 * Call this after all validation rules to retrieve the validated data.
 * Works with query parameters, payloads, or any object.
 * 
 * === Returns
 * 
 * Returns the original object that was passed to `validate()`.
 * 
 * === Example - Query Parameters
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(attributes.queryParams)
 *     .withValidation("userId", "User ID is required")
 *     .getData()
 * ----
 * 
 * === Example - Request Payload
 * 
 * [source,DataWeave,linenums]
 * ----
 * validate(payload)
 *     .withValidation("email", "Email is required")
 *     .getData()
 * ----
 * 
 * === Example - Custom Object
 * 
 * [source,DataWeave,linenums]
 * ----
 * var customObject = { name: "John", age: 30 }
 * validate(customObject)
 *     .withValidation("name", "Name is required")
 *     .getData()
 * ----
 */
// Note: getData is defined inline within the validate() function

/**
 * Helper function to get nested values using dot notation.
 * 
 * === Example
 * 
 * [source,DataWeave,linenums]
 * ----
 * getNestedValue({ user: { address: { city: "NYC" } } }, "user.address.city")
 * // Returns: "NYC"
 * ----
 */
fun getNestedValue(obj: Object, path: String) = do {
    var keys = path splitBy "."
    ---
    keys reduce (key, current = obj) -> 
        if (current is Null) null else current[key]
}

/**
 * Helper function to interpolate template strings with variables.
 * 
 * Replaces all \${variableName} placeholders in template with values.
 */
fun interpolateTemplate(template: String, variables: Object) = do {
    var variableKeys = keysOf(variables)
    ---
    variableKeys reduce (key, result = template) ->
        result replace "\${$(key)}" with (variables[key] as String)
}
