// Production: DRY RUN of the history load for September 2026 (active credit contracts). Writes nothing; emails the counts.
Id jobId = Database.executeBatch(new EzidebitDishonourBackfillBatch(Date.newInstance(2026, 9, 1), Date.newInstance(2026, 9, 28), true), 1);
System.debug('RESULT job ' + jobId);
