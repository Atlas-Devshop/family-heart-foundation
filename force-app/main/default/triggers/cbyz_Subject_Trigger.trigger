trigger cbyz_Subject_Trigger on CTMS__Subject__c (after insert,after update,before delete) {
    
    if(Trigger.isBefore && Trigger.isDelete){
        SubjectTriggerHandler.deletesubjectVisit(Trigger.Old);
    }
    
    if(Trigger.isAfter && Trigger.isInsert){
        SubjectTriggerHandler.insertSubject(Trigger.New);
    }
    
    if(Trigger.isAfter && Trigger.isUpdate){
        System.debug('After update Subject-------------------->');
        if(CheckRecursiveforSubject.runOnceAfter()){
            SubjectTriggerHandler.createOrUpdateSubVisit(Trigger.New,Trigger.Old);
        }
    }
}