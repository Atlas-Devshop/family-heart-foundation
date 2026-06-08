/**
 * HouseholdRenameInvocable
 *
 * Flow-callable entry point for standalone household renaming.
 * Kept separate from HouseholdGeoMatchInvocable so it can be called
 * independently from any Flow or Process that only needs a rename
 * (e.g. after a Contact's last name changes).
 *
 * ADH-9796
 */
public with sharing class HouseholdRenameInvocable {

    public class Request {
        @InvocableVariable(label='Household Id' required=true)
        public String householdId;

        @InvocableVariable(label='New Last Name' required=false)
        public String newLastName;

        @InvocableVariable(label='Contact Id To Exclude' required=false)
        public String contactIdToExclude;
    }

    @InvocableMethod(
        label='Rename Household'
        description='Renames a household account using the last names of all current members combined with the provided surname.'
        category='Household'
    )
    public static void rename(List<Request> requests) {
        for (Request req : requests) {
            HouseholdGeoMatchService.renameHousehold(
                (Id) req.householdId,
                req.newLastName,
                (Id) req.contactIdToExclude
            );
        }
    }
}
