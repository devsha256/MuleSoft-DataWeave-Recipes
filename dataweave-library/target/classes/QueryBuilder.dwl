%dw 2.0
import * from dw::core::URL

/**
 * QueryBuilder Module - True Builder Pattern Implementation
 * Each function returns an object with chainable methods
 */

/**
 * Initialize builder with query parameters object
 */
fun fromQueryParams(params: Object) = 
  buildWith(params, {}, true)

/**
 * Core builder function - returns object with all chainable methods
 */
fun buildWith(params: Object, transformers: Object, encode: Boolean) = {
  
  // Chainable method: Add transformer for a parameter
  withTransform: (paramName: String, transformer: (Any) -> Any) -> 
    buildWith(params, transformers ++ { (paramName): transformer }, encode),
  
  // Chainable method: Disable encoding
  withoutEncoding: () -> 
    buildWith(params, transformers, false),
  
  // Chainable method: Enable encoding
  withEncoding: () -> 
    buildWith(params, transformers, true),
  
  // Chainable method: Exclude parameters
  exclude: (paramNames: Array<String>) -> 
    buildWith(
      params filterObject (value, key) -> 
        !(paramNames contains (key as String)),
      transformers,
      encode
    ),
  
  // Chainable method: Include only specific parameters
  include: (paramNames: Array<String>) -> 
    buildWith(
      params filterObject (value, key) -> 
        paramNames contains (key as String),
      transformers,
      encode
    ),
  
  // Terminal method: Get query string
  get: () -> do {
    var processedParams = params mapObject (value, key) -> do {
      var keyStr = key as String
      var transformer = transformers[keyStr]
      ---
      (keyStr): if (transformer != null) transformer(value) else value
    }
    
    var queryPairs = processedParams pluck (value, key) -> 
      if (encode)
        "$(encodeURIComponent(key as String))=$(encodeURIComponent(value as String))"
      else
        "$(key)=$(value)"
    ---
    if (isEmpty(queryPairs)) "" 
    else "?" ++ (queryPairs joinBy "&")
  },
  
  // Terminal method: Get as object
  getAsObject: () -> 
    params mapObject (value, key) -> do {
      var keyStr = key as String
      var transformer = transformers[keyStr]
      ---
      (keyStr): if (transformer != null) transformer(value) else value
    },
  
  // Terminal method: Get raw params (for debugging)
  getParams: () -> params,
  
  // Terminal method: Get transformers (for debugging)
  getTransformers: () -> transformers
}
