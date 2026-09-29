// Production: after the September history load, close failures that later payments recovered (live and history),
// then link the $16.50 fees already charged. Active credit contracts only.
Id r = Database.executeBatch(new EzidebitDishonourRecoveryBatch(true), 200);
System.debug('RESULT recovery ' + r);
