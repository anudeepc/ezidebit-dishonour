// Production: history load for September 2026 (active credit contracts). Fixes the go-live gap: the originals of
// retries from before 19 Sep are recorded, and each insert relinks its retry and moves the first-default flag.
Id jobId = Database.executeBatch(new EzidebitDishonourBackfillBatch(Date.newInstance(2026, 9, 1), Date.newInstance(2026, 9, 28), false), 1);
System.debug('RESULT job ' + jobId);
