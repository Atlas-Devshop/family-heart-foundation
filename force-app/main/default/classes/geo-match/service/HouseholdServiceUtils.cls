public with sharing class HouseholdServiceUtils {
    private static final String HH_ACCOUNT_RT = 'HH_Account';
    private static final String LOG_PREFIX     = '[HouseholdServiceUtils] ';

    @TestVisible private static HouseholdGeoMatchSelector selector = new HouseholdGeoMatchSelector();
    @TestVisible private static HouseholdGeoMatchDomain   domain   = new HouseholdGeoMatchDomain();

    public static Id getHhRecordTypeId() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(HH_ACCOUNT_RT)
            .getRecordTypeId();
    }

    public static Id createHousehold(String lastName) {
        System.debug(LOG_PREFIX + 'createHousehold: ' + lastName);
        Account hh = new Account(
            Name         = lastName + ' Household',
            RecordTypeId = getHhRecordTypeId()
        );
        insert hh;
        return hh.Id;
    }

    // Deletes the household if it has no remaining members; renames it otherwise.
    public static void deleteOrRenameHousehold(Id householdId) {
        System.debug(LOG_PREFIX + 'deleteOrRenameHousehold: ' + householdId);
        List<Contact> remaining = selector.getHouseholdMembers(householdId);
        if (remaining.isEmpty()) {
            System.debug(LOG_PREFIX + 'Household empty — deleting: ' + householdId);
            delete new Account(Id = householdId);
        } else {
            System.debug(LOG_PREFIX + 'Household has members — renaming: ' + householdId);
            update new Account(Id = householdId, Name = domain.buildHouseholdName(remaining, null));
        }
    }
}
