%dw 2.0
import * from LoggerBuilder
output application/json
---
{
    startLog: newLogger()
                .withProcessId("PROC-001")
                .withProcessName("CustomerSync")
                .withCorrelationId(uuid())
                .asStart()
                .build(),
    successLog: newLogger()
                    .withProcessId("PROC-002")
                    .withProcessName("PaymentProcess")
                    .withCorrelationId(uuid())
                    .withApiName("PaymentAPI")
                    .asSuccess()
                    .withUserId("user123")
                    .build(),
    errorLog: newLogger()
                .withProcessId("PROC-003")
                .withProcessName("OrderProcessing")
                .withCorrelationId(uuid())
                .withApiName("OrderAPI")
                .asError("Database timeout")
                .withUserId("user456")
                .withStackTrace("at line 42...")
                .build()
}
