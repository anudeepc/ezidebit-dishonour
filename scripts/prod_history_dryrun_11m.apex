Id j = Database.executeBatch(new EzidebitDishonourBackfillBatch(Date.newInstance(2025, 10, 1), Date.newInstance(2026, 8, 31), true), 1); System.debug('RESULT dry ' + j);
