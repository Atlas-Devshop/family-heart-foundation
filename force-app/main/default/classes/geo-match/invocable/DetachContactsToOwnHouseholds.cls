public with sharing class DetachContactsToOwnHouseholds {

    public class Request {
        @InvocableVariable(label='Contact Ids' required=true)
        public List<Id> contactIds;
    }

    @InvocableMethod(
        label='Detach Contacts to Own Households'
        description='Removes each selected contact from their current household and creates a new individual household for each'
        category='Household'
    )
    public static void detach(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;
        DetachContactsService.detach(requests[0].contactIds);
    }
}
