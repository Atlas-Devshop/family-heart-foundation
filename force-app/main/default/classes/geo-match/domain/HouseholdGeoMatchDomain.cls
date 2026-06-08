/**
 * HouseholdGeoMatchDomain
 *
 * Business-rules layer for the Household Geolocation Matching feature.
 * Enforces validation and transformation rules on in-memory data.
 * Contains no SOQL and performs no DML.
 *
 * ADH-9796
 */
public with sharing class HouseholdGeoMatchDomain {

    /**
     * Removes the NPSP auto-created household from the candidate list so it is
     * never mistakenly treated as a pre-existing match.
     *
     * @param households       Candidate household Accounts from the selector
     * @param npspHouseholdId  Id of the household NPSP just auto-created
     * @return                 Filtered list with the NPSP household excluded
     */
    public List<Account> excludeNpspAutoCreatedHousehold(
        List<Account> households,
        Id npspHouseholdId
    ) {
        List<Account> filtered = new List<Account>();
        for (Account hh : households) {
            if (hh.Id != npspHouseholdId) {
                filtered.add(hh);
            }
        }
        return filtered;
    }

    /**
     * Returns the nearest household from an already-distance-sorted list.
     * Returns null when the list is empty (no match available).
     *
     * @param households  Accounts sorted ascending by distance (from selector)
     */
    public Account findClosestMatch(List<Account> households) {
        if (households == null || households.isEmpty()) {
            return null;
        }
        return households[0];
    }

    /**
     * Builds a household display name by combining all existing member last names
     * with the incoming contact's last name, deduplicating, sorting A→Z, and
     * appending " Household".
     *
     * Example: members [Smith, Johnson] + newLastName "Johnson"
     *          → "Johnson AND Smith Household"
     *
     * @param members      Current household members from the selector
     * @param newLastName  Last name of the contact being added / renamed
     */
    public String buildHouseholdName(List<Contact> members, String newLastName) {
        Set<String> lastNames = new Set<String>();

        for (Contact c : members) {
            if (String.isNotBlank(c.LastName)) {
                lastNames.add(c.LastName);
            }
        }

        if (String.isNotBlank(newLastName)) {
            lastNames.add(newLastName);
        }

        List<String> sortedNames = new List<String>(lastNames);
        sortedNames.sort();

        return String.join(sortedNames, ' ; ') + ' Household';
    }
}
