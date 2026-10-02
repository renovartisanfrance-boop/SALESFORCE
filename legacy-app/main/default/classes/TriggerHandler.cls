/**
 * Base class for all trigger handlers.
 *
 * Usage:
 *   1. Create a subclass per SObject (e.g. AccountTriggerHandler).
 *   2. Override only the hooks you need (beforeInsert, afterUpdate, ...).
 *   3. In the trigger, call: new AccountTriggerHandler().run();
 *
 * Features:
 *   - Single entry point (run) that dispatches to the right hook.
 *   - Bypass mechanism: TriggerHandler.bypass('AccountTriggerHandler');
 *   - Recursion guard via setMaxLoopCount.
 */
public virtual class TriggerHandler {

    @TestVisible
    private static Set<String> bypassedHandlers = new Set<String>();

    @TestVisible
    private static Map<String, LoopCount> loopCountMap = new Map<String, LoopCount>();

    @TestVisible
    private TriggerContext context;

    @TestVisible
    private Boolean isTriggerExecuting;

    public TriggerHandler() {
        this.setTriggerContext();
    }

    // ---------------------------------------------------------------------
    // Public API
    // ---------------------------------------------------------------------

    public void run() {
        if (!validateRun()) {
            return;
        }

        addToLoopCount();

        switch on this.context {
            when BEFORE_INSERT  { this.beforeInsert(); }
            when BEFORE_UPDATE  { this.beforeUpdate(); }
            when BEFORE_DELETE  { this.beforeDelete(); }
            when AFTER_INSERT   { this.afterInsert(); }
            when AFTER_UPDATE   { this.afterUpdate(); }
            when AFTER_DELETE   { this.afterDelete(); }
            when AFTER_UNDELETE { this.afterUndelete(); }
        }
    }

    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if (!loopCountMap.containsKey(handlerName)) {
            loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            loopCountMap.get(handlerName).setMax(max);
        }
    }

    public void clearMaxLoopCount() {
        this.setMaxLoopCount(-1);
    }

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }

    // ---------------------------------------------------------------------
    // Hooks — override in subclasses
    // ---------------------------------------------------------------------

    protected virtual void beforeInsert()  {}
    protected virtual void beforeUpdate()  {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterInsert()   {}
    protected virtual void afterUpdate()   {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    // ---------------------------------------------------------------------
    // Internals
    // ---------------------------------------------------------------------

    @TestVisible
    private void setTriggerContext() {
        this.setTriggerContext(null, false);
    }

    @TestVisible
    private void setTriggerContext(String ctx, Boolean testMode) {
        if (!Trigger.isExecuting && !testMode) {
            this.isTriggerExecuting = false;
            return;
        }
        this.isTriggerExecuting = true;

        if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
            (ctx != null && ctx == 'before insert')) {
            this.context = TriggerContext.BEFORE_INSERT;
        } else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
                   (ctx != null && ctx == 'before update')) {
            this.context = TriggerContext.BEFORE_UPDATE;
        } else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
                   (ctx != null && ctx == 'before delete')) {
            this.context = TriggerContext.BEFORE_DELETE;
        } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
                   (ctx != null && ctx == 'after insert')) {
            this.context = TriggerContext.AFTER_INSERT;
        } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
                   (ctx != null && ctx == 'after update')) {
            this.context = TriggerContext.AFTER_UPDATE;
        } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
                   (ctx != null && ctx == 'after delete')) {
            this.context = TriggerContext.AFTER_DELETE;
        } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
                   (ctx != null && ctx == 'after undelete')) {
            this.context = TriggerContext.AFTER_UNDELETE;
        }
    }

    @TestVisible
    private Boolean validateRun() {
        if (!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException(
                'Trigger handler called outside of Trigger execution');
        }
        if (bypassedHandlers.contains(getHandlerName())) {
            return false;
        }
        return true;
    }

    @TestVisible
    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if (loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = loopCountMap.get(handlerName).increment();
            if (exceeded) {
                Integer max = loopCountMap.get(handlerName).max;
                throw new TriggerHandlerException(
                    'Maximum loop count of ' + String.valueOf(max)
                    + ' reached in ' + handlerName);
            }
        }
    }

    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }

    // ---------------------------------------------------------------------
    // Inner types
    // ---------------------------------------------------------------------

    @TestVisible
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, AFTER_UNDELETE
    }

    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;

        public LoopCount() {
            this.max = 5;
            this.count = 0;
        }

        public LoopCount(Integer max) {
            this.max = max;
            this.count = 0;
        }

        public Boolean increment() {
            this.count++;
            return this.exceeded();
        }

        public Boolean exceeded() {
            return this.max >= 0 && this.count > this.max;
        }

        public Integer getMax()   { return this.max; }
        public Integer getCount() { return this.count; }
        public void setMax(Integer max) { this.max = max; }
    }

    public class TriggerHandlerException extends Exception {}
}