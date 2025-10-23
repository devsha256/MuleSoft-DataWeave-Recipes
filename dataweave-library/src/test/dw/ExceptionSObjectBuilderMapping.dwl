%dw 2.0
import * from ExceptionSObjectBuilder
output application/json

var config = {
  defaultSeverity: "ERROR",
  defaultStatus: "New",
  defaultEnvironment: "Production",
  defaultRetryCount: 0
}
---
newException(config)
  .withExceptionCode("ERR_001")
  .withExceptionMessage("Database connection failed")
  .withExceptionType("DatabaseException")
  .withSourceSystem("SAP-Integration")
  .withTransactionId("TXN-123456")
  .build()
