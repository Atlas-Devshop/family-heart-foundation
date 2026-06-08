/**
 * HouseholdDuplicateReportService
 *
 * Generates a CSV report of household Account pairs that fall within the same
 * geolocation threshold used by the live geo-matching logic (0.5 mi).
 * Intended as a one-time diagnostic run via Anonymous Apex to surface households
 * that were created before the matching feature was deployed.
 *
 * Usage (Anonymous Apex):
 *   HouseholdDuplicateReportService.generateAndSaveReport();
 *   // Check debug log for the download URL of the saved File.
 *
 * ADH-9797
 */
public with sharing class HouseholdDuplicateReportService {

    private static final Decimal THRESHOLD_MILES     = 0.5;
    private static final String  HH_RECORD_TYPE      = 'HH_Account';
    private static final String  LOG_PREFIX          = '[HouseholdDuplicateReportService] ';

    // ─────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────

    public static void generateAndSaveReport() {
        List<Account> households = queryHouseholds();
        System.debug(LOG_PREFIX + 'Households with coordinates: ' + households.size());

        List<DuplicatePair> pairs = findDuplicatePairs(households);
        System.debug(LOG_PREFIX + 'Duplicate pairs found: ' + pairs.size());

        if (pairs.isEmpty()) {
            System.debug(LOG_PREFIX + 'No duplicate pairs found within ' + THRESHOLD_MILES + ' mi. No file saved.');
            return;
        }

        String csv = buildCsv(pairs);
        Id contentVersionId = saveAsFile(csv);
        System.debug(LOG_PREFIX + 'File saved — ContentVersion Id: ' + contentVersionId);
        System.debug(LOG_PREFIX + 'Download: /sfc/servlet.shepherd/version/download/' + contentVersionId);
    }

    // ─────────────────────────────────────────────────────────────────
    // Query
    // ─────────────────────────────────────────────────────────────────

    private static List<Account> queryHouseholds() {
        Id hhRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get(HH_RECORD_TYPE)
            .getRecordTypeId();

        return [
            SELECT Id, Name,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   BillingLatitude, BillingLongitude,
                   (SELECT Id FROM Contacts)
            FROM Account
            WHERE RecordTypeId     = :hhRecordTypeId
              AND BillingLatitude  != null
              AND BillingLongitude != null
            ORDER BY BillingLatitude ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────────
    // Matching — Haversine distance, same threshold as geo-match service
    // ─────────────────────────────────────────────────────────────────

    // 0.5 mi ≈ 0.0073 degrees of latitude everywhere on Earth.
    // Households sorted by lat ASC: once the lat gap exceeds this bound the
    // remaining candidates are guaranteed to be > 0.5 mi away, so we break early.
    private static final Decimal LAT_DEGREE_BOUND = 0.0073;

    private static List<DuplicatePair> findDuplicatePairs(List<Account> households) {
        List<DuplicatePair> pairs = new List<DuplicatePair>();

        for (Integer i = 0; i < households.size(); i++) {
            Account hh1 = households[i];
            for (Integer j = i + 1; j < households.size(); j++) {
                Account hh2 = households[j];
                if (hh2.BillingLatitude - hh1.BillingLatitude > LAT_DEGREE_BOUND) break;
                Decimal dist = haversineDistanceMiles(
                    hh1.BillingLatitude, hh1.BillingLongitude,
                    hh2.BillingLatitude, hh2.BillingLongitude
                );
                if (dist <= THRESHOLD_MILES) {
                    pairs.add(new DuplicatePair(hh1, hh2, dist));
                }
            }
        }

        return pairs;
    }

    private static Decimal haversineDistanceMiles(
        Decimal lat1, Decimal lng1,
        Decimal lat2, Decimal lng2
    ) {
        Double R    = 3958.8;
        Double dLat = (Double)(lat2 - lat1) * Math.PI / 180;
        Double dLng = (Double)(lng2 - lng1) * Math.PI / 180;
        Double a    = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                    + Math.cos((Double)lat1 * Math.PI / 180)
                    * Math.cos((Double)lat2 * Math.PI / 180)
                    * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        Double c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return (Decimal)(R * c);
    }

    // ─────────────────────────────────────────────────────────────────
    // CSV builder
    // ─────────────────────────────────────────────────────────────────

    private static String buildCsv(List<DuplicatePair> pairs) {
        List<String> rows = new List<String>();
        rows.add(
            'HH1 Id,HH1 Name,HH1 Address,HH1 Latitude,HH1 Longitude,HH1 Members,' +
            'HH2 Id,HH2 Name,HH2 Address,HH2 Latitude,HH2 Longitude,HH2 Members,' +
            'Distance (miles)'
        );

        for (DuplicatePair p : pairs) {
            rows.add(
                csvField(p.hh1.Id)                          + ',' +
                csvField(p.hh1.Name)                        + ',' +
                csvField(billingAddress(p.hh1))             + ',' +
                p.hh1.BillingLatitude                       + ',' +
                p.hh1.BillingLongitude                      + ',' +
                p.hh1.Contacts.size()                       + ',' +
                csvField(p.hh2.Id)                          + ',' +
                csvField(p.hh2.Name)                        + ',' +
                csvField(billingAddress(p.hh2))             + ',' +
                p.hh2.BillingLatitude                       + ',' +
                p.hh2.BillingLongitude                      + ',' +
                p.hh2.Contacts.size()                       + ',' +
                p.distanceMiles.setScale(4)
            );
        }

        return String.join(rows, '\n');
    }

    private static String billingAddress(Account a) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(a.BillingStreet))     parts.add(a.BillingStreet.replace('\n', ' '));
        if (String.isNotBlank(a.BillingCity))       parts.add(a.BillingCity);
        if (String.isNotBlank(a.BillingState))      parts.add(a.BillingState);
        if (String.isNotBlank(a.BillingPostalCode)) parts.add(a.BillingPostalCode);
        if (String.isNotBlank(a.BillingCountry))    parts.add(a.BillingCountry);
        return String.join(parts, ', ');
    }

    private static String csvField(String val) {
        if (val == null) return '""';
        return '"' + val.replace('"', '""') + '"';
    }

    // ─────────────────────────────────────────────────────────────────
    // File output
    // ─────────────────────────────────────────────────────────────────

    private static Id saveAsFile(String csv) {
        String fileName = 'Duplicate_Households_Report_'
            + Datetime.now().format('yyyy-MM-dd_HH-mm') + '.csv';

        ContentVersion cv = new ContentVersion(
            Title          = fileName,
            PathOnClient   = fileName,
            VersionData    = Blob.valueOf(csv),
            IsMajorVersion = true
        );
        insert cv;
        return cv.Id;
    }

    // ─────────────────────────────────────────────────────────────────
    // Inner class
    // ─────────────────────────────────────────────────────────────────

    private class DuplicatePair {
        Account hh1;
        Account hh2;
        Decimal distanceMiles;

        DuplicatePair(Account hh1, Account hh2, Decimal distanceMiles) {
            this.hh1           = hh1;
            this.hh2           = hh2;
            this.distanceMiles = distanceMiles;
        }
    }
}
