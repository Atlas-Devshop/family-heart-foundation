@IsTest
private class HouseholdDuplicateReportServiceTest {

    private static Id hhRecordTypeId() {
        return Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('HH_Account')
            .getRecordTypeId();
    }

    private static Account insertHousehold(
        String name, String street, String city, String state,
        Decimal lat, Decimal lng
    ) {
        Account a = new Account(
            Name             = name,
            RecordTypeId     = hhRecordTypeId(),
            BillingStreet    = street,
            BillingCity      = city,
            BillingState     = state,
            BillingLatitude  = lat,
            BillingLongitude = lng
        );
        insert a;
        return a;
    }

    @IsTest
    static void testGenerateReport_createsCsvWhenDuplicatesExist() {
        // Two households within 0.5 mi (same block)
        insertHousehold('Smith Household',   '100 Main St', 'Austin', 'TX', 30.26715, -97.74306);
        insertHousehold('Johnson Household', '102 Main St', 'Austin', 'TX', 30.26720, -97.74310);
        // One far away — should not pair with either
        insertHousehold('Williams Household', '1 Far Ave', 'Seattle', 'WA', 47.60621, -122.33207);

        Test.startTest();
        HouseholdDuplicateReportService.generateAndSaveReport();
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE Title LIKE 'Duplicate_Households_Report_%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.isFalse(files.isEmpty(), 'A CSV report file should be created when duplicates exist');
        Assert.isTrue(files[0].Title.endsWith('.csv'), 'Saved file should have .csv extension');
    }

    @IsTest
    static void testGenerateReport_noFileWhenNoDuplicates() {
        // All households far apart
        insertHousehold('Smith Household',    '100 Main St', 'Austin',  'TX', 30.26715, -97.74306);
        insertHousehold('Johnson Household',  '1 Far Ave',   'Seattle', 'WA', 47.60621, -122.33207);
        insertHousehold('Williams Household', '5 Ocean Dr',  'Miami',   'FL', 25.77427, -80.19366);

        Test.startTest();
        HouseholdDuplicateReportService.generateAndSaveReport();
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id FROM ContentVersion
            WHERE Title LIKE 'Duplicate_Households_Report_%'
        ];
        Assert.isTrue(files.isEmpty(), 'No report file should be created when no duplicates exist');
    }

    @IsTest
    static void testGenerateReport_householdsWithoutCoordinatesExcluded() {
        // One geocoded, one without coordinates — no pair possible
        insertHousehold('Smith Household', '100 Main St', 'Austin', 'TX', 30.26715, -97.74306);
        Account noCoords = new Account(
            Name         = 'No Coords Household',
            RecordTypeId = hhRecordTypeId()
        );
        insert noCoords;

        Test.startTest();
        HouseholdDuplicateReportService.generateAndSaveReport();
        Test.stopTest();

        List<ContentVersion> files = [
            SELECT Id FROM ContentVersion
            WHERE Title LIKE 'Duplicate_Households_Report_%'
        ];
        Assert.isTrue(files.isEmpty(), 'Households without coordinates should be excluded from comparison');
    }
}
