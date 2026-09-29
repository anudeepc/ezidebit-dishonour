// Production, 29 Sep 2026: repair the go-live ordering problem. Relink first (oldest first), then recoveries.
Id relinkJob = Database.executeBatch(new EzidebitDishonourRelinkBatch(), 200);
System.debug('RESULT relink job ' + relinkJob);
