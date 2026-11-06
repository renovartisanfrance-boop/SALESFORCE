trigger LeadTrigger on Lead (before insert, before update, after insert, after update, after delete, after undelete) {
    new LeadTriggerHandler().run();
}