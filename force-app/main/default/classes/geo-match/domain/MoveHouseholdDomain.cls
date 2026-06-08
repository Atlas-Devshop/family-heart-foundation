public with sharing class MoveHouseholdDomain {
    private static final String LOG_PREFIX = '[MoveHouseholdDomain] ';

    public npsp__Address__c buildNewAddress(
        Id householdId, String street, String city,
        String state, String postalCode, String country, String addrType
    ) {
        System.debug(LOG_PREFIX + 'buildNewAddress for household: ' + householdId);
        return new npsp__Address__c(
            npsp__Household_Account__c = householdId,
            npsp__MailingStreet__c     = street,
            npsp__MailingCity__c       = city,
            npsp__MailingState__c      = state,
            npsp__MailingPostalCode__c = postalCode,
            npsp__MailingCountry__c    = country,
            npsp__Address_Type__c      = addrType,
            npsp__Default_Address__c   = true
        );
    }

    public Account buildHouseholdAddressUpdate(
        Id householdId, String street, String city,
        String state, String postalCode, String country
    ) {
        return new Account(
            Id                = householdId,
            BillingStreet     = street,
            BillingCity       = city,
            BillingState      = state,
            BillingPostalCode = postalCode,
            BillingCountry    = country
        );
    }

    public List<npsp__Address__c> clearDefaultFlags(List<npsp__Address__c> addresses) {
        for (npsp__Address__c addr : addresses) {
            addr.npsp__Default_Address__c = false;
        }
        return addresses;
    }

    public List<Contact> syncContactsToAddress(
        List<Contact> members, String street, String city,
        String state, String postalCode, String country
    ) {
        System.debug(LOG_PREFIX + 'syncContactsToAddress: ' + members.size() + ' members');
        for (Contact member : members) {
            member.MailingStreet     = street;
            member.MailingCity       = city;
            member.MailingState      = state;
            member.MailingPostalCode = postalCode;
            member.MailingCountry    = country;
            member.npsp__is_Address_Override__c = false;
        }
        return members;
    }
}
