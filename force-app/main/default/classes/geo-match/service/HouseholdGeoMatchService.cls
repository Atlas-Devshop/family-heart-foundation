/**
 * HouseholdGeoMatchService
 *
 * Orchestration layer for the Household Geolocation Matching feature.
 * Coordinates the selector (SOQL) and domain (rules) layers, and owns
 * all DML for this feature.
 *
 * Custom Metadata record named "Default" (Radius_Threshold_Miles__c field),
 * so it can be adjusted without a code deployment.
 *
 * ADH-9796
 */
public with sharing class HouseholdGeoMatchService {

    @TestVisible
    private static HouseholdGeoMatchSelector selector = new HouseholdGeoMatchSelector();

    @TestVisible
    private static HouseholdGeoMatchDomain domain = new HouseholdGeoMatchDomain();

    private static final Decimal DEFAULT_THRESHOLD_MILES = 0.05;
    private static final String LOG_PREFIX = '[HouseholdGeoMatchService] ';

    // ─────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────

    public static void matchAndLinkHousehold(Id contactId) {
        System.debug(LOG_PREFIX + '--- matchAndLinkHousehold START --- contactId: ' + contactId);

        Contact contact = selector.getContactById(contactId);
        System.debug(LOG_PREFIX + 'Contact: ' + contact.LastName
            + ' | MailingLat: ' + contact.MailingLatitude
            + ' | MailingLng: ' + contact.MailingLongitude
            + ' | AccountId (NPSP HH): ' + contact.AccountId);

        if (contact.MailingLatitude == null || contact.MailingLongitude == null) {
            System.debug(LOG_PREFIX + 'GUARD: lat/lng null — geocoding not complete. Exiting.');
            return;
        }

        Decimal threshold  = 0.5;
        Id npspHouseholdId = contact.AccountId;
        System.debug(LOG_PREFIX + 'Threshold: ' + threshold + ' mi | NPSP HH to exclude: ' + npspHouseholdId);

        List<Account> candidates = selector.getHouseholdsWithinRadius(
            contact.MailingLatitude,
            contact.MailingLongitude,
            threshold
        );
        System.debug(LOG_PREFIX + 'Candidates before exclusion: ' + candidates.size());

        candidates = domain.excludeNpspAutoCreatedHousehold(candidates, npspHouseholdId);
        System.debug(LOG_PREFIX + 'Candidates after NPSP exclusion: ' + candidates.size());

        Account match = domain.findClosestMatch(candidates);
        System.debug(LOG_PREFIX + 'Closest match: ' + (match != null ? match.Id + ' — ' + match.Name : 'NONE'));

        if (match != null) {
            System.debug(LOG_PREFIX + 'MATCH FOUND — moving contact to: ' + match.Id);
            update new Contact(Id = contact.Id, AccountId = match.Id);
            System.debug(LOG_PREFIX + 'Contact AccountId updated.');

            HouseholdServiceUtils.deleteOrRenameHousehold(npspHouseholdId);

            System.debug(LOG_PREFIX + 'Renaming matched HH: ' + match.Id);
            renameHousehold(match.Id, contact.LastName);
        }
        else {
            System.debug(LOG_PREFIX + 'NO MATCH — creating new household for contact at new address.');
            Id newHouseholdId = HouseholdServiceUtils.createHousehold(contact.LastName);
            System.debug(LOG_PREFIX + 'New household created: ' + newHouseholdId);

            update new Contact(Id = contact.Id, AccountId = newHouseholdId);
            System.debug(LOG_PREFIX + 'Contact moved to new household.');

            update new Account(
                Id                = newHouseholdId,
                BillingStreet     = contact.MailingStreet,
                BillingCity       = contact.MailingCity,
                BillingState      = contact.MailingState,
                BillingPostalCode = contact.MailingPostalCode,
                BillingCountry    = contact.MailingCountry
            );
            System.debug(LOG_PREFIX + 'New household billing address set from contact mailing address.');

            HouseholdServiceUtils.deleteOrRenameHousehold(npspHouseholdId);
        }

        System.debug(LOG_PREFIX + '--- matchAndLinkHousehold END ---');
    }

    public static void renameHousehold(Id householdId, String newLastName) {
        renameHousehold(householdId, newLastName, null);
    }

    public static void renameHousehold(Id householdId, String newLastName, Id excludeContactId) {
        System.debug(LOG_PREFIX + '--- renameHousehold START --- householdId: ' + householdId
            + ' | newLastName: ' + newLastName + ' | excludeContactId: ' + excludeContactId);

        List<Contact> members = selector.getHouseholdMembers(householdId);
        System.debug(LOG_PREFIX + 'Members queried: ' + members.size());

        if (excludeContactId != null) {
            List<Contact> filtered = new List<Contact>();
            for (Contact c : members) {
                if (c.Id != excludeContactId) {
                    filtered.add(c);
                }
            }
            members = filtered;
            System.debug(LOG_PREFIX + 'Members after exclusion: ' + members.size());
        }

        String householdName = domain.buildHouseholdName(members, newLastName);
        System.debug(LOG_PREFIX + 'Built name: ' + householdName);

        update new Account(Id = householdId, Name = householdName);
        System.debug(LOG_PREFIX + 'Account renamed successfully.');

        System.debug(LOG_PREFIX + '--- renameHousehold END ---');
    }
}