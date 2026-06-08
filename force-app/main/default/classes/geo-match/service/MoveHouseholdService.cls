public with sharing class MoveHouseholdService {
    @TestVisible private static MoveHouseholdSelector selector = new MoveHouseholdSelector();
    @TestVisible private static MoveHouseholdDomain   domain   = new MoveHouseholdDomain();

    private static final String LOG_PREFIX = '[MoveHouseholdService] ';

    public static void move(
        Id contactId, String street, String city,
        String state, String postalCode, String country, String addressType
    ) {
        System.debug(LOG_PREFIX + 'move: contactId=' + contactId);
        String addrType = String.isBlank(addressType) ? 'Home' : addressType;

        Contact con = selector.getContactById(contactId);
        Id householdId = con.AccountId;
        System.debug(LOG_PREFIX + 'householdId=' + householdId);

        List<npsp__Trigger_Handler__c> handlers = selector.getAddressHandlers();

        try {
            if (!handlers.isEmpty()) {
                handlers[0].npsp__Active__c = false;
                update handlers;
            }

            List<npsp__Address__c> existingDefaults = selector.getDefaultAddresses(householdId);
            if (!existingDefaults.isEmpty()) {
                update domain.clearDefaultFlags(existingDefaults);
            }

            insert domain.buildNewAddress(householdId, street, city, state, postalCode, country, addrType);
            update domain.buildHouseholdAddressUpdate(householdId, street, city, state, postalCode, country);

            List<Contact> members = selector.getHouseholdMembers(householdId);
            if (!members.isEmpty()) {
                update domain.syncContactsToAddress(members, street, city, state, postalCode, country);
            }

        } finally {
            if (!handlers.isEmpty()) {
                handlers[0].npsp__Active__c = true;
                update handlers;
            }
        }
    }
}
