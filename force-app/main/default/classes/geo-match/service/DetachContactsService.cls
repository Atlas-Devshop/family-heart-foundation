public with sharing class DetachContactsService {
    @TestVisible private static DetachContactsSelector selector = new DetachContactsSelector();
    @TestVisible private static DetachContactsDomain   domain   = new DetachContactsDomain();

    private static final String LOG_PREFIX = '[DetachContactsService] ';

    public static void detach(List<Id> contactIds) {
        System.debug(LOG_PREFIX + 'detach: ' + contactIds);
        if (contactIds == null || contactIds.isEmpty()) return;

        List<Contact> contacts = selector.getContactsByIds(contactIds);
        if (contacts.isEmpty()) return;

        Id hhRecordTypeId = HouseholdServiceUtils.getHhRecordTypeId();

        Set<Id> oldHouseholdIds = new Set<Id>();
        for (Contact c : contacts) {
            if (c.AccountId != null) oldHouseholdIds.add(c.AccountId);
        }

        List<Account> newHouseholds = domain.buildNewHouseholds(contacts, hhRecordTypeId);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.duplicateRuleHeader.allowSave = true;
        Database.insert(newHouseholds, dml);

        contacts = domain.assignContactsToHouseholds(contacts, newHouseholds);
        Database.update(contacts, dml);

        List<Account> householdsToUpdate = domain.syncHouseholdAddresses(newHouseholds, contacts);
        Database.update(householdsToUpdate, dml);

        List<Contact> remaining = selector.getRemainingContactsByHouseholdIds(oldHouseholdIds);
        List<Account> toDelete = domain.findEmptyHouseholds(oldHouseholdIds, remaining);
        if (!toDelete.isEmpty()) delete toDelete;
    }
}
