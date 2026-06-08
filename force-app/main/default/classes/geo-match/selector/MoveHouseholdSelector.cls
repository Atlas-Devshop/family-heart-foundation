public with sharing class MoveHouseholdSelector {
    private static final String LOG_PREFIX = '[MoveHouseholdSelector] ';

    public virtual Contact getContactById(Id contactId) {
        System.debug(LOG_PREFIX + 'getContactById: ' + contactId);
        return [SELECT Id, AccountId FROM Contact WHERE Id = :contactId LIMIT 1];
    }

    public virtual List<npsp__Trigger_Handler__c> getAddressHandlers() {
        System.debug(LOG_PREFIX + 'getAddressHandlers');
        return [
            SELECT Id, npsp__Active__c
            FROM npsp__Trigger_Handler__c
            WHERE npsp__Class__c = 'ADDR_Addresses_TDTM'
            LIMIT 1
        ];
    }

    public virtual List<npsp__Address__c> getDefaultAddresses(Id householdId) {
        System.debug(LOG_PREFIX + 'getDefaultAddresses: ' + householdId);
        return [
            SELECT Id, npsp__Default_Address__c
            FROM npsp__Address__c
            WHERE npsp__Household_Account__c = :householdId
            AND npsp__Default_Address__c = true
        ];
    }

    public virtual List<Contact> getHouseholdMembers(Id householdId) {
        System.debug(LOG_PREFIX + 'getHouseholdMembers: ' + householdId);
        return [
            SELECT Id, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE AccountId = :householdId
        ];
    }
}
