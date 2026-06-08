public with sharing class HouseholdGeoMatchInvocable {

    public class Request {
        @InvocableVariable(label='Contact Id' required=true)
        public String contactId;
    }

    @InvocableMethod(
        label='Match and Link Household by Geolocation'
        description='Finds the nearest existing household within the configured radius and links the contact to it. Exits silently when geocoding has not yet completed.'
        category='Household'
    )
    public static void matchAndLink(List<Request> requests) {
        for (Request req : requests) {
            HouseholdGeoMatchService.matchAndLinkHousehold((Id) req.contactId);
        }
    }
}