public virtual with sharing class HouseholdGeoMatchSelector {

    private static final String HH_RECORD_TYPE_DEV_NAME = 'HH_Account';
    private static final String LOG_PREFIX = '[HouseholdGeoMatchSelector] ';

    /**
     * Returns Household Accounts within the given radius of a coordinate,
     * ordered nearest-first. Only queries the HH_Account record type.
     *
     * @param lat            Latitude of the origin point
     * @param lng            Longitude of the origin point
     * @param thresholdMiles Maximum distance in miles
     */
    public virtual List<Account> getHouseholdsWithinRadius(
        Decimal lat,
        Decimal lng,
        Decimal thresholdMiles
    ) {
        System.debug(LOG_PREFIX + 'getHouseholdsWithinRadius() called');
        System.debug(LOG_PREFIX + 'Input — lat: ' + lat + ' | lng: ' + lng + ' | thresholdMiles: ' + thresholdMiles);

        Id hhRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(HH_RECORD_TYPE_DEV_NAME)
            .getRecordTypeId();

        System.debug(LOG_PREFIX + 'HH_Account RecordTypeId resolved: ' + hhRecordTypeId);

        List<Account> results = [
            SELECT Id, Name, BillingLatitude, BillingLongitude
            FROM Account
            WHERE RecordTypeId = :hhRecordTypeId
              AND DISTANCE(BillingAddress, GEOLOCATION(:lat, :lng), 'mi') < :thresholdMiles
            ORDER BY DISTANCE(BillingAddress, GEOLOCATION(:lat, :lng), 'mi') ASC
        ];

        System.debug(LOG_PREFIX + 'Households found within radius: ' + results.size());
        for (Account hh : results) {
            System.debug(LOG_PREFIX + 'Candidate — Id: ' + hh.Id + ' | Name: ' + hh.Name
                + ' | BillingLat: ' + hh.BillingLatitude + ' | BillingLng: ' + hh.BillingLongitude);
        }

        return results;
    }

    /**
     * Returns all Contacts that belong to the given household.
     *
     * @param householdId  Id of the household Account
     */
    public virtual List<Contact> getHouseholdMembers(Id householdId) {
        System.debug(LOG_PREFIX + 'getHouseholdMembers() called — householdId: ' + householdId);

        List<Contact> members = [
            SELECT Id, LastName
            FROM Contact
            WHERE AccountId = :householdId
        ];

        System.debug(LOG_PREFIX + 'Members found: ' + members.size());
        for (Contact c : members) {
            System.debug(LOG_PREFIX + 'Member — Id: ' + c.Id + ' | LastName: ' + c.LastName);
        }

        return members;
    }

    /**
     * Returns a single Contact with the fields required by the matching service.
     *
     * @param contactId  Id of the Contact to retrieve
     */
    public virtual Contact getContactById(Id contactId) {
        System.debug(LOG_PREFIX + 'getContactById() called — contactId: ' + contactId);

        Contact c = [
            SELECT Id, LastName, AccountId,
                   MailingLatitude, MailingLongitude,
                   MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        System.debug(LOG_PREFIX + 'Contact retrieved — LastName: ' + c.LastName
            + ' | AccountId: ' + c.AccountId
            + ' | MailingLat: ' + c.MailingLatitude
            + ' | MailingLng: ' + c.MailingLongitude);

        return c;
    }
}
