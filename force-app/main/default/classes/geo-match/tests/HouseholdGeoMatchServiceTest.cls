@IsTest
private class HouseholdGeoMatchServiceTest {

    // ─── Mock Selector ────────────────────────────────────────────────────────
    private class MockSelector extends HouseholdGeoMatchSelector {
        public Contact contactToReturn;
        public List<Account> householdsToReturn = new List<Account>();
        public Map<Id, List<Contact>> membersByHousehold = new Map<Id, List<Contact>>();

        public override Contact getContactById(Id contactId) {
            return contactToReturn;
        }

        public override List<Account> getHouseholdsWithinRadius(
            Decimal lat, Decimal lng, Decimal thresholdMiles
        ) {
            return householdsToReturn;
        }

        public override List<Contact> getHouseholdMembers(Id householdId) {
            return membersByHousehold.containsKey(householdId)
                ? membersByHousehold.get(householdId)
                : new List<Contact>();
        }
    }

    // ─── Test Data Helpers ────────────────────────────────────────────────────
    private static Account insertAccount(String name) {
        Account acct = new Account(Name = name);
        insert acct;
        return acct;
    }

    private static Contact insertContact(Id accountId, String lastName, Decimal lat, Decimal lng) {
        // AccountId and lat/lng are intentionally omitted from the real insert.
        //
        // Why no AccountId: inserting into a plain Account causes NPSP to auto-create
        //   an HH_Account and move the contact, which changes the contact's AccountId
        //   in the database and makes the mock's accountId references stale/wrong.
        //
        // Why no lat/lng: the geo-match flow fires on insert when coordinates are present,
        //   running real service logic before the mock selector is injected, which can
        //   delete the test accounts the test is about to reference.
        //
        // The mock selector provides the AccountId and coordinates the service actually
        // reads; the accountId parameter here is only used by the caller to build mocks.
        Contact c = new Contact(LastName = lastName);
        insert c;
        return c;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void testMatchFound_contactMovedAndNpspHouseholdDeleted() {
        Account npspAcct    = insertAccount('Smith Household');
        Account matchedAcct = insertAccount('Johnson Household');
        Contact c           = insertContact(npspAcct.Id, 'Smith', 30.0, -97.0);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id
        );
        mock.householdsToReturn = new List<Account>{ matchedAcct };
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>());
        mock.membersByHousehold.put(matchedAcct.Id, new List<Contact>{
            new Contact(Id = c.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Assert.areEqual(
            matchedAcct.Id,
            [SELECT AccountId FROM Contact WHERE Id = :c.Id].AccountId,
            'Contact should be re-homed to the matched household'
        );
        Assert.isTrue(
            [SELECT Id FROM Account WHERE Id = :npspAcct.Id].isEmpty(),
            'Empty NPSP household should be deleted'
        );
        Assert.areEqual(
            'Smith Household',
            [SELECT Name FROM Account WHERE Id = :matchedAcct.Id].Name,
            'Matched household should be renamed'
        );
    }

    @IsTest
    static void testNoMatchFound_contactMovedToNewHousehold() {
        Account npspAcct = insertAccount('Old Name');
        Contact c        = insertContact(npspAcct.Id, 'Smith', 30.0, -97.0);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id,
            MailingStreet = '123 Test St', MailingCity = 'Detroit',
            MailingState = 'MI', MailingPostalCode = '48201', MailingCountry = 'US'
        );
        mock.householdsToReturn = new List<Account>();
        // Old household is empty after the contact moves away
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>());

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Contact updated = [SELECT AccountId FROM Contact WHERE Id = :c.Id];
        Assert.areNotEqual(
            npspAcct.Id,
            updated.AccountId,
            'Contact should be moved off the old household to a new one'
        );
        Assert.isTrue(
            [SELECT Id FROM Account WHERE Id = :npspAcct.Id].isEmpty(),
            'Old empty household should be deleted'
        );
        Account newHH = [
            SELECT Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account WHERE Id = :updated.AccountId
        ];
        Assert.areEqual('Smith Household', newHH.Name, 'New household should be named after the contact');
        Assert.areEqual('123 Test St', newHH.BillingStreet, 'New household billing street should match contact mailing street');
        Assert.areEqual('Detroit', newHH.BillingCity, 'New household billing city should match contact mailing city');
        Assert.areEqual('MI', newHH.BillingState, 'New household billing state should match contact mailing state');
        Assert.areEqual('48201', newHH.BillingPostalCode, 'New household billing postal code should match contact mailing postal code');
        Assert.areEqual('US', newHH.BillingCountry, 'New household billing country should match contact mailing country');
    }

