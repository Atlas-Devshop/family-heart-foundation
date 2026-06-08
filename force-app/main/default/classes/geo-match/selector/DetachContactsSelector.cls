public with sharing class DetachContactsSelector {
    private static final String LOG_PREFIX = '[DetachContactsSelector] ';

    public virtual List<Contact> getContactsByIds(List<Id> contactIds) {
        System.debug(LOG_PREFIX + 'getContactsByIds: ' + contactIds);
        return [
            SELECT Id, LastName, AccountId,
                   MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE Id IN :contactIds
        ];
    }

    public virtual List<Contact> getRemainingContactsByHouseholdIds(Set<Id> householdIds) {
        System.debug(LOG_PREFIX + 'getRemainingContactsByHouseholdIds: ' + householdIds);
        return [SELECT AccountId FROM Contact WHERE AccountId IN :householdIds];
    }

}
