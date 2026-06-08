public with sharing class DetachContactsDomain {
    private static final String LOG_PREFIX = '[DetachContactsDomain] ';

    public List<Account> buildNewHouseholds(List<Contact> contacts, Id hhRecordTypeId) {
        System.debug(LOG_PREFIX + 'buildNewHouseholds: ' + contacts.size());
        List<Account> households = new List<Account>();
        for (Contact c : contacts) {
            households.add(new Account(
                Name         = c.LastName + ' Household',
                RecordTypeId = hhRecordTypeId
            ));
        }
        return households;
    }

    public List<Contact> assignContactsToHouseholds(List<Contact> contacts, List<Account> newHouseholds) {
        System.debug(LOG_PREFIX + 'assignContactsToHouseholds');
        for (Integer i = 0; i < contacts.size(); i++) {
            contacts[i].AccountId = newHouseholds[i].Id;
        }
        return contacts;
    }

    public List<Account> syncHouseholdAddresses(List<Account> newHouseholds, List<Contact> contacts) {
        System.debug(LOG_PREFIX + 'syncHouseholdAddresses');
        List<Account> updates = new List<Account>();
        for (Integer i = 0; i < contacts.size(); i++) {
            updates.add(new Account(
                Id                = newHouseholds[i].Id,
                BillingStreet     = contacts[i].MailingStreet,
                BillingCity       = contacts[i].MailingCity,
                BillingState      = contacts[i].MailingState,
                BillingPostalCode = contacts[i].MailingPostalCode,
                BillingCountry    = contacts[i].MailingCountry
            ));
        }
        return updates;
    }

    public List<Account> findEmptyHouseholds(Set<Id> oldHouseholdIds, List<Contact> remainingContacts) {
        System.debug(LOG_PREFIX + 'findEmptyHouseholds');
        Map<Id, Integer> memberCount = new Map<Id, Integer>();
        for (Id hhId : oldHouseholdIds) memberCount.put(hhId, 0);
        for (Contact c : remainingContacts) {
            memberCount.put(c.AccountId, memberCount.get(c.AccountId) + 1);
        }
        List<Account> toDelete = new List<Account>();
        for (Id hhId : memberCount.keySet()) {
            if (memberCount.get(hhId) == 0) toDelete.add(new Account(Id = hhId));
        }
        return toDelete;
    }
}
