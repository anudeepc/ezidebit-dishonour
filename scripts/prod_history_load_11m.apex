Id j = Database.executeBatch(new EzidebitDishonourBackfillBatch(Date.newInstance(2025, 10, 1), Date.newInstance(2026, 8, 31), false), 1); System.debug('RESULT load ' + j);
