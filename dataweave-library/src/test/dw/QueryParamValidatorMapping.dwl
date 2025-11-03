%dw 2.0
import * from QueryParamValidator
output application/json

---
validate({
    apiKey: "valid-api-key-12345678901234",
    userId: null,  // This will cause failure
    limit: "invalid",  // This won't be checked
    startDate: null,  // This won't be checked
    endDate: null  // This won't be checked
})
.withValidation("userId", "User ID can not be Null!", (v) -> !isEmpty(v))
.getQueryParams()