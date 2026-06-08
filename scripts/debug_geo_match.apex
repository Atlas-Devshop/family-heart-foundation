System.debug('=== START matchAndLinkHousehold ===');
try {
    HouseholdGeoMatchService.matchAndLinkHousehold('003U900000x3hcnIAA');
    System.debug('=== SERVICE COMPLETED ===');
    Contact c = [SELECT Id, AccountId FROM Contact WHERE Id = '003U900000x3hcnIAA'];
    System.debug('=== Contact.AccountId after service: ' + c.AccountId);
} catch (Exception e) {
    System.debug('=== EXCEPTION TYPE: ' + e.getTypeName());
    System.debug('=== EXCEPTION MSG:  ' + e.getMessage());
    System.debug('=== STACK TRACE:    ' + e.getStackTraceString());
}
