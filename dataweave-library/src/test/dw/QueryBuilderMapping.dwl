%dw 2.0
import * from QueryBuilder

output application/json
---
{
  // Build complex OData query with multiple transformations
  oDataQuery: fromQueryParams({
    "\$filter": "status eq 'active'",
    "\$top": "50",
    "\$skip": "10",
    "\$select": ["id", "name", "date"],
    "\$orderby": "date desc",
    "fromDate": "Date(1634215200000)",
    "toDate": "Date(1634301600000)",
    "includeMetadata": "true"
  })
  .withTransform("\$top", (v) -> v as Number)
  .withTransform("\$skip", (v) -> v as Number)
  .withTransform("\$select", (v) -> (v as Array) joinBy ",")
  .withTransform("includeMetadata", (v) -> v as Boolean)
  .get()
}
