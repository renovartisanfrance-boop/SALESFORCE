@IsTest
private class TriggerHandlerTest {

    private static TestHandler handler;

    private static void resetTest() {
        handler = new TestHandler();
        TriggerHandler.clearAllBypasses();
    }

    // -----------------------------------------------------------------
    // Context dispatch
    // -----------------------------------------------------------------

    @IsTest
    static void testBeforeInsert() {
        resetTest();
        handler.setTriggerContext('before insert', true);
        handler.run();
        System.assertEquals('beforeInsert', handler.lastMethodCalled);
    }

    @IsTest
    static void testAfterUpdate() {
        resetTest();
        handler.setTriggerContext('after update', true);
        handler.run();
        System.assertEquals('afterUpdate', handler.lastMethodCalled);
    }

    @IsTest
    static void testRunOutsideTriggerThrows() {
        resetTest();
        Boolean threw = false;
        try {
            handler.run();
        } catch (TriggerHandler.TriggerHandlerException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw when not in trigger context');
    }

    // -----------------------------------------------------------------
    // Bypass
    // -----------------------------------------------------------------

    @IsTest
    static void testBypass() {
        resetTest();
        handler.setTriggerContext('before insert', true);
        TriggerHandler.bypass('TestHandler');
        handler.run();
        System.assertEquals(null, handler.lastMethodCalled,
            'Hook should not run when bypassed');
        System.assert(TriggerHandler.isBypassed('TestHandler'));

        TriggerHandler.clearBypass('TestHandler');
        System.assert(!TriggerHandler.isBypassed('TestHandler'));
    }

    @IsTest
    static void testClearAllBypasses() {
        resetTest();
        TriggerHandler.bypass('A');
        TriggerHandler.bypass('B');
        TriggerHandler.clearAllBypasses();
        System.assert(!TriggerHandler.isBypassed('A'));
        System.assert(!TriggerHandler.isBypassed('B'));
    }

    // -----------------------------------------------------------------
    // Loop count
    // -----------------------------------------------------------------

    @IsTest
    static void testLoopCountExceeded() {
        resetTest();
        handler.setTriggerContext('before insert', true);
        handler.setMaxLoopCount(1);

        handler.run();

        Boolean threw = false;
        try {
            handler.run();
        } catch (TriggerHandler.TriggerHandlerException e) {
            threw = true;
        }
        System.assert(threw, 'Second run should throw — max loop reached');
    }

    @IsTest
    static void testClearMaxLoopCount() {
        resetTest();
        handler.setTriggerContext('before insert', true);
        handler.setMaxLoopCount(1);
        handler.clearMaxLoopCount();
        handler.run();
        handler.run();
        handler.run();
        System.assertEquals('beforeInsert', handler.lastMethodCalled);
    }

    // -----------------------------------------------------------------
    // Stub subclass for testing
    // -----------------------------------------------------------------

    private class TestHandler extends TriggerHandler {
        public String lastMethodCalled;

        protected override void beforeInsert()  { lastMethodCalled = 'beforeInsert'; }
        protected override void beforeUpdate()  { lastMethodCalled = 'beforeUpdate'; }
        protected override void beforeDelete()  { lastMethodCalled = 'beforeDelete'; }
        protected override void afterInsert()   { lastMethodCalled = 'afterInsert'; }
        protected override void afterUpdate()   { lastMethodCalled = 'afterUpdate'; }
        protected override void afterDelete()   { lastMethodCalled = 'afterDelete'; }
        protected override void afterUndelete() { lastMethodCalled = 'afterUndelete'; }
    }
}