    @IsTest
    static void testNoMatchFound_oldHouseholdHasOtherMembers_notDeleted() {
        Account npspAcct = insertAccount('Smith AND Jones Household');
        Contact c        = insertContact(npspAcct.Id, 'Smith', 30.0, -97.0);
        Contact other    = insertContact(npspAcct.Id, 'Jones', null, null);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id,
            MailingStreet = '456 Oak Ave', MailingCity = 'Detroit',
            MailingState = 'MI', MailingPostalCode = '48202', MailingCountry = 'US'
        );
        mock.householdsToReturn = new List<Account>();
        // Old household still has the other member after Smith moves away
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>{
            new Contact(Id = other.Id, LastName = 'Jones')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Contact updated = [SELECT AccountId FROM Contact WHERE Id = :c.Id];
        Assert.areNotEqual(
            npspAcct.Id,
            updated.AccountId,
            'Contact should be moved to a new household'
        );
        Assert.isFalse(
            [SELECT Id FROM Account WHERE Id = :npspAcct.Id].isEmpty(),
            'Old household with remaining members should NOT be deleted'
        );
        Assert.areEqual(
            'Jones Household',
            [SELECT Name FROM Account WHERE Id = :npspAcct.Id].Name,
            'Old household should be renamed to reflect its remaining member'
        );
        Account newHH = [
            SELECT Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account WHERE Id = :updated.AccountId
        ];
        Assert.areEqual('Smith Household', newHH.Name, 'New household should be named after the moved contact');
        Assert.areEqual('456 Oak Ave', newHH.BillingStreet, 'New household billing street should match contact mailing street');
        Assert.areEqual('Detroit', newHH.BillingCity, 'New household billing city should match contact mailing city');
    }

