@IsTest
private class HouseholdGeoMatchSelectorTest {

    private static Id hhRecordTypeId() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('HH_Account')
            .getRecordTypeId();
    }

    private static Account insertHousehold(String name, Decimal lat, Decimal lng) {
        Account a = new Account(
            Name             = name,
            RecordTypeId     = hhRecordTypeId(),
            BillingStreet    = '100 Main St',
            BillingCity      = 'Detroit',
            BillingState     = 'MI',
            BillingLatitude  = lat,
            BillingLongitude = lng
        );
        insert a;
        return a;
    }

    // ─── getHouseholdsWithinRadius ────────────────────────────────────────────

    @IsTest
    static void testGetHouseholdsWithinRadius_findsNearbyHousehold() {
        Account nearby = insertHousehold('Nearby Household', 42.3314, -83.0458);

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        List<Account> results = sel.getHouseholdsWithinRadius(42.3314, -83.0458, 0.5);
        Test.stopTest();

        Assert.isTrue(results.size() >= 1, 'Should return the nearby household');
        Assert.areEqual(nearby.Id, results[0].Id, 'Should return the correct household');
    }

    @IsTest
    static void testGetHouseholdsWithinRadius_excludesFarHousehold() {
        insertHousehold('Far Household', 34.0522, -118.2437); // Los Angeles

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        List<Account> results = sel.getHouseholdsWithinRadius(42.3314, -83.0458, 0.5);
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Should not return a household far outside the radius');
    }

    @IsTest
    static void testGetHouseholdsWithinRadius_returnsNearestFirst() {
        Account closer  = insertHousehold('Closer Household',  42.3314, -83.0458);
        Account farther = insertHousehold('Farther Household', 42.3370, -83.0500);

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        List<Account> results = sel.getHouseholdsWithinRadius(42.3314, -83.0458, 0.5);
        Test.stopTest();

        Assert.isTrue(results.size() >= 2, 'Should return both nearby households');
        Assert.areEqual(closer.Id, results[0].Id, 'Closest household should be first');
    }

    // ─── getHouseholdMembers ─────────────────────────────────────────────────

    @IsTest
    static void testGetHouseholdMembers_returnsContacts() {
        Account acct = insertHousehold('Smith Household', 42.3314, -83.0458);
        Contact c1   = new Contact(LastName = 'Smith', AccountId = acct.Id);
        Contact c2   = new Contact(LastName = 'Jones', AccountId = acct.Id);
        insert new List<Contact>{ c1, c2 };

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        List<Contact> members = sel.getHouseholdMembers(acct.Id);
        Test.stopTest();

        Assert.areEqual(2, members.size(), 'Should return all household members');
    }

    @IsTest
    static void testGetHouseholdMembers_emptyHousehold() {
        Account acct = insertHousehold('Empty Household', 42.3314, -83.0458);

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        List<Contact> members = sel.getHouseholdMembers(acct.Id);
        Test.stopTest();

        Assert.isTrue(members.isEmpty(), 'Should return empty list for a household with no members');
    }

    // ─── getContactById ──────────────────────────────────────────────────────

    @IsTest
    static void testGetContactById_returnsCorrectFields() {
        Account acct = insertHousehold('Test Household', 42.3314, -83.0458);
        Contact c = new Contact(
            LastName         = 'Rivera',
            AccountId        = acct.Id,
            MailingLatitude  = 42.3314,
            MailingLongitude = -83.0458
        );
        insert c;

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        Contact result = sel.getContactById(c.Id);
        Test.stopTest();

        Assert.areEqual('Rivera',   result.LastName,         'LastName should match');
        Assert.areEqual(42.3314,    result.MailingLatitude,  'MailingLatitude should match');
        Assert.areEqual(-83.0458,   result.MailingLongitude, 'MailingLongitude should match');
        Assert.areEqual(acct.Id,    result.AccountId,        'AccountId should match');
    }

    @IsTest
    static void testGetContactById_overrideFieldReturned() {
        Account acct = insertHousehold('Test Household', 42.3314, -83.0458);
        Contact c = new Contact(
            LastName                     = 'Nguyen',
            AccountId                    = acct.Id,
            npsp__is_Address_Override__c = true
        );
        insert c;

        HouseholdGeoMatchSelector sel = new HouseholdGeoMatchSelector();

        Test.startTest();
        Contact result = sel.getContactById(c.Id);
        Test.stopTest();

        Assert.isTrue(result.npsp__is_Address_Override__c, 'Override flag should be returned');
    }
}
