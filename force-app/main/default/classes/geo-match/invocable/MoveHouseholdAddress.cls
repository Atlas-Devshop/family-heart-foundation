public with sharing class MoveHouseholdAddress {

    public class Request {
        @InvocableVariable(label='Contact Id' required=true)
        public Id contactId;

        @InvocableVariable(label='Street' required=true)
        public String street;

        @InvocableVariable(label='City' required=true)
        public String city;

        @InvocableVariable(label='State')
        public String state;

        @InvocableVariable(label='Postal Code')
        public String postalCode;

        @InvocableVariable(label='Country')
        public String country;

        @InvocableVariable(label='Address Type')
        public String addressType;
    }

    @InvocableMethod(
        label='Move Household to New Address'
        description='Creates a new primary address on the household and syncs all member contacts to it'
        category='Household'
    )
    public static void move(List<Request> requests) {
        if (requests == null || requests.isEmpty()) return;
        Request req = requests[0];
        MoveHouseholdService.move(
            req.contactId, req.street, req.city,
            req.state, req.postalCode, req.country, req.addressType
        );
    }
}