    @IsTest
    static void testMultipleCandidates_picksClosest() {
        Account npspAcct    = insertAccount('Smith Household');
        Account closestAcct = insertAccount('Johnson Household');
        Account fartherAcct = insertAccount('Williams Household');
        Contact c           = insertContact(npspAcct.Id, 'Smith', 30.0, -97.0);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id
        );
        // Selector returns candidates pre-sorted ASC by distance
        mock.householdsToReturn = new List<Account>{ closestAcct, fartherAcct };
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>());
        mock.membersByHousehold.put(closestAcct.Id, new List<Contact>{
            new Contact(Id = c.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Assert.areEqual(
            closestAcct.Id,
            [SELECT AccountId FROM Contact WHERE Id = :c.Id].AccountId,
            'Contact should be linked to the closest (first) candidate'
        );
    }

    @IsTest
    static void testNpspHouseholdHasOtherMembers_notDeleted() {
        Account npspAcct    = insertAccount('Brown AND Smith Household');
        Account matchedAcct = insertAccount('Johnson Household');
        Contact c           = insertContact(npspAcct.Id, 'Smith', 30.0, -97.0);
        Contact other       = insertContact(npspAcct.Id, 'Brown', null, null);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id
        );
        mock.householdsToReturn = new List<Account>{ matchedAcct };
        // NPSP household still has a remaining member after the move
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>{
            new Contact(Id = other.Id, LastName = 'Brown')
        });
        mock.membersByHousehold.put(matchedAcct.Id, new List<Contact>{
            new Contact(Id = c.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Assert.isFalse(
            [SELECT Id FROM Account WHERE Id = :npspAcct.Id].isEmpty(),
            'NPSP household with remaining members should NOT be deleted'
        );
        Assert.areEqual(
            'Brown Household',
            [SELECT Name FROM Account WHERE Id = :npspAcct.Id].Name,
            'Old household should be renamed to reflect only its remaining members'
        );
    }

    @IsTest
    static void testNullLatLng_exitsEarlyWithNoDml() {
        Account npspAcct = insertAccount('Smith Household');
        Contact c        = insertContact(npspAcct.Id, 'Smith', null, null);

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = null, MailingLongitude = null,
            AccountId = npspAcct.Id
        );

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        // Household name must be unchanged — service should have exited before any DML
        Assert.areEqual(
            'Smith Household',
            [SELECT Name FROM Account WHERE Id = :npspAcct.Id].Name,
            'No DML should occur when coordinates are null'
        );
    }

    @IsTest
    static void testRenameHousehold_multipleMembers() {
        Account acct = insertAccount('Old Name Household');
        Contact c1   = insertContact(acct.Id, 'Johnson', null, null);
        Contact c2   = insertContact(acct.Id, 'Smith', null, null);

        MockSelector mock = new MockSelector();
        mock.membersByHousehold.put(acct.Id, new List<Contact>{
            new Contact(Id = c1.Id, LastName = 'Johnson'),
            new Contact(Id = c2.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.renameHousehold(acct.Id, 'Williams');
        Test.stopTest();

        Assert.areEqual(
            'Johnson AND Smith AND Williams Household',
            [SELECT Name FROM Account WHERE Id = :acct.Id].Name,
            'Household name should combine all last names sorted A-Z'
        );
    }

    @IsTest
    static void testRenameHousehold_excludesContact() {
        Account acct = insertAccount('Johnson AND Smith Household');
        Contact c1   = insertContact(acct.Id, 'Johnson', null, null);
        Contact c2   = insertContact(acct.Id, 'Smith', null, null);

        MockSelector mock = new MockSelector();
        mock.membersByHousehold.put(acct.Id, new List<Contact>{
            new Contact(Id = c1.Id, LastName = 'Johnson'),
            new Contact(Id = c2.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.renameHousehold(acct.Id, null, c2.Id);
        Test.stopTest();

        Assert.areEqual(
            'Johnson Household',
            [SELECT Name FROM Account WHERE Id = :acct.Id].Name,
            'Household name should exclude the deleted contact'
        );
    }

    @IsTest
    static void testMatchFound_contactMailingAddressPreservedAsEntered() {
        Account npspAcct    = insertAccount('Smith Household');
        Account matchedAcct = insertAccount('Johnson Household');
        Contact c = new Contact(
            LastName = 'Smith', AccountId = npspAcct.Id,
            MailingStreet = '1359 Jeff St'
            // lat/lng omitted — flow exits early on null guard; mock provides coords below
        );
        insert c;

        MockSelector mock = new MockSelector();
        mock.contactToReturn = new Contact(
            Id = c.Id, LastName = 'Smith',
            MailingLatitude = 30.0, MailingLongitude = -97.0,
            AccountId = npspAcct.Id
        );
        mock.householdsToReturn = new List<Account>{ matchedAcct };
        mock.membersByHousehold.put(npspAcct.Id, new List<Contact>());
        mock.membersByHousehold.put(matchedAcct.Id, new List<Contact>{
            new Contact(Id = c.Id, LastName = 'Smith')
        });

        HouseholdGeoMatchService.selector = mock;

        Test.startTest();
        HouseholdGeoMatchService.matchAndLinkHousehold(c.Id);
        Test.stopTest();

        Contact updated = [SELECT MailingStreet, AccountId FROM Contact WHERE Id = :c.Id];
        Assert.areEqual(
            matchedAcct.Id,
            updated.AccountId,
            'Contact should be linked to the matched household'
        );
        Assert.areEqual(
            '1359 Jeff St',
            updated.MailingStreet,
            'Contact mailing address should not be overwritten'
        );
    }

    @IsTest
    static void testBuildHouseholdName_deduplication() {
        HouseholdGeoMatchDomain d = new HouseholdGeoMatchDomain();
        List<Contact> members = new List<Contact>{
            new Contact(LastName = 'Smith'),
            new Contact(LastName = 'Johnson'),
            new Contact(LastName = 'Smith')
        };

        String result = d.buildHouseholdName(members, 'Johnson');

        Assert.areEqual('Johnson AND Smith Household', result, 'Duplicate last names should be deduplicated');
    }
}
