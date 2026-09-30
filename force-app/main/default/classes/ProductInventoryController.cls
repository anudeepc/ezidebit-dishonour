public with sharing class ProductInventoryController {

    public String searchTerm { get; set; }
    public String sortField { get; set; }
    public String sortOrder { get; set; }
    public Integer pageSize { get; set; }
    public Integer pageNumber { get; set; }
    public Integer totalRecords { get; set; }
    public Integer totalPages { get; set; }
    public Boolean isLoading { get; set; }

    // Filter properties
    public Boolean filterWebsiteProducts { get; set; }
    public Boolean filterProductsWithErrors { get; set; }
    public Boolean filterMissingURLs { get; set; }
    public Boolean filterPriceDiscrepancies { get; set; }
    public Boolean filterDraftProducts { get; set; }
    public Boolean filterWebsiteDrift { get; set; }
    public Boolean filterDisabledProducts { get; set; }
    public Boolean filterBelowTargetMargin { get; set; } // margin below MARGIN_TARGET_LOW
    public String selectedCategory { get; set; }
    public String selectedVarianceRange { get; set; }
    public String selectedSupplierCompetitor { get; set; }
    public String selectedBrand { get; set; } // Brand filter using Manufacturer_Name__c

    // Static caching for performance (safe in Salesforce as static variables are per-transaction)
    private static Map<String, List<Product_Inventory__c>> queryCache = new Map<String, List<Product_Inventory__c>>();
    private static Map<String, Integer> countCache = new Map<String, Integer>();
    private static Long cacheTimestamp = 0;
    private final Integer CACHE_DURATION_MS = 60000; // 60 seconds cache

    // ============== VARIANCE UTILITY METHODS (Single Source of Truth) ==============

    // Get lowest valid price from a list (filters null and <= 0)
    private static Decimal getLowestValidPrice(List<Decimal> prices) {
        List<Decimal> valid = new List<Decimal>();
        for (Decimal p : prices) {
            if (p != null && p > 0) valid.add(p);
        }
        if (valid.isEmpty()) return null;
        valid.sort();
        return valid[0];
    }

    // Get lowest supplier price from a record
    private static Decimal getLowestSupplierPrice(Product_Inventory__c rec) {
        return getLowestValidPrice(new List<Decimal>{
            rec.Supplier_1_Price__c,
            rec.Supplier_2_Price__c
        });
    }

    // Get average competitor price from a record (only includes valid prices > 0)
    private static Decimal getAverageCompetitorPrice(Product_Inventory__c rec) {
        List<Decimal> validPrices = new List<Decimal>();
        if (rec.Competitor_1_Market_Value__c != null && rec.Competitor_1_Market_Value__c > 0) {
            validPrices.add(rec.Competitor_1_Market_Value__c);
        }
        if (rec.Competitor_2_Market_Value__c != null && rec.Competitor_2_Market_Value__c > 0) {
            validPrices.add(rec.Competitor_2_Market_Value__c);
        }
        if (rec.Competitor_3_Market_Value__c != null && rec.Competitor_3_Market_Value__c > 0) {
            validPrices.add(rec.Competitor_3_Market_Value__c);
        }
        if (validPrices.isEmpty()) {
            return null;
        }
        Decimal total = 0;
        for (Decimal p : validPrices) {
            total += p;
        }
        return total / validPrices.size();
    }

    // Calculate variance percentage (returns null if can't calculate)
    private static Decimal calcVariancePercent(Decimal supplierPrice, Decimal competitorPrice) {
        if (supplierPrice == null || supplierPrice <= 0 || competitorPrice == null) {
            return null;
        }
        return ((competitorPrice - supplierPrice) / supplierPrice) * 100;
    }

    // Determine variance range bucket from percentage
    private static String getVarianceRangeBucket(Decimal variancePercent) {
        if (variancePercent == null) return 'noVariance';
        Decimal abs = Math.abs(variancePercent);
        if (abs < 5) return 'under5';
        if (abs < 15) return '5to15';
        if (abs < 25) return '15to25';
        return 'over25';
    }

    // ============== END VARIANCE UTILITY METHODS ==============

    // ============== MARGIN (KPI 15-17%, Chris Sep 2026) ==============
    // Our margin on the cash price, all amounts including GST, the same basis as the Brian Report's
    // OpportunityLineItem.Margin_Percentage__c: (cash price - cheapest supplier price - metro delivery) / cash price.
    // The variance above is different: it compares competitors with the cheapest supplier.
    public static final Decimal MARGIN_TARGET_LOW = 15;
    public static final Decimal MARGIN_TARGET_GOOD = 17;

    private static Decimal calcMarginPercent(Product_Inventory__c rec) {
        // Some callers query only the fields they display; a field left out counts as blank.
        Decimal cashPrice = rec.isSet('Cash_Price__c') ? rec.Cash_Price__c : null;
        Decimal supplierPrice = getLowestSupplierPrice(rec);
        if (cashPrice == null || cashPrice <= 0 || supplierPrice == null) {
            return null;
        }
        Decimal delivery = rec.isSet('Metro_Delivery_Cost_Inc_GST__c') && rec.Metro_Delivery_Cost_Inc_GST__c != null
            ? rec.Metro_Delivery_Cost_Inc_GST__c : 0;
        return ((cashPrice - supplierPrice - delivery) / cashPrice) * 100;
    }

    private static String getMarginBand(Decimal marginPercent) {
        if (marginPercent == null) return 'noMargin';
        if (marginPercent < MARGIN_TARGET_LOW) return 'below';
        if (marginPercent < MARGIN_TARGET_GOOD) return 'near';
        return 'onTarget';
    }

    // ============== END MARGIN ==============

    public String selectedRecordId { get; set; }
    public Product_Inventory__c selectedRecord { get; set; }

    // New product for creation modal using standard Salesforce fields
    public Product_Inventory__c newProduct { get; set; }

    // Bulk action properties
    public String selectedProductIds { get; set; }
    public Boolean bulkWebsiteStatus { get; set; }
    public Integer supplierForInvoiceCost { get; set; } // 1 or 2 - which supplier price to copy to Invoice Cost

    public ProductInventoryController() {
        searchTerm = '';
        sortField = 'LastModifiedDate';
        sortOrder = 'DESC';
        pageSize = 50; // Optimized page size
        pageNumber = 1;
        totalRecords = 0;
        totalPages = 0;
        isLoading = false;
        filterWebsiteProducts = true; // Default to show only website products
        filterProductsWithErrors = false;
        filterMissingURLs = false;
        filterPriceDiscrepancies = false;
        filterDraftProducts = false;
        filterWebsiteDrift = false;
        filterDisabledProducts = false;
        filterBelowTargetMargin = false;
        selectedCategory = 'All'; // Default to show all categories
        selectedVarianceRange = 'All'; // Default to show all variance ranges
        selectedSupplierCompetitor = 'All'; // Default to show all suppliers/competitors
        selectedBrand = 'All'; // Default to show all brands

        // Initialize new product instance
        newProduct = new Product_Inventory__c();

        // Initialize pagination data
        initializePagination();
    }

    // Initialize pagination metadata by calculating total records
    private void initializePagination() {
        try {
            totalRecords = getTotalRecordCount();
            totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);
        } catch (Exception e) {
            totalRecords = 0;
            totalPages = 0;
            System.debug('Error initializing pagination: ' + e.getMessage());
        }
    }

    // Optimized method that only loads the current page
    public List<InventoryWrapper> getInventoryRecords() {
        List<InventoryWrapper> wrappers = new List<InventoryWrapper>();
        List<InventoryWrapper> allFilteredWrappers = new List<InventoryWrapper>();

        try {
            isLoading = true;

            // Check if client-side filters are active
            Boolean hasClientSideFilter = filterPriceDiscrepancies || filterBelowTargetMargin == true ||
                (String.isNotBlank(selectedVarianceRange) && selectedVarianceRange != 'All');

            // Build and execute query
            String query = buildPaginatedQuery();
            List<Product_Inventory__c> records = executeCachedQuery(query);

            // Create wrappers - ALWAYS evaluate status for proper display
            for (Product_Inventory__c record : records) {
                InventoryWrapper wrapper = new InventoryWrapper(record, true); // Always evaluate

                // Apply client-side filters (price discrepancy and variance range)
                Boolean includeRecord = true;

                // Price discrepancy filter (filters by price discrepancy status)
                if (filterPriceDiscrepancies) {
                    includeRecord = wrapper.hasPriceDiscrepancy;
                }

                // Variance range filter (uses absolute value of variance percentage)
                if (includeRecord && String.isNotBlank(selectedVarianceRange) && selectedVarianceRange != 'All') {
                    includeRecord = matchesVarianceRange(wrapper);
                }

                // Margin below target
                if (includeRecord && filterBelowTargetMargin == true) {
                    includeRecord = wrapper.marginBand == 'below';
                }

                if (includeRecord) {
                    allFilteredWrappers.add(wrapper);
                }
            }

            // Handle special StatusOrder sorting if needed
            if (sortField == 'StatusOrder') {
                sortByStatus(allFilteredWrappers);
            }

            // When client-side filters are active, we need to paginate the filtered results
            if (hasClientSideFilter) {
                // Update total records to reflect filtered count
                totalRecords = allFilteredWrappers.size();
                totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);

                // Ensure page number is valid
                if (pageNumber < 1) pageNumber = 1;
                if (pageNumber > totalPages && totalPages > 0) pageNumber = totalPages;

                // Get the records for the current page
                Integer startIndex = (pageNumber - 1) * pageSize;
                Integer endIndex = Math.min(startIndex + pageSize, allFilteredWrappers.size());

                for (Integer i = startIndex; i < endIndex; i++) {
                    wrappers.add(allFilteredWrappers[i]);
                }
            } else {
                // No client-side filter, use standard pagination from query
                totalRecords = getTotalRecordCount();
                totalPages = (Integer)Math.ceil((Decimal)totalRecords / pageSize);

                // Ensure page number is valid
                if (pageNumber < 1) pageNumber = 1;
                if (pageNumber > totalPages && totalPages > 0) pageNumber = totalPages;

                wrappers = allFilteredWrappers;
            }

        } catch (Exception e) {
            System.debug('Error in getInventoryRecords: ' + e.getMessage());
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error loading records: ' + e.getMessage()));
        } finally {
            isLoading = false;
        }

        return wrappers;
    }

    // Cached query execution
    private List<Product_Inventory__c> executeCachedQuery(String query) {
        String cacheKey = query + '_' + pageNumber;

        // Check if cache is still valid
        if (System.currentTimeMillis() - cacheTimestamp > CACHE_DURATION_MS) {
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = System.currentTimeMillis();
        }

        if (!queryCache.containsKey(cacheKey)) {
            queryCache.put(cacheKey, Database.query(query));
        }

        return queryCache.get(cacheKey);
    }

    // Get total count with caching
    private Integer getTotalRecordCount() {
        String countQuery = buildCountQuery();
        String cacheKey = 'count_' + countQuery + '_' + filterPriceDiscrepancies + '_' + selectedVarianceRange + '_' + filterBelowTargetMargin;

        // Check cache validity
        if (System.currentTimeMillis() - cacheTimestamp > CACHE_DURATION_MS) {
            countCache.clear();
        }

        if (!countCache.containsKey(cacheKey)) {
            Integer count;

            // Client-side filters (price discrepancy and variance) require special handling
            Boolean hasClientSideFilter = filterPriceDiscrepancies || filterBelowTargetMargin == true ||
                (String.isNotBlank(selectedVarianceRange) && selectedVarianceRange != 'All');

            if (hasClientSideFilter) {
                // Can't count via SOQL, must count after wrapper evaluation
                // Note: buildPaginatedQuery() already returns query without LIMIT when hasClientSideFilter is true
                String query = buildPaginatedQuery();
                List<Product_Inventory__c> allRecords = Database.query(query);
                count = 0;
                for (Product_Inventory__c record : allRecords) {
                    InventoryWrapper wrapper = new InventoryWrapper(record, true);

                    // Apply the same client-side filters as in getInventoryRecords()
                    Boolean includeRecord = true;

                    // Price discrepancy filter
                    if (filterPriceDiscrepancies) {
                        includeRecord = wrapper.hasPriceDiscrepancy;
                    }

                    // Variance range filter
                    if (includeRecord && String.isNotBlank(selectedVarianceRange) && selectedVarianceRange != 'All') {
                        includeRecord = matchesVarianceRange(wrapper);
                    }

                    // Margin below target
                    if (includeRecord && filterBelowTargetMargin == true) {
                        includeRecord = wrapper.marginBand == 'below';
                    }

                    if (includeRecord) {
                        count++;
                    }
                }
            } else {
                count = Database.countQuery(countQuery);
            }

            countCache.put(cacheKey, count);
        }

        return countCache.get(cacheKey);
    }

    // Build count query for total records
    private String buildCountQuery() {
        String query = 'SELECT COUNT() FROM Product_Inventory__c';
        String whereClause = buildWhereClause();

        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }

        return query;
    }

    // Build WHERE clause based on filters (SOQL injection safe with bind variables)
    private String buildWhereClause() {
        List<String> conditions = new List<String>();

        // Search term - use bind variable to prevent SOQL injection
        if (String.isNotBlank(searchTerm)) {
            // Sanitize search term: allow alphanumeric, spaces, hyphens, and periods (for decimals)
            String sanitizedSearch = searchTerm.replaceAll('[^a-zA-Z0-9\\s\\-\\.]', '');
            if (String.isNotBlank(sanitizedSearch)) {
                String escapedSearch = String.escapeSingleQuotes(sanitizedSearch);
                List<String> searchConditions = new List<String>();

                // Text field searches - Product ID, Name, Product Code, Suppliers, Competitors, Comments
                searchConditions.add('Name LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('ProductName__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('ProductCode__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Website_Product_Id__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Supplier_1_Name__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Supplier_2_Name__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Competitor_1__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Competitor_2__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Competitor_3__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Comments__c LIKE \'%' + escapedSearch + '%\'');
                searchConditions.add('Supplier_Error_Notes__c LIKE \'%' + escapedSearch + '%\'');

                // Check if search term is a valid number for price searches
                try {
                    Decimal searchPrice = Decimal.valueOf(sanitizedSearch.trim());
                    // Search for exact price matches or close matches (within $1)
                    Decimal lowerBound = searchPrice - 1;
                    Decimal upperBound = searchPrice + 1;
                    searchConditions.add('(Cash_Price__c >= ' + lowerBound + ' AND Cash_Price__c <= ' + upperBound + ')');
                    searchConditions.add('(RRP__c >= ' + lowerBound + ' AND RRP__c <= ' + upperBound + ')');
                    searchConditions.add('(Supplier_1_Price__c >= ' + lowerBound + ' AND Supplier_1_Price__c <= ' + upperBound + ')');
                    searchConditions.add('(Supplier_2_Price__c >= ' + lowerBound + ' AND Supplier_2_Price__c <= ' + upperBound + ')');
                } catch (Exception e) {
                    // Not a number, skip price search
                }

                conditions.add('(' + String.join(searchConditions, ' OR ') + ')');
            }
        }

        // Website products filter
        if (filterWebsiteProducts) {
            conditions.add('In_R4K_Website__c = true');
        }

        // Products with errors filter
        if (filterProductsWithErrors) {
            conditions.add('Supplier_Error_Notes__c != null');
        }

        // Missing URLs filter - this requires checking multiple fields
        if (filterMissingURLs) {
            conditions.add('((Competitor_1__c != null AND Competitor_1_URL__c = null) OR ' +
                          '(Competitor_2__c != null AND Competitor_2_URL__c = null) OR ' +
                          '(Competitor_3__c != null AND Competitor_3_URL__c = null) OR ' +
                          '(Supplier_1_Name__c != null AND Supplier_1_URL__c = null) OR ' +
                          '(Supplier_2_Name__c != null AND Supplier_2_URL__c = null))');
        }

        // Draft products filter
        if (filterDraftProducts) {
            conditions.add('Website_Status__c = \'Draft\'');
        }

        // Disabled products filter
        if (filterDisabledProducts) {
            conditions.add('Manual_Disable__c = true');
        }

        // Website disagreement queue. Website_Drift__c is a formula over the observation fields,
        // so this shows only products the sweep has actually looked at and found inconsistent.
        if (filterWebsiteDrift) {
            conditions.add('Website_Drift__c = true');
        }

        // Category filter
        if (String.isNotBlank(selectedCategory) && selectedCategory != 'All') {
            if (selectedCategory == 'Uncategorised') {
                conditions.add('Category__c = null');
            } else {
                conditions.add('Category__c = \'' + String.escapeSingleQuotes(selectedCategory) + '\'');
            }
        }

        // Supplier/Competitor filter - searches across all supplier and competitor name fields
        if (String.isNotBlank(selectedSupplierCompetitor) && selectedSupplierCompetitor != 'All') {
            String escapedName = String.escapeSingleQuotes(selectedSupplierCompetitor);
            conditions.add('(Supplier_1_Name__c = \'' + escapedName + '\' OR ' +
                          'Supplier_2_Name__c = \'' + escapedName + '\' OR ' +
                          'Competitor_1__c = \'' + escapedName + '\' OR ' +
                          'Competitor_2__c = \'' + escapedName + '\' OR ' +
                          'Competitor_3__c = \'' + escapedName + '\')');
        }

        // Brand filter - uses Manufacturer_Name__c field
        if (String.isNotBlank(selectedBrand) && selectedBrand != 'All') {
            String escapedBrand = String.escapeSingleQuotes(selectedBrand);
            conditions.add('Manufacturer_Name__c = \'' + escapedBrand + '\'');
        }

        // Note: Price discrepancies filter requires post-query filtering in wrapper
        // because it involves comparing formula fields

        return String.join(conditions, ' AND ');
    }

    private void sortByStatus(List<InventoryWrapper> wrappers) {
        // Evaluate status for all wrappers before sorting
        for (InventoryWrapper w : wrappers) {
            w.evaluateStatus();
        }

        // Sort by priority
        if (sortOrder == 'ASC') {
            wrappers.sort(new StatusComparatorAsc());
        } else {
            wrappers.sort(new StatusComparatorDesc());
        }
    }

    // Comparator for ascending status sort
    class StatusComparatorAsc implements System.Comparator<InventoryWrapper> {
        public Integer compare(InventoryWrapper w1, InventoryWrapper w2) {
            return w1.getStatusPriority() - w2.getStatusPriority();
        }
    }

    // Comparator for descending status sort
    class StatusComparatorDesc implements System.Comparator<InventoryWrapper> {
        public Integer compare(InventoryWrapper w1, InventoryWrapper w2) {
            return w2.getStatusPriority() - w1.getStatusPriority();
        }
    }

    // Whitelist of allowed sort fields to prevent injection
    private static final Set<String> ALLOWED_SORT_FIELDS = new Set<String>{
        'Name', 'Cash_Price__c', 'RRP__c',
        'Competitor_1__c', 'Competitor_1_Market_Value__c',
        'Competitor_2__c', 'Competitor_2_Market_Value__c',
        'Competitor_3__c', 'Competitor_3_Market_Value__c',
        'Supplier_1_Name__c', 'Supplier_1_Price__c',
        'Supplier_2_Name__c', 'Supplier_2_Price__c',
        'LastModifiedDate', 'StatusOrder'
    };

    // Optimized query builder with pagination
    private String buildPaginatedQuery() {
        // Only select fields needed for list view
        String query = 'SELECT Id, Name, ProductName__c, ProductCode__c, Website_Product_Id__c, ' +
            'Manufacturer_Name__c, Cash_Price__c, RRP__c, ' +
            'Competitor_1__c, Competitor_1_URL__c, Competitor_1_Market_Value__c, ' +
            'Competitor_1_New_Market_Value__c, Competitor_1_Last_Updated__c, ' +
            'Competitor_1_Google_Drive_URL__c, Competitor_1_URL_Notes__c, ' +
            'Competitor_2__c, Competitor_2_URL__c, Competitor_2_Market_Value__c, ' +
            'Competitor_2_New_Market_Value__c, Competitor_2_Last_Updated__c, ' +
            'Competitor_2_Google_Drive_URL__c, Competitor_2_URL_Notes__c, ' +
            'Competitor_3__c, Competitor_3_URL__c, Competitor_3_Market_Value__c, ' +
            'Competitor_3_New_Market_Value__c, Competitor_3_Last_Updated__c, ' +
            'Competitor_3_Google_Drive_URL__c, Competitor_3_URL_Notes__c, ' +
            'Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c, ' +
            'Supplier_1_Google_Drive_URL__c, Supplier_1_Last_Updated__c, ' +
            'Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c, ' +
            'Supplier_2_Google_Drive_URL__c, Supplier_2_Last_Updated__c, ' +
            'Delivery_Partner__c, Delivery_Cost__c, Metro_Delivery_Cost_Inc_GST__c, ' +
            'Regional_Delivery_Cost__c, Regional_Delivery_Cost_Inc_GST__c, ' +
            'Supplier_Error_Notes__c, In_R4K_Website__c, Manual_Disable__c, ' +
            'Website_Drift__c, Woo_Stock_Status__c, Woo_Post_Status__c, Woo_Purchasable__c, ' +
            'Woo_Observed_At__c, Woo_Observation_Error__c, Woo_Drift_Since__c, ' +
            'Availability_Resolved_By__c, Availability_Resolved_At__c, Availability_Resolution__c, ' +
            'Website_Update_Requested_Date__c, Website_Status__c, Website_Update_Date__c, ' +
            'Website_Update_Status__c, Website_URL__c, Category__c, LastModifiedDate, ' +
            'Website_Terms__c, Publish_13_Months__c, ' +
            'Publish_24_Months__c, Publish_36_Months__c ' +
            'FROM Product_Inventory__c';

        String whereClause = buildWhereClause();
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }

        // Apply database sorting if not sorting by StatusOrder - with whitelist validation
        if (String.isNotBlank(sortField) && sortField != 'StatusOrder') {
            // Validate sortField against whitelist
            if (ALLOWED_SORT_FIELDS.contains(sortField)) {
                // Validate sortOrder
                String validatedOrder = (sortOrder == 'DESC') ? 'DESC' : 'ASC';
                query += ' ORDER BY ' + sortField + ' ' + validatedOrder + ' NULLS LAST';
            } else {
                // Fallback to default if invalid sort field
                query += ' ORDER BY Name ASC NULLS LAST';
            }
        } else if (sortField != 'StatusOrder') {
            // Default sorting by Name if no sort field specified
            query += ' ORDER BY Name ASC NULLS LAST';
        }

        // Note: WITH SECURITY_ENFORCED removed to allow field access
        // Security is enforced via 'with sharing' class declaration and sharing rules

        // Add pagination - for client-side filters (price discrepancy, variance), we need to fetch ALL records
        // since matching records may be sparsely distributed across the dataset
        Boolean hasClientSideFilter = filterPriceDiscrepancies || filterBelowTargetMargin == true ||
            (String.isNotBlank(selectedVarianceRange) && selectedVarianceRange != 'All');

        // When variance filter is active, don't limit - we need to scan all records to find matches
        // Standard pagination only applies when no client-side filters are active
        if (!hasClientSideFilter) {
            query += ' LIMIT ' + pageSize;
            if (pageNumber > 1) {
                Integer offset = (pageNumber - 1) * pageSize;
                query += ' OFFSET ' + offset;
            }
        }
        // Note: When hasClientSideFilter is true, no LIMIT is applied to ensure all matching records are found

        return query;
    }

    // Full query for modal details (lazy loading)
    private String buildFullQuery() {
        return 'SELECT Id, Name, Cash_Price__c, RRP__c, Invoice_Cost__c, Comments__c, ' +
            'Competitor_1__c, Competitor_1_URL__c, Competitor_1_Market_Value__c, ' +
            'Competitor_1_New_Market_Value__c, Competitor_1_Last_Updated__c, ' +
            'Competitor_1_Google_Drive_URL__c, Competitor_1_URL_Notes__c, ' +
            'Competitor_2__c, Competitor_2_URL__c, Competitor_2_Market_Value__c, ' +
            'Competitor_2_New_Market_Value__c, Competitor_2_Last_Updated__c, ' +
            'Competitor_2_Google_Drive_URL__c, Competitor_2_URL_Notes__c, ' +
            'Competitor_3__c, Competitor_3_URL__c, Competitor_3_Market_Value__c, ' +
            'Competitor_3_New_Market_Value__c, Competitor_3_Last_Updated__c, ' +
            'Competitor_3_Google_Drive_URL__c, Competitor_3_URL_Notes__c, ' +
            'Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c, ' +
            'Supplier_1_Google_Drive_URL__c, Supplier_1_Last_Updated__c, ' +
            'Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c, ' +
            'Supplier_2_Google_Drive_URL__c, Supplier_2_Last_Updated__c, ' +
            'Supplier_Error_Notes__c, ' +
            'Website_Update_Requested_Date__c, Website_Status__c, Website_Update_Date__c, ' +
            'Website_Update_Status__c, Website_URL__c ' +
            'FROM Product_Inventory__c ' +
            'WHERE Id = :recordId ' +
            'LIMIT 1';
    }

    public void search() {
        pageNumber = 1;
        clearCache();
        initializePagination();
    }

    public void clearFilters() {
        filterWebsiteProducts = true; // Reset to default (website products only)
        filterProductsWithErrors = false;
        filterMissingURLs = false;
        filterPriceDiscrepancies = false;
        filterDraftProducts = false;
        filterWebsiteDrift = false;
        filterDisabledProducts = false;
        selectedVarianceRange = 'All'; // Reset variance filter
        filterBelowTargetMargin = false;
        selectedSupplierCompetitor = 'All'; // Reset supplier/competitor filter
        selectedBrand = 'All'; // Reset brand filter
        searchTerm = '';
        search();
    }

    public void sortBy() {
        if (sortOrder == 'ASC') {
            sortOrder = 'DESC';
        } else {
            sortOrder = 'ASC';
        }
        pageNumber = 1; // Reset to first page when sorting
        clearCache();
    }

    // Pagination methods
    public void firstPage() {
        pageNumber = 1;
        clearCache();
    }

    public void changePageSize() {
        // Guard against null/invalid values coming from the UI
        if (pageSize == null || pageSize <= 0) {
            pageSize = 50;
        }

        pageNumber = 1; // Reset to first page when changing page size
        clearCache();
        initializePagination(); // Recalculate totals with the new page size
    }

    public void previousPage() {
        if (pageNumber > 1) {
            pageNumber--;
            clearCache();
        }
    }

    public void nextPage() {
        if (pageNumber < totalPages) {
            pageNumber++;
            clearCache();
        }
    }

    public void lastPage() {
        pageNumber = totalPages;
        clearCache();
    }

    public void goToPage() {
        // This will be called when user enters a specific page number
        if (pageNumber < 1) pageNumber = 1;
        if (pageNumber > totalPages) pageNumber = totalPages;
        clearCache();
    }

    // Clear cache when navigation changes
    private void clearCache() {
        queryCache.clear();
        countCache.clear();
        cacheTimestamp = 0;
    }

    // Check if we can navigate
    public Boolean getHasPrevious() {
        return pageNumber > 1;
    }

    public Boolean getHasNext() {
        return pageNumber < totalPages;
    }

    // Get page numbers for display
    public List<Integer> getPageNumbers() {
        List<Integer> pages = new List<Integer>();
        Integer startPage = Math.max(1, pageNumber - 2);
        Integer endPage = Math.min(totalPages, pageNumber + 2);

        for (Integer i = startPage; i <= endPage; i++) {
            pages.add(i);
        }

        return pages;
    }

    // Get category options for dropdown
    public List<SelectOption> getCategoryOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('All', 'All'));

        // Query unique categories from Product_Inventory__c
        Set<String> categories = new Set<String>();
        for (AggregateResult ar : [SELECT Category__c FROM Product_Inventory__c
                                    WHERE Category__c != null
                                    GROUP BY Category__c
                                    ORDER BY Category__c]) {
            String category = (String)ar.get('Category__c');
            if (String.isNotBlank(category)) {
                categories.add(category);
            }
        }

        // Add categories to options
        for (String category : categories) {
            options.add(new SelectOption(category, category));
        }

        // Add "Uncategorised" option at the end
        options.add(new SelectOption('Uncategorised', 'Uncategorised'));

        return options;
    }

    // Get price variance range options for dropdown filter
    public List<SelectOption> getVarianceRangeOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('All', 'All Variance'));
        options.add(new SelectOption('under5', 'Under 5% (Anomaly)'));
        options.add(new SelectOption('5to15', '5% - 15% (Concerning)'));
        options.add(new SelectOption('15to25', '15% - 25% (Moderate)'));
        options.add(new SelectOption('over25', 'Over 25% (Competitive)'));
        options.add(new SelectOption('noVariance', 'No Variance Data'));
        return options;
    }

    // Get unique supplier and competitor names for dropdown filter
    public List<SelectOption> getSupplierCompetitorOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('All', 'All Suppliers/Competitors'));

        // Collect unique names from all supplier and competitor fields
        Set<String> uniqueNames = new Set<String>();

        // Query all distinct supplier and competitor names
        for (AggregateResult ar : [SELECT Supplier_1_Name__c name FROM Product_Inventory__c
                                    WHERE Supplier_1_Name__c != null
                                    GROUP BY Supplier_1_Name__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueNames.add(name);
            }
        }

        for (AggregateResult ar : [SELECT Supplier_2_Name__c name FROM Product_Inventory__c
                                    WHERE Supplier_2_Name__c != null
                                    GROUP BY Supplier_2_Name__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueNames.add(name);
            }
        }

        for (AggregateResult ar : [SELECT Competitor_1__c name FROM Product_Inventory__c
                                    WHERE Competitor_1__c != null
                                    GROUP BY Competitor_1__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueNames.add(name);
            }
        }

        for (AggregateResult ar : [SELECT Competitor_2__c name FROM Product_Inventory__c
                                    WHERE Competitor_2__c != null
                                    GROUP BY Competitor_2__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueNames.add(name);
            }
        }

        for (AggregateResult ar : [SELECT Competitor_3__c name FROM Product_Inventory__c
                                    WHERE Competitor_3__c != null
                                    GROUP BY Competitor_3__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueNames.add(name);
            }
        }

        // Sort the names alphabetically
        List<String> sortedNames = new List<String>(uniqueNames);
        sortedNames.sort();

        // Add to options
        for (String name : sortedNames) {
            options.add(new SelectOption(name, name));
        }

        return options;
    }

    // Get unique brand names (Manufacturer_Name__c) for dropdown filter
    public List<SelectOption> getBrandOptions() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('All', 'All Brands'));

        // Collect unique brand names
        Set<String> uniqueBrands = new Set<String>();

        // Query all distinct manufacturer names
        for (AggregateResult ar : [SELECT Manufacturer_Name__c name FROM Product_Inventory__c
                                    WHERE Manufacturer_Name__c != null
                                    GROUP BY Manufacturer_Name__c]) {
            String name = (String)ar.get('name');
            if (String.isNotBlank(name)) {
                uniqueBrands.add(name);
            }
        }

        // Sort the brands alphabetically
        List<String> sortedBrands = new List<String>(uniqueBrands);
        sortedBrands.sort();

        // Add to options
        for (String brand : sortedBrands) {
            options.add(new SelectOption(brand, brand));
        }

        return options;
    }

    // Check if wrapper matches selected variance range(s) using centralized bucket logic
    // Supports multiple comma-separated values for multi-select (OR logic)
    private Boolean matchesVarianceRange(InventoryWrapper wrapper) {
        // If no filter or 'All', include everything
        if (String.isBlank(selectedVarianceRange) || selectedVarianceRange == 'All') {
            return true;
        }

        // Parse comma-separated selections
        Set<String> selectedRanges = new Set<String>();
        for (String range : selectedVarianceRange.split(',')) {
            selectedRanges.add(range.trim());
        }

        if (selectedRanges.isEmpty() || selectedRanges.contains('All')) {
            return true;
        }

        // Get the bucket for this wrapper using centralized utility
        String bucket = getVarianceRangeBucket(wrapper.priceVariancePercent);

        // Check if wrapper's bucket matches any selected range (OR logic)
        return selectedRanges.contains(bucket);
    }

    public void loadRecordDetails() {
        if (String.isNotBlank(selectedRecordId)) {
            String recordId = selectedRecordId;
            String query = buildFullQuery();
            List<Product_Inventory__c> records = Database.query(query);
            if (!records.isEmpty()) {
                selectedRecord = records[0];
            }
        }
    }

    @RemoteAction
    public static Product_Inventory__c getRecordDetails(String recordId) {
        // Input validation
        if (String.isBlank(recordId)) {
            throw new IllegalArgumentException('Record ID is required');
        }

        // Validate ID format to prevent injection
        try {
            Id validId = Id.valueOf(recordId);
        } catch (Exception e) {
            throw new IllegalArgumentException('Invalid Record ID format');
        }

        // Check object-level read access
        if (!Schema.sObjectType.Product_Inventory__c.isAccessible()) {
            throw new System.NoAccessException();
        }

        // Lazy load full details only when modal opens
        return [
            SELECT Id, Name, Owner.Name, ProductName__c, CurrencyIsoCode, Display_Name__c,
                ProductCode__c, DeviceModel__c, Website_Product_Id__c, ProductList__c,
                Manufacturer_Name__c, Cash_Price__c, RRP__c, Invoice_Cost__c, Comments__c,
                Competitor_1__c, Competitor_1_URL__c, Competitor_1_Market_Value__c,
                Competitor_1_New_Market_Value__c, Competitor_1_Last_Updated__c,
                Competitor_1_Google_Drive_URL__c, Competitor_1_URL_Notes__c,
                Competitor_2__c, Competitor_2_URL__c, Competitor_2_Market_Value__c,
                Competitor_2_New_Market_Value__c, Competitor_2_Last_Updated__c,
                Competitor_2_Google_Drive_URL__c, Competitor_2_URL_Notes__c,
                Competitor_3__c, Competitor_3_URL__c, Competitor_3_Market_Value__c,
                Competitor_3_New_Market_Value__c, Competitor_3_Last_Updated__c,
                Competitor_3_Google_Drive_URL__c, Competitor_3_URL_Notes__c,
                Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c,
                Supplier_1_Google_Drive_URL__c, Supplier_1_Last_Updated__c,
                Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c,
                Supplier_2_Google_Drive_URL__c, Supplier_2_Last_Updated__c,
                Supplier_Error_Notes__c, In_R4K_Website__c, Manual_Disable__c,
                Delivery_Partner__c, Delivery_Cost__c, Metro_Delivery_Cost_Inc_GST__c,
                Regional_Delivery_Cost__c, Regional_Delivery_Cost_Inc_GST__c,
                Website_Update_Requested_Date__c, Website_Status__c, Website_Update_Date__c,
                Website_Update_Status__c, Website_URL__c, LastModifiedDate
            FROM Product_Inventory__c
            WHERE Id = :recordId
                        LIMIT 1
        ];
    }

    // Standard Visualforce method for creating products using apex:inputField
    public PageReference createProductStandard() {
        // Create savepoint for transaction control
        Savepoint sp = Database.setSavepoint();

        try {
            // Check CRUD permissions before insert
            if (!Schema.sObjectType.Product_Inventory__c.isCreateable()) {
                throw new System.NoAccessException();
            }

            // Validate field-level security for fields being set
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Product_Inventory__c.fields.getMap();
            List<String> fieldsToCheck = new List<String>{
                'RRP__c', 'In_R4K_Website__c', 'Competitor_1__c', 'Competitor_1_Market_Value__c',
                'Competitor_1_URL__c', 'Supplier_1_Name__c', 'Supplier_1_Price__c'
            };

            for (String fieldName : fieldsToCheck) {
                if (fieldMap.containsKey(fieldName) && !fieldMap.get(fieldName).getDescribe().isCreateable()) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Insufficient permissions to create field: ' + fieldName));
                    return null;
                }
            }

            insert newProduct;

            // Create corresponding Product_Warehouse__c record
            Product_Warehouse__c pw = new Product_Warehouse__c();
            pw.Available_Stock__c = 100;
            pw.InStock__c = true;
            pw.Product_Inventory__c = newProduct.Id;
            pw.Stock_Pending_To_Order_To_Supplier__c = 0;
            pw.Warehouse_Location__c = 'ALL';
            insert pw;

            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Product created successfully!'));

            // Reset for next create
            newProduct = new Product_Inventory__c();

            // Clear cache to refresh list
            clearCache();

            return null; // Stay on same page
        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Insufficient permissions to create products'));
            return null;
        } catch (DmlException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error creating product: ' + e.getDmlMessage(0)));
            return null;
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error creating product: ' + e.getMessage()));
            return null;
        }
    }

    @RemoteAction
    public static Map<String, Object> createProduct(Map<String, Object> productData) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            Product_Inventory__c newProduct = new Product_Inventory__c();

            // Set basic fields
            // Note: Name field is auto-number and cannot be set manually
            if (productData.containsKey('RRP__c')) {
                newProduct.RRP__c = (Decimal) productData.get('RRP__c');
            }
            if (productData.containsKey('In_R4K_Website__c')) {
                newProduct.In_R4K_Website__c = (Boolean) productData.get('In_R4K_Website__c');
            }

            // Set competitor fields
            if (productData.containsKey('Competitor_1__c')) {
                newProduct.Competitor_1__c = (String) productData.get('Competitor_1__c');
            }
            if (productData.containsKey('Competitor_1_Market_Value__c')) {
                newProduct.Competitor_1_Market_Value__c = (Decimal) productData.get('Competitor_1_Market_Value__c');
            }
            if (productData.containsKey('Competitor_1_URL__c')) {
                newProduct.Competitor_1_URL__c = (String) productData.get('Competitor_1_URL__c');
            }

            if (productData.containsKey('Competitor_2__c')) {
                newProduct.Competitor_2__c = (String) productData.get('Competitor_2__c');
            }
            if (productData.containsKey('Competitor_2_Market_Value__c')) {
                newProduct.Competitor_2_Market_Value__c = (Decimal) productData.get('Competitor_2_Market_Value__c');
            }
            if (productData.containsKey('Competitor_2_URL__c')) {
                newProduct.Competitor_2_URL__c = (String) productData.get('Competitor_2_URL__c');
            }

            if (productData.containsKey('Competitor_3__c')) {
                newProduct.Competitor_3__c = (String) productData.get('Competitor_3__c');
            }
            if (productData.containsKey('Competitor_3_Market_Value__c')) {
                newProduct.Competitor_3_Market_Value__c = (Decimal) productData.get('Competitor_3_Market_Value__c');
            }
            if (productData.containsKey('Competitor_3_URL__c')) {
                newProduct.Competitor_3_URL__c = (String) productData.get('Competitor_3_URL__c');
            }

            // Set supplier fields
            if (productData.containsKey('Supplier_1_Name__c')) {
                newProduct.Supplier_1_Name__c = (String) productData.get('Supplier_1_Name__c');
            }
            if (productData.containsKey('Supplier_1_Price__c')) {
                newProduct.Supplier_1_Price__c = (Decimal) productData.get('Supplier_1_Price__c');
            }
            if (productData.containsKey('Supplier_1_URL__c')) {
                newProduct.Supplier_1_URL__c = (String) productData.get('Supplier_1_URL__c');
            }

            if (productData.containsKey('Supplier_2_Name__c')) {
                newProduct.Supplier_2_Name__c = (String) productData.get('Supplier_2_Name__c');
            }
            if (productData.containsKey('Supplier_2_Price__c')) {
                newProduct.Supplier_2_Price__c = (Decimal) productData.get('Supplier_2_Price__c');
            }
            if (productData.containsKey('Supplier_2_URL__c')) {
                newProduct.Supplier_2_URL__c = (String) productData.get('Supplier_2_URL__c');
            }

            // Set delivery fields
            if (productData.containsKey('Delivery_Partner__c')) {
                newProduct.Delivery_Partner__c = (String) productData.get('Delivery_Partner__c');
            }
            if (productData.containsKey('Delivery_Cost__c')) {
                newProduct.Delivery_Cost__c = (Decimal) productData.get('Delivery_Cost__c');
            }
            if (productData.containsKey('Regional_Delivery_Cost__c')) {
                newProduct.Regional_Delivery_Cost__c = (Decimal) productData.get('Regional_Delivery_Cost__c');
            }

            insert newProduct;

            response.put('success', true);
            response.put('message', 'Product created successfully');
            response.put('productId', newProduct.Id);

        } catch (DmlException e) {
            response.put('success', false);
            response.put('message', 'Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    @RemoteAction
    public static Map<String, Object> setManualDisable(String recordId, Boolean disableValue) {
        Map<String, Object> response = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();

        try {
            // Input validation
            if (String.isBlank(recordId)) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Validate ID format
            try {
                Id validId = Id.valueOf(recordId);
            } catch (Exception e) {
                response.put('success', false);
                response.put('message', 'Invalid Record ID format');
                return response;
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Check FLS for Manual_Disable__c and Manual_Enable__c fields
            if (!Schema.sObjectType.Product_Inventory__c.fields.Manual_Disable__c.isUpdateable() ||
                !Schema.sObjectType.Product_Inventory__c.fields.Manual_Enable__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            Product_Inventory__c product = [
                SELECT Id, Manual_Disable__c, Manual_Enable__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                                LIMIT 1
            ];
            product.Manual_Disable__c = disableValue;
            // When disabling, also uncheck Manual_Enable; when enabling, also uncheck Manual_Disable
            product.Manual_Enable__c = !disableValue;
            update product;

            response.put('success', true);
            response.put('message', disableValue ? 'Product disabled successfully' : 'Product enabled successfully');

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Insufficient permissions to update products');
        } catch (DmlException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    @RemoteAction
    public static Map<String, Object> getStats(Boolean filterWebsite, Boolean filterErrors,
                                                Boolean filterURLs, String category) {
        Map<String, Object> stats = new Map<String, Object>();

        try {
            // Check read access
            if (!Schema.sObjectType.Product_Inventory__c.isAccessible()) {
                throw new System.NoAccessException();
            }

            // Build base WHERE clause from active filters
            List<String> conditions = new List<String>();
            if (filterWebsite == true) {
                conditions.add('In_R4K_Website__c = true');
            }
            if (filterErrors == true) {
                conditions.add('Supplier_Error_Notes__c != null');
            }
            if (filterURLs == true) {
                conditions.add('((Competitor_1__c != null AND Competitor_1_URL__c = null) OR ' +
                              '(Competitor_2__c != null AND Competitor_2_URL__c = null) OR ' +
                              '(Competitor_3__c != null AND Competitor_3_URL__c = null) OR ' +
                              '(Supplier_1_Name__c != null AND Supplier_1_URL__c = null) OR ' +
                              '(Supplier_2_Name__c != null AND Supplier_2_URL__c = null))');
            }
            if (String.isNotBlank(category) && category != 'All') {
                if (category == 'Uncategorised') {
                    conditions.add('Category__c = null');
                } else {
                    conditions.add('Category__c = \'' + String.escapeSingleQuotes(category) + '\'');
                }
            }

            String baseWhere = conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');

            // Query all stats in a single pass for efficiency
            String mainQuery = 'SELECT Id, In_R4K_Website__c, Supplier_Error_Notes__c, Manual_Disable__c, Website_Drift__c, ' +
                'Cash_Price__c, Metro_Delivery_Cost_Inc_GST__c, ' +
                'Competitor_1__c, Competitor_1_URL__c, Competitor_2__c, Competitor_2_URL__c, ' +
                'Competitor_3__c, Competitor_3_URL__c, Supplier_1_Name__c, Supplier_1_URL__c, ' +
                'Supplier_2_Name__c, Supplier_2_URL__c, Supplier_1_Price__c, Supplier_2_Price__c, ' +
                'Competitor_1_Market_Value__c, Competitor_2_Market_Value__c, Competitor_3_Market_Value__c, ' +
                'Competitor_1_New_Market_Value__c, Competitor_2_New_Market_Value__c, Competitor_3_New_Market_Value__c ' +
                'FROM Product_Inventory__c' + baseWhere;

            // Initialize counters
            Integer totalProducts = 0;
            Integer websiteProducts = 0;
            Integer errorProducts = 0;
            Integer missingURLs = 0;
            Integer priceChanges = 0;
            Integer outOfStockProducts = 0;
            Integer websiteDriftProducts = 0;
            Integer varianceUnder5 = 0;
            Integer variance5to15 = 0;
            Integer variance15to25 = 0;
            Integer varianceOver25 = 0;
            Integer noVarianceData = 0;
            Integer marginBelowTarget = 0;
            Integer marginNearTarget = 0;
            Integer marginOnTarget = 0;
            Integer marginProducts = 0;
            Decimal marginTotal = 0;

            // Single pass through all filtered records
            for (Product_Inventory__c p : Database.query(mainQuery)) {
                totalProducts++;

                // Count website products
                if (p.In_R4K_Website__c == true) websiteProducts++;

                // Count error products
                if (p.Supplier_Error_Notes__c != null) errorProducts++;

                // Count out of stock (disabled) products
                if (p.Manual_Disable__c == true) outOfStockProducts++;

                // Count products where the observed website state contradicts Salesforce
                if (p.Website_Drift__c == true) websiteDriftProducts++;

                // Count missing URLs
                if ((p.Competitor_1__c != null && p.Competitor_1_URL__c == null) ||
                    (p.Competitor_2__c != null && p.Competitor_2_URL__c == null) ||
                    (p.Competitor_3__c != null && p.Competitor_3_URL__c == null) ||
                    (p.Supplier_1_Name__c != null && p.Supplier_1_URL__c == null) ||
                    (p.Supplier_2_Name__c != null && p.Supplier_2_URL__c == null)) {
                    missingURLs++;
                }

                // Count price discrepancies (>25% variance between Cash Price and Competitor/Supplier prices)
                // This matches the hasPriceDiscrepancy logic in InventoryWrapper.checkPriceDiscrepancy()
                Decimal cashPrice = p.Cash_Price__c;
                if (cashPrice != null) {
                    Boolean hasDiscrepancy = false;

                    // Check Competitor 1
                    if (p.Competitor_1_Market_Value__c != null && p.Competitor_1_Market_Value__c > 0) {
                        Decimal variance = ((cashPrice - p.Competitor_1_Market_Value__c) / p.Competitor_1_Market_Value__c) * 100;
                        if (variance > 25) hasDiscrepancy = true;
                    }
                    // Check Competitor 2
                    if (!hasDiscrepancy && p.Competitor_2_Market_Value__c != null && p.Competitor_2_Market_Value__c > 0) {
                        Decimal variance = ((cashPrice - p.Competitor_2_Market_Value__c) / p.Competitor_2_Market_Value__c) * 100;
                        if (variance > 25) hasDiscrepancy = true;
                    }
                    // Check Competitor 3
                    if (!hasDiscrepancy && p.Competitor_3_Market_Value__c != null && p.Competitor_3_Market_Value__c > 0) {
                        Decimal variance = ((cashPrice - p.Competitor_3_Market_Value__c) / p.Competitor_3_Market_Value__c) * 100;
                        if (variance > 25) hasDiscrepancy = true;
                    }
                    // Check Supplier 1
                    if (!hasDiscrepancy && p.Supplier_1_Price__c != null && p.Supplier_1_Price__c > 0) {
                        Decimal variance = ((cashPrice - p.Supplier_1_Price__c) / p.Supplier_1_Price__c) * 100;
                        if (variance > 25) hasDiscrepancy = true;
                    }
                    // Check Supplier 2
                    if (!hasDiscrepancy && p.Supplier_2_Price__c != null && p.Supplier_2_Price__c > 0) {
                        Decimal variance = ((cashPrice - p.Supplier_2_Price__c) / p.Supplier_2_Price__c) * 100;
                        if (variance > 25) hasDiscrepancy = true;
                    }

                    if (hasDiscrepancy) priceChanges++;
                }

                // Calculate variance bucket using centralized utilities
                Decimal variance = calcVariancePercent(getLowestSupplierPrice(p), getAverageCompetitorPrice(p));
                String bucket = getVarianceRangeBucket(variance);

                if (bucket == 'under5') varianceUnder5++;
                else if (bucket == '5to15') variance5to15++;
                else if (bucket == '15to25') variance15to25++;
                else if (bucket == 'over25') varianceOver25++;
                else noVarianceData++;

                // Margin against the KPI
                Decimal margin = calcMarginPercent(p);
                String marginBand = getMarginBand(margin);
                if (margin != null) {
                    marginProducts++;
                    marginTotal += margin;
                }
                if (marginBand == 'below') marginBelowTarget++;
                else if (marginBand == 'near') marginNearTarget++;
                else if (marginBand == 'onTarget') marginOnTarget++;
            }

            stats.put('totalProducts', totalProducts);
            stats.put('websiteProducts', websiteProducts);
            stats.put('errorProducts', errorProducts);
            stats.put('missingURLs', missingURLs);
            stats.put('priceChanges', priceChanges);
            stats.put('outOfStockProducts', outOfStockProducts);
            stats.put('websiteDriftProducts', websiteDriftProducts);
            stats.put('varianceUnder5', varianceUnder5);
            stats.put('variance5to15', variance5to15);
            stats.put('variance15to25', variance15to25);
            stats.put('varianceOver25', varianceOver25);
            stats.put('noVarianceData', noVarianceData);
            stats.put('marginBelowTarget', marginBelowTarget);
            stats.put('marginNearTarget', marginNearTarget);
            stats.put('marginOnTarget', marginOnTarget);
            stats.put('marginProducts', marginProducts);
            stats.put('averageMargin', marginProducts > 0 ? (marginTotal / marginProducts).setScale(1) : null);
            stats.put('success', true);

        } catch (System.NoAccessException e) {
            stats.put('success', false);
            stats.put('message', 'Insufficient permissions to access product data');
        } catch (Exception e) {
            stats.put('success', false);
            stats.put('message', 'Error: ' + e.getMessage());
        }

        return stats;
    }

    @RemoteAction
    public static Map<String, Object> filterByTile(String tileType) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            // Validate input to prevent injection
            Set<String> validTiles = new Set<String>{'all', 'website', 'errors', 'urls', 'price', 'outOfStock', 'websiteDrift'};
            if (!validTiles.contains(tileType)) {
                response.put('success', false);
                response.put('message', 'Invalid tile type');
                return response;
            }

            response.put('success', true);
            response.put('filterType', tileType);

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    @RemoteAction
    public static String exportProducts(String searchTerm, Boolean filterWebsite, Boolean filterErrors, Boolean filterURLs, Boolean filterPrice) {
        try {
            // Check read access
            if (!Schema.sObjectType.Product_Inventory__c.isAccessible()) {
                return 'Error: Insufficient permissions to access product data';
            }

            // Build query with filters
            String query = 'SELECT Id, Name, ProductCode__c, Website_Product_Id__c, Manufacturer_Name__c, ' +
                'Cash_Price__c, RRP__c, Metro_Delivery_Cost_Inc_GST__c, ' +
                'Competitor_1__c, Competitor_1_URL__c, Competitor_1_Market_Value__c, ' +
                'Competitor_2__c, Competitor_2_URL__c, Competitor_2_Market_Value__c, ' +
                'Competitor_3__c, Competitor_3_URL__c, Competitor_3_Market_Value__c, ' +
                'Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c, ' +
                'Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c, ' +
                'Supplier_Error_Notes__c, In_R4K_Website__c, Manual_Disable__c ' +
                'FROM Product_Inventory__c';

            // Build WHERE clause with input sanitization
            List<String> conditions = new List<String>();

            if (String.isNotBlank(searchTerm)) {
                // Sanitize search term: allow alphanumeric, spaces, hyphens, and periods
                String sanitizedSearch = searchTerm.replaceAll('[^a-zA-Z0-9\\s\\-\\.]', '');
                if (String.isNotBlank(sanitizedSearch)) {
                    String escapedSearch = String.escapeSingleQuotes(sanitizedSearch);
                    List<String> searchConditions = new List<String>();

                    // Text field searches - include ProductCode and Website_Product_Id
                    searchConditions.add('Name LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('ProductName__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('ProductCode__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Website_Product_Id__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Supplier_1_Name__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Supplier_2_Name__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Competitor_1__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Competitor_2__c LIKE \'%' + escapedSearch + '%\'');
                    searchConditions.add('Competitor_3__c LIKE \'%' + escapedSearch + '%\'');

                    // Check if search term is a valid number for price searches
                    try {
                        Decimal searchPrice = Decimal.valueOf(sanitizedSearch.trim());
                        Decimal lowerBound = searchPrice - 1;
                        Decimal upperBound = searchPrice + 1;
                        searchConditions.add('(Cash_Price__c >= ' + lowerBound + ' AND Cash_Price__c <= ' + upperBound + ')');
                        searchConditions.add('(RRP__c >= ' + lowerBound + ' AND RRP__c <= ' + upperBound + ')');
                    } catch (Exception e) {
                        // Not a number, skip price search
                    }

                    conditions.add('(' + String.join(searchConditions, ' OR ') + ')');
                }
            }

            if (filterWebsite == true) {
                conditions.add('In_R4K_Website__c = true');
            }

            if (filterErrors == true) {
                conditions.add('Supplier_Error_Notes__c != null');
            }

            if (filterURLs == true) {
                conditions.add('((Competitor_1__c != null AND Competitor_1_URL__c = null) OR ' +
                              '(Competitor_2__c != null AND Competitor_2_URL__c = null) OR ' +
                              '(Competitor_3__c != null AND Competitor_3_URL__c = null) OR ' +
                              '(Supplier_1_Name__c != null AND Supplier_1_URL__c = null) OR ' +
                              '(Supplier_2_Name__c != null AND Supplier_2_URL__c = null))');
            }

            if (!conditions.isEmpty()) {
                query += ' WHERE ' + String.join(conditions, ' AND ');
            }

            query += ' ORDER BY Name ASC LIMIT 10000';

            List<Product_Inventory__c> records = Database.query(query);

            // Build CSV
            List<String> csvRows = new List<String>();

            // Header row
            csvRows.add('"Product Name","Status","Cash Price","RRP","Margin %",' +
                       '"Competitor 1","Comp 1 Price","Comp 1 URL",' +
                       '"Competitor 2","Comp 2 Price","Comp 2 URL",' +
                       '"Competitor 3","Comp 3 Price","Comp 3 URL",' +
                       '"Supplier 1","Supp 1 Price","Supp 1 URL",' +
                       '"Supplier 2","Supp 2 Price","Supp 2 URL",' +
                       '"On Website","Disabled","Error Notes"');

            // Data rows
            for (Product_Inventory__c record : records) {
                InventoryWrapper wrapper = new InventoryWrapper(record, true);

                // Skip if price discrepancy filter is on and this doesn't match
                if (filterPrice && !wrapper.hasCompetitorPriceChange) {
                    continue;
                }

                String status = 'OK';
                if (wrapper.hasCompetitorPriceChange) status = 'Price Alert';
                else if (wrapper.hasMissingURL) status = 'Missing URL';
                else if (wrapper.hasSupplierError) status = 'Has Note';

                csvRows.add(
                    escapeCsv(record.Name) + ',' +
                    escapeCsv(status) + ',' +
                    escapeCsv(formatCurrency(record.Cash_Price__c)) + ',' +
                    escapeCsv(formatCurrency(record.RRP__c)) + ',' +
                    escapeCsv(wrapper.marginDisplay) + ',' +
                    escapeCsv(record.Competitor_1__c) + ',' +
                    escapeCsv(formatCurrency(record.Competitor_1_Market_Value__c)) + ',' +
                    escapeCsv(record.Competitor_1_URL__c) + ',' +
                    escapeCsv(record.Competitor_2__c) + ',' +
                    escapeCsv(formatCurrency(record.Competitor_2_Market_Value__c)) + ',' +
                    escapeCsv(record.Competitor_2_URL__c) + ',' +
                    escapeCsv(record.Competitor_3__c) + ',' +
                    escapeCsv(formatCurrency(record.Competitor_3_Market_Value__c)) + ',' +
                    escapeCsv(record.Competitor_3_URL__c) + ',' +
                    escapeCsv(record.Supplier_1_Name__c) + ',' +
                    escapeCsv(formatCurrency(record.Supplier_1_Price__c)) + ',' +
                    escapeCsv(record.Supplier_1_URL__c) + ',' +
                    escapeCsv(record.Supplier_2_Name__c) + ',' +
                    escapeCsv(formatCurrency(record.Supplier_2_Price__c)) + ',' +
                    escapeCsv(record.Supplier_2_URL__c) + ',' +
                    escapeCsv(record.In_R4K_Website__c ? 'Yes' : 'No') + ',' +
                    escapeCsv(record.Manual_Disable__c ? 'Yes' : 'No') + ',' +
                    escapeCsv(record.Supplier_Error_Notes__c)
                );
            }

            return String.join(csvRows, '\n');

        } catch (Exception e) {
            return 'Error: ' + e.getMessage();
        }
    }

    // Helper method to escape CSV values
    private static String escapeCsv(String value) {
        if (String.isBlank(value)) {
            return '""';
        }
        // Escape double quotes and wrap in quotes
        String escaped = '"' + value.replace('"', '""') + '"';
        return escaped;
    }

    // Helper method to format currency
    private static String formatCurrency(Decimal value) {
        if (value == null) {
            return '';
        }
        return '$' + value.setScale(2).format();
    }

    @RemoteAction
    public static String updatePrice(String recordId, Decimal newPrice, String competitorField) {
        Savepoint sp = Database.setSavepoint();

        try {
            // Input validation
            if (String.isBlank(recordId)) {
                return 'Error: Record ID is required';
            }

            try {
                Id validId = Id.valueOf(recordId);
            } catch (Exception e) {
                return 'Error: Invalid Record ID format';
            }

            // Validate competitorField input
            if (competitorField != 'competitor1' && competitorField != 'competitor2' && competitorField != 'competitor3') {
                return 'Error: Invalid competitor field specified';
            }

            // Validate decimal input
            if (newPrice != null && (newPrice < 0 || newPrice > 999999)) {
                return 'Error: Price must be between 0 and 999,999';
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                return 'Error: Insufficient permissions to update products';
            }

            Product_Inventory__c record = [
                SELECT Id,
                    Competitor_1_New_Market_Value__c,
                    Competitor_2_New_Market_Value__c,
                    Competitor_3_New_Market_Value__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                                LIMIT 1
            ];

            if (competitorField == 'competitor1') {
                record.Competitor_1_New_Market_Value__c = newPrice;
            } else if (competitorField == 'competitor2') {
                record.Competitor_2_New_Market_Value__c = newPrice;
            } else if (competitorField == 'competitor3') {
                record.Competitor_3_New_Market_Value__c = newPrice;
            }

            update record;
            return 'Success';
        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            return 'Error: Insufficient permissions';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'Error: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String putStockOnHold(String recordId, String notes) {
        Savepoint sp = Database.setSavepoint();

        try {
            // Input validation
            if (String.isBlank(recordId)) {
                return 'Error: Record ID is required';
            }

            try {
                Id validId = Id.valueOf(recordId);
            } catch (Exception e) {
                return 'Error: Invalid Record ID format';
            }

            // Validate notes length (text area is 255 chars)
            if (String.isNotBlank(notes) && notes.length() > 255) {
                return 'Error: Notes must be 255 characters or less';
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                return 'Error: Insufficient permissions to update products';
            }

            // Check FLS for Supplier_Error_Notes__c field
            if (!Schema.sObjectType.Product_Inventory__c.fields.Supplier_Error_Notes__c.isUpdateable()) {
                return 'Error: Insufficient permissions to update Supplier Error Notes';
            }

            Product_Inventory__c record = [
                SELECT Id, Supplier_Error_Notes__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                                LIMIT 1
            ];
            record.Supplier_Error_Notes__c = notes;
            update record;
            return 'Success';
        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            return 'Error: Insufficient permissions';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'Error: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static Map<String, Object> saveProductDetails(Map<String, Object> updatedData) {
        Map<String, Object> response = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();

        try {
            String recordId = (String) updatedData.get('Id');

            // Input validation
            if (String.isBlank(recordId)) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Validate ID format to prevent injection
            try {
                Id validId = Id.valueOf(recordId);
            } catch (Exception e) {
                response.put('success', false);
                response.put('message', 'Invalid Record ID format');
                return response;
            }

            // Check CRUD permissions before update
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Validate decimal inputs to prevent overflow
            if (updatedData.containsKey('RRP__c')) {
                Decimal rrp = (Decimal) updatedData.get('RRP__c');
                if (rrp != null && (rrp < 0 || rrp > 999999)) {
                    response.put('success', false);
                    response.put('message', 'RRP must be between 0 and 999,999');
                    return response;
                }
            }

            // Validate competitor names against blocked list (Big W, Office Works, Target)
            if (updatedData.containsKey('Competitor_1__c')) {
                String validationError = validateCompetitorName((String) updatedData.get('Competitor_1__c'));
                if (validationError != null) {
                    response.put('success', false);
                    response.put('message', validationError);
                    return response;
                }
            }
            if (updatedData.containsKey('Competitor_2__c')) {
                String validationError = validateCompetitorName((String) updatedData.get('Competitor_2__c'));
                if (validationError != null) {
                    response.put('success', false);
                    response.put('message', validationError);
                    return response;
                }
            }
            if (updatedData.containsKey('Competitor_3__c')) {
                String validationError = validateCompetitorName((String) updatedData.get('Competitor_3__c'));
                if (validationError != null) {
                    response.put('success', false);
                    response.put('message', validationError);
                    return response;
                }
            }

            // Query the existing record with security enforced
            Product_Inventory__c record = [
                SELECT Id, Name, Cash_Price__c, RRP__c, Invoice_Cost__c, Comments__c,
                    Competitor_1__c, Competitor_1_URL__c, Competitor_1_Market_Value__c,
                    Competitor_1_New_Market_Value__c, Competitor_1_Last_Updated__c,
                    Competitor_1_Google_Drive_URL__c, Competitor_1_URL_Notes__c,
                    Competitor_2__c, Competitor_2_URL__c, Competitor_2_Market_Value__c,
                    Competitor_2_New_Market_Value__c, Competitor_2_Last_Updated__c,
                    Competitor_2_Google_Drive_URL__c, Competitor_2_URL_Notes__c,
                    Competitor_3__c, Competitor_3_URL__c, Competitor_3_Market_Value__c,
                    Competitor_3_New_Market_Value__c, Competitor_3_Last_Updated__c,
                    Competitor_3_Google_Drive_URL__c, Competitor_3_URL_Notes__c,
                    Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c,
                    Supplier_1_Google_Drive_URL__c, Supplier_1_Last_Updated__c,
                    Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c,
                    Supplier_2_Google_Drive_URL__c, Supplier_2_Last_Updated__c,
                    Supplier_Error_Notes__c, In_R4K_Website__c, Manual_Disable__c,
                    Delivery_Partner__c, Delivery_Cost__c, Metro_Delivery_Cost_Inc_GST__c,
                    Regional_Delivery_Cost__c, Regional_Delivery_Cost_Inc_GST__c, LastModifiedDate
                FROM Product_Inventory__c
                WHERE Id = :recordId
                                LIMIT 1
            ];

            // Update fields from the map
            // Note: Cash_Price__c is a formula field and cannot be updated directly
            // If you need to update it, modify the underlying fields that the formula uses

            if (updatedData.containsKey('RRP__c')) {
                record.RRP__c = (Decimal) updatedData.get('RRP__c');
            }
            if (updatedData.containsKey('Invoice_Cost__c')) {
                record.Invoice_Cost__c = (Decimal) updatedData.get('Invoice_Cost__c');
            }
            if (updatedData.containsKey('Comments__c')) {
                record.Comments__c = (String) updatedData.get('Comments__c');
            }

            // Competitor 1
            if (updatedData.containsKey('Competitor_1__c')) {
                record.Competitor_1__c = (String) updatedData.get('Competitor_1__c');
            }
            if (updatedData.containsKey('Competitor_1_Market_Value__c')) {
                record.Competitor_1_Market_Value__c = (Decimal) updatedData.get('Competitor_1_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_1_New_Market_Value__c')) {
                record.Competitor_1_New_Market_Value__c = (Decimal) updatedData.get('Competitor_1_New_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_1_URL__c')) {
                record.Competitor_1_URL__c = (String) updatedData.get('Competitor_1_URL__c');
            }
            if (updatedData.containsKey('Competitor_1_URL_Notes__c')) {
                record.Competitor_1_URL_Notes__c = (String) updatedData.get('Competitor_1_URL_Notes__c');
            }

            // Competitor 2
            if (updatedData.containsKey('Competitor_2__c')) {
                record.Competitor_2__c = (String) updatedData.get('Competitor_2__c');
            }
            if (updatedData.containsKey('Competitor_2_Market_Value__c')) {
                record.Competitor_2_Market_Value__c = (Decimal) updatedData.get('Competitor_2_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_2_New_Market_Value__c')) {
                record.Competitor_2_New_Market_Value__c = (Decimal) updatedData.get('Competitor_2_New_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_2_URL__c')) {
                record.Competitor_2_URL__c = (String) updatedData.get('Competitor_2_URL__c');
            }
            if (updatedData.containsKey('Competitor_2_URL_Notes__c')) {
                record.Competitor_2_URL_Notes__c = (String) updatedData.get('Competitor_2_URL_Notes__c');
            }

            // Competitor 3
            if (updatedData.containsKey('Competitor_3__c')) {
                record.Competitor_3__c = (String) updatedData.get('Competitor_3__c');
            }
            if (updatedData.containsKey('Competitor_3_Market_Value__c')) {
                record.Competitor_3_Market_Value__c = (Decimal) updatedData.get('Competitor_3_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_3_New_Market_Value__c')) {
                record.Competitor_3_New_Market_Value__c = (Decimal) updatedData.get('Competitor_3_New_Market_Value__c');
            }
            if (updatedData.containsKey('Competitor_3_URL__c')) {
                record.Competitor_3_URL__c = (String) updatedData.get('Competitor_3_URL__c');
            }
            if (updatedData.containsKey('Competitor_3_URL_Notes__c')) {
                record.Competitor_3_URL_Notes__c = (String) updatedData.get('Competitor_3_URL_Notes__c');
            }

            // Supplier 1
            if (updatedData.containsKey('Supplier_1_Name__c')) {
                record.Supplier_1_Name__c = (String) updatedData.get('Supplier_1_Name__c');
            }
            if (updatedData.containsKey('Supplier_1_Price__c')) {
                record.Supplier_1_Price__c = (Decimal) updatedData.get('Supplier_1_Price__c');
            }
            if (updatedData.containsKey('Supplier_1_URL__c')) {
                record.Supplier_1_URL__c = (String) updatedData.get('Supplier_1_URL__c');
            }

            // Supplier 2
            if (updatedData.containsKey('Supplier_2_Name__c')) {
                record.Supplier_2_Name__c = (String) updatedData.get('Supplier_2_Name__c');
            }
            if (updatedData.containsKey('Supplier_2_Price__c')) {
                record.Supplier_2_Price__c = (Decimal) updatedData.get('Supplier_2_Price__c');
            }
            if (updatedData.containsKey('Supplier_2_URL__c')) {
                record.Supplier_2_URL__c = (String) updatedData.get('Supplier_2_URL__c');
            }

            // Delivery fields
            if (updatedData.containsKey('Delivery_Partner__c')) {
                record.Delivery_Partner__c = (String) updatedData.get('Delivery_Partner__c');
            }
            if (updatedData.containsKey('Delivery_Cost__c')) {
                record.Delivery_Cost__c = (Decimal) updatedData.get('Delivery_Cost__c');
            }
            if (updatedData.containsKey('Regional_Delivery_Cost__c')) {
                record.Regional_Delivery_Cost__c = (Decimal) updatedData.get('Regional_Delivery_Cost__c');
            }
            if (updatedData.containsKey('Supplier_Error_Notes__c')) {
                record.Supplier_Error_Notes__c = (String) updatedData.get('Supplier_Error_Notes__c');
            }

            // Perform the update
            update record;

            // Return success with updated record
            response.put('success', true);
            response.put('message', 'Record updated successfully');
            response.put('record', record);

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Insufficient permissions to update products');
        } catch (DmlException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    // Bulk update website price - requests price update for selected products
    public PageReference bulkUpdateWebsite() {
        Savepoint sp = Database.setSavepoint();

        try {
            // Validate input
            if (String.isBlank(selectedProductIds)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No products selected'));
                return null;
            }

            // Parse selected IDs
            List<String> idList = selectedProductIds.split(',');
            Set<Id> productIds = new Set<Id>();

            for (String idStr : idList) {
                if (String.isNotBlank(idStr)) {
                    try {
                        productIds.add(Id.valueOf(idStr.trim()));
                    } catch (Exception e) {
                        // Skip invalid IDs
                        continue;
                    }
                }
            }

            if (productIds.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No valid products selected'));
                return null;
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Check FLS for Website_Update_Requested_Date__c field
            if (!Schema.sObjectType.Product_Inventory__c.fields.Website_Update_Requested_Date__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Query and update products - set Website_Update_Requested_Date__c to current date/time
            List<Product_Inventory__c> productsToUpdate = [
                SELECT Id, Website_Update_Requested_Date__c
                FROM Product_Inventory__c
                WHERE Id IN :productIds
            ];

            DateTime now = DateTime.now();
            for (Product_Inventory__c product : productsToUpdate) {
                product.Website_Update_Requested_Date__c = now;
            }

            update productsToUpdate;

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Successfully requested website price update for ' + productsToUpdate.size() + ' product(s)'
            ));

            // Clear cache and reset timestamp to force re-query
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0; // Reset to force cache rebuild
            selectedProductIds = '';

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Insufficient permissions to update products'
            ));
        } catch (DmlException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error updating products: ' + e.getDmlMessage(0)
            ));
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error: ' + e.getMessage()
            ));
        }

        return null;
    }

    // Bulk mark products as out of stock
    public PageReference bulkOutOfStock() {
        Savepoint sp = Database.setSavepoint();

        try {
            // Validate input
            if (String.isBlank(selectedProductIds)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No products selected'));
                return null;
            }

            // Parse selected IDs
            List<String> idList = selectedProductIds.split(',');
            Set<Id> productIds = new Set<Id>();

            for (String idStr : idList) {
                if (String.isNotBlank(idStr)) {
                    try {
                        productIds.add(Id.valueOf(idStr.trim()));
                    } catch (Exception e) {
                        // Skip invalid IDs
                        continue;
                    }
                }
            }

            if (productIds.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No valid products selected'));
                return null;
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Check FLS for Manual_Disable__c field
            if (!Schema.sObjectType.Product_Inventory__c.fields.Manual_Disable__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Query and update products
            List<Product_Inventory__c> productsToUpdate = [
                SELECT Id, Manual_Disable__c
                FROM Product_Inventory__c
                WHERE Id IN :productIds
            ];

            for (Product_Inventory__c product : productsToUpdate) {
                product.Manual_Disable__c = true;
            }

            update productsToUpdate;

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                'Successfully marked ' + productsToUpdate.size() + ' product(s) as out of stock'
            ));

            // Clear cache and reset timestamp to force re-query
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0; // Reset to force cache rebuild
            selectedProductIds = '';

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Insufficient permissions to update products'
            ));
        } catch (DmlException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error updating products: ' + e.getDmlMessage(0)
            ));
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error: ' + e.getMessage()
            ));
        }

        return null;
    }

    // Bulk copy supplier price (excl GST) to Invoice Cost
    public PageReference bulkCopySupplierToInvoiceCost() {
        Savepoint sp = Database.setSavepoint();

        try {
            // Validate input
            if (String.isBlank(selectedProductIds)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No products selected'));
                return null;
            }

            if (supplierForInvoiceCost == null || (supplierForInvoiceCost != 1 && supplierForInvoiceCost != 2)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Please select Supplier 1 or Supplier 2'));
                return null;
            }

            // Parse selected IDs
            List<String> idList = selectedProductIds.split(',');
            Set<Id> productIds = new Set<Id>();

            for (String idStr : idList) {
                if (String.isNotBlank(idStr)) {
                    try {
                        productIds.add(Id.valueOf(idStr.trim()));
                    } catch (Exception e) {
                        continue;
                    }
                }
            }

            if (productIds.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No valid products selected'));
                return null;
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Insufficient permissions'));
                return null;
            }

            // Query products with supplier price
            String priceField = supplierForInvoiceCost == 1 ? 'Supplier_1_Price__c' : 'Supplier_2_Price__c';
            List<Product_Inventory__c> productsToUpdate = [
                SELECT Id, Invoice_Cost__c, Supplier_1_Price__c, Supplier_2_Price__c
                FROM Product_Inventory__c
                WHERE Id IN :productIds
            ];

            Integer updatedCount = 0;
            Integer skippedCount = 0;

            for (Product_Inventory__c product : productsToUpdate) {
                Decimal supplierPrice = supplierForInvoiceCost == 1 ? product.Supplier_1_Price__c : product.Supplier_2_Price__c;

                if (supplierPrice != null && supplierPrice > 0) {
                    // Calculate price excluding GST (divide by 1.1 for 10% GST)
                    Decimal priceExclGST = supplierPrice / 1.1;
                    // Round to 2 decimal places
                    product.Invoice_Cost__c = priceExclGST.setScale(2, RoundingMode.HALF_UP);
                    updatedCount++;
                } else {
                    skippedCount++;
                }
            }

            if (updatedCount > 0) {
                update productsToUpdate;
            }

            String message = 'Updated Invoice Cost for ' + updatedCount + ' product(s) from Supplier ' + supplierForInvoiceCost + ' price (excl GST)';
            if (skippedCount > 0) {
                message += '. Skipped ' + skippedCount + ' product(s) with no supplier price.';
            }

            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.CONFIRM,
                message
            ));

            // Clear cache
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;
            selectedProductIds = '';

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Insufficient permissions'));
        } catch (DmlException e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getDmlMessage(0)));
        } catch (Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage()));
        }

        return null;
    }

    // Blocked competitor names - these retailers cannot be entered as competitors
    private static final Set<String> BLOCKED_COMPETITORS = new Set<String>{
        'big w', 'bigw', 'office works', 'officeworks', 'target'
    };

    /**
     * Validates competitor name against blocked list
     * @param name - The competitor name to validate
     * @return null if valid, error message if invalid
     */
    private static String validateCompetitorName(String name) {
        if (String.isBlank(name)) {
            return null; // Empty names are allowed
        }

        String normalizedName = name.toLowerCase().trim();

        for (String blocked : BLOCKED_COMPETITORS) {
            if (normalizedName.equals(blocked) || normalizedName.contains(blocked)) {
                return 'ERROR: "' + name + '" is not allowed as a competitor. Big W, Office Works, and Target cannot be entered as competitors.';
            }
        }

        return null; // Valid
    }

    @RemoteAction
    public static String saveCompetitor1(Id recordId, String name, Decimal price, Decimal newPrice, String url, String googleDrive, String urlNotes) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        // Validate competitor name against blocked list
        String validationError = validateCompetitorName(name);
        if (validationError != null) {
            return validationError;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            // Update Competitor Name, Market Value (Current Price), New Market Value, URLs, Notes, and Last Updated
            record.Competitor_1__c = name;
            record.Competitor_1_Market_Value__c = price;
            record.Competitor_1_New_Market_Value__c = newPrice;
            record.Competitor_1_URL__c = url;
            record.Competitor_1_Google_Drive_URL__c = googleDrive;
            record.Competitor_1_URL_Notes__c = urlNotes;
            record.Competitor_1_Last_Updated__c = System.now();
            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String saveCompetitor2(Id recordId, String name, Decimal price, Decimal newPrice, String url, String googleDrive, String urlNotes) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        // Validate competitor name against blocked list
        String validationError = validateCompetitorName(name);
        if (validationError != null) {
            return validationError;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            // Update Competitor Name, Market Value (Current Price), New Market Value, URLs, Notes, and Last Updated
            record.Competitor_2__c = name;
            record.Competitor_2_Market_Value__c = price;
            record.Competitor_2_New_Market_Value__c = newPrice;
            record.Competitor_2_URL__c = url;
            record.Competitor_2_Google_Drive_URL__c = googleDrive;
            record.Competitor_2_URL_Notes__c = urlNotes;
            record.Competitor_2_Last_Updated__c = System.now();
            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String saveCompetitor3(Id recordId, String name, Decimal price, Decimal newPrice, String url, String googleDrive, String urlNotes) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        // Validate competitor name against blocked list
        String validationError = validateCompetitorName(name);
        if (validationError != null) {
            return validationError;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            // Update Competitor Name, Market Value (Current Price), New Market Value, URLs, Notes, and Last Updated
            record.Competitor_3__c = name;
            record.Competitor_3_Market_Value__c = price;
            record.Competitor_3_New_Market_Value__c = newPrice;
            record.Competitor_3_URL__c = url;
            record.Competitor_3_Google_Drive_URL__c = googleDrive;
            record.Competitor_3_URL_Notes__c = urlNotes;
            record.Competitor_3_Last_Updated__c = System.now();
            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String saveSupplier1(Id recordId, String name, Decimal price, String url, String googleDrive, String errorNotes) {
        return saveSupplier1WithInvoiceCost(recordId, name, price, url, googleDrive, errorNotes, false);
    }

    @RemoteAction
    public static String saveSupplier1WithInvoiceCost(Id recordId, String name, Decimal price, String url, String googleDrive, String errorNotes, Boolean copyToInvoiceCost) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            record.Supplier_1_Name__c = name;
            record.Supplier_1_Price__c = price;
            record.Supplier_1_URL__c = url;
            record.Supplier_1_Google_Drive_URL__c = googleDrive;
            record.Supplier_1_Last_Updated__c = System.now();
            record.Supplier_Error_Notes__c = errorNotes;

            // Copy supplier price (excl GST) to Invoice Cost if checkbox is checked
            if (copyToInvoiceCost == true && price != null && price > 0) {
                Decimal priceExclGST = price / 1.1;
                record.Invoice_Cost__c = priceExclGST.setScale(2, RoundingMode.HALF_UP);
            }

            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String saveSupplier2(Id recordId, String name, Decimal price, String url, String googleDrive, String errorNotes) {
        return saveSupplier2WithInvoiceCost(recordId, name, price, url, googleDrive, errorNotes, false);
    }

    @RemoteAction
    public static String saveSupplier2WithInvoiceCost(Id recordId, String name, Decimal price, String url, String googleDrive, String errorNotes, Boolean copyToInvoiceCost) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            record.Supplier_2_Name__c = name;
            record.Supplier_2_Price__c = price;
            record.Supplier_2_URL__c = url;
            record.Supplier_2_Google_Drive_URL__c = googleDrive;
            record.Supplier_2_Last_Updated__c = System.now();
            record.Supplier_Error_Notes__c = errorNotes;

            // Copy supplier price (excl GST) to Invoice Cost if checkbox is checked
            if (copyToInvoiceCost == true && price != null && price > 0) {
                Decimal priceExclGST = price / 1.1;
                record.Invoice_Cost__c = priceExclGST.setScale(2, RoundingMode.HALF_UP);
            }

            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String saveDelivery(Id recordId, String partner, Decimal cost, Decimal metroCost, Decimal regionalCost, Decimal regionalCostGST) {
        if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
            return 'ERROR: Insufficient permissions';
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            record.Delivery_Partner__c = partner;
            record.Delivery_Cost__c = cost;
            record.Regional_Delivery_Cost__c = regionalCost;
            // Metro_Delivery_Cost_Inc_GST__c and Regional_Delivery_Cost_Inc_GST__c are formula fields (read-only)
            update record;
            return 'SUCCESS';
        } catch (Exception e) {
            Database.rollback(sp);
            return 'ERROR: ' + e.getMessage();
        }
    }

    /**
     * Remote Action: Update Website Price Request
     * Sets Website_Update_Requested_Date__c to current date/time
     */
    @RemoteAction
    public static Map<String, Object> updateWebsitePrice(Id recordId) {
        Map<String, Object> response = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();

        try {
            // Input validation
            if (recordId == null) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Validate ID format
            try {
                Id validId = Id.valueOf(String.valueOf(recordId));
            } catch (Exception e) {
                response.put('success', false);
                response.put('message', 'Invalid Record ID format');
                return response;
            }

            // Check CRUD permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            // Check FLS for Website_Update_Requested_Date__c field
            if (!Schema.sObjectType.Product_Inventory__c.fields.Website_Update_Requested_Date__c.isUpdateable()) {
                throw new System.NoAccessException();
            }

            Product_Inventory__c record = [SELECT Id FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1];
            record.Website_Update_Requested_Date__c = DateTime.now();

            update record;

            // Clear cache to ensure updated data is displayed
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            response.put('success', true);
            response.put('message', 'Website price update request submitted successfully');
            response.put('requestDateTime', record.Website_Update_Requested_Date__c.format('dd/MM/yyyy HH:mm:ss'));

        } catch (System.NoAccessException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Insufficient permissions to update website price request');
        } catch (DmlException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Mark product as out of stock - take it off sale on the website.
     *
     * Real time: WooCommerce is called first and Salesforce is only updated once the website
     * confirms. See reactivateProduct for why that ordering matters.
     */
    @RemoteAction
    public static Map<String, Object> markProductOutOfStock(Id recordId) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            // Validate recordId
            if (recordId == null) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Check permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            // Get the record
            Product_Inventory__c record = [
                SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Status__c,
                       In_R4K_Website__c, Website_Product_Id__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            if (String.isBlank(record.Website_Product_Id__c)) {
                response.put('success', false);
                response.put('message', 'Product "' + record.Name + '" is not mapped to a WooCommerce product '
                    + '(Website Product Id is blank), so it cannot be taken off sale on the website. '
                    + 'Map it first from the WooCommerce Product Mapping page.');
                return response;
            }

            // Callout first, before any DML in this transaction - see reactivateProduct for why.
            WooCommerceStockStatusService.Result wooResult =
                WooCommerceStockStatusService.apply(new List<Id>{ recordId }, 'outofstock');

            if (wooResult.succeeded == 0) {
                String detail = wooResult.messages.isEmpty()
                    ? 'the website did not confirm the change'
                    : String.join(wooResult.messages, '; ');
                response.put('success', false);
                response.put('message', 'Product "' + record.Name + '" was NOT taken off sale: ' + detail
                    + '. It is still being sold on the website and Salesforce has been left unchanged.');
                return response;
            }

            // The website confirmed stock_status=outofstock, so record the decision in Salesforce.
            record.Manual_Disable__c = true;
            record.Manual_Enable__c = false;
            update record;

            // Clear cache to ensure updated data is displayed
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            response.put('success', true);
            response.put('message', 'Product "' + record.Name + '" is off sale - the website confirmed it is out of stock.');
        } catch (DmlException e) {
            // The website change already succeeded, so do not imply nothing happened.
            response.put('success', false);
            response.put('message', 'The website was updated to out of stock, but saving the change in Salesforce '
                + 'failed: ' + e.getDmlMessage(0) + '. Please re-run this action.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Reactivate product - put it back on sale on the website.
     *
     * Runs in real time. WooCommerce is called FIRST and Salesforce is only updated once the
     * website confirms the change, so the message returned to the operator describes what actually
     * happened rather than what was queued. That ordering is also what makes a synchronous callout
     * legal: DML before a callout raises "You have uncommitted work pending", which is the sole
     * reason this used to run through @Future.
     *
     * Reactivation also stamps Website_Update_Requested_Date__c, which makes
     * ProductInventoryTrigger enqueue WooCommerceSyncBatch to push the current prices, APRs and
     * comparison rates. Without it the product would go back on sale carrying whatever prices the
     * website last received, which for a product parked for months is not what Salesforce holds.
     */
    @RemoteAction
    public static Map<String, Object> reactivateProduct(Id recordId) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            // Validate recordId
            if (recordId == null) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Check permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            // Get the record
            Product_Inventory__c record = [
                SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Status__c,
                       In_R4K_Website__c, Website_Product_Id__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            // Check if product is actually disabled
            if (record.Manual_Disable__c != true) {
                response.put('success', false);
                response.put('message', 'Product "' + record.Name + '" is already active');
                return response;
            }

            if (String.isBlank(record.Website_Product_Id__c)) {
                response.put('success', false);
                response.put('message', 'Product "' + record.Name + '" is not mapped to a WooCommerce product '
                    + '(Website Product Id is blank), so it cannot be reactivated on the website. '
                    + 'Map it first from the WooCommerce Product Mapping page.');
                return response;
            }

            // Callout first, before any DML in this transaction.
            WooCommerceStockStatusService.Result wooResult =
                WooCommerceStockStatusService.apply(new List<Id>{ recordId }, 'instock');

            if (wooResult.succeeded == 0) {
                String detail = wooResult.messages.isEmpty()
                    ? 'the website did not confirm the change'
                    : String.join(wooResult.messages, '; ');
                response.put('success', false);
                response.put('message', 'Product "' + record.Name + '" was NOT reactivated: ' + detail
                    + '. Salesforce has been left unchanged.');
                return response;
            }

            // The website confirmed stock_status=instock, so record the decision in Salesforce.
            // Current pricing went out in the same call as the availability change, so there is
            // nothing further to request here.
            record.Manual_Disable__c = false;
            record.Manual_Enable__c = true;
            update record;

            // Clear cache to ensure updated data is displayed
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            String message = 'Product "' + record.Name + '" is back on sale - the website confirmed it is in stock. '
                + 'Current pricing is being pushed now.';
            if (record.Website_Status__c != 'Published') {
                message += ' Note: its Website Status is "' + record.Website_Status__c
                    + '", so the product page is still hidden. Use "Enable on Website" to publish the page.';
            }

            response.put('success', true);
            response.put('message', message);
        } catch (DmlException e) {
            // The website change already succeeded at this point, so say so rather than implying
            // nothing happened - the two systems are briefly out of step and that must be visible.
            response.put('success', false);
            response.put('message', 'The website was updated to in stock, but saving the change in Salesforce failed: '
                + e.getDmlMessage(0) + '. Please re-run this reactivation.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Bulk reactivate products - put them back on sale on the website.
     *
     * Real time, like the single-record version: one POST /products/batch call covers up to 100
     * products, and only those the website confirms are marked active in Salesforce. The previous
     * implementation enqueued one @Future per product inside a loop, so a selection of 51 threw an
     * uncatchable "Too many future calls: 51" that rolled back the whole transaction.
     *
     * Selections larger than one batch fall back to the chained Queueable, because a long run of
     * sequential batch writes can exceed the 120-second cumulative callout timeout.
     */
    @RemoteAction
    public static Map<String, Object> bulkReactivateProducts(List<Id> recordIds) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            // Validate input
            if (recordIds == null || recordIds.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No products selected');
                return response;
            }

            // Check permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            // Get the records that are currently disabled
            List<Product_Inventory__c> records = [
                SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Product_Id__c
                FROM Product_Inventory__c
                WHERE Id IN :recordIds AND Manual_Disable__c = true
            ];

            if (records.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No disabled products found in the selection');
                return response;
            }

            List<Id> mappedIds = new List<Id>();
            Integer unmapped = 0;
            for (Product_Inventory__c record : records) {
                if (String.isBlank(record.Website_Product_Id__c)) {
                    unmapped++;
                } else {
                    mappedIds.add(record.Id);
                }
            }

            if (mappedIds.isEmpty()) {
                response.put('success', false);
                response.put('message', 'None of the selected products are mapped to a WooCommerce product, '
                    + 'so none can be reactivated on the website.');
                return response;
            }

            // Larger than one batch: hand off to the chained Queueable. No DML first - the
            // Salesforce flags are flipped by the job as each chunk is confirmed.
            if (mappedIds.size() > WooCommerceStockStatusService.CHUNK_SIZE) {
                WooCommerceStockStatusService.applyAsync(mappedIds, 'instock');
                response.put('success', true);
                response.put('message', mappedIds.size() + ' products queued for reactivation in batches of '
                    + WooCommerceStockStatusService.CHUNK_SIZE + '. Refresh in a few minutes to see confirmed results.');
                return response;
            }

            // Callout first, before any DML in this transaction.
            WooCommerceStockStatusService.Result wooResult =
                WooCommerceStockStatusService.apply(mappedIds, 'instock');

            if (wooResult.succeededIds.isEmpty()) {
                String detail = wooResult.messages.isEmpty()
                    ? 'the website did not confirm any of the changes'
                    : String.join(wooResult.messages, '; ');
                response.put('success', false);
                response.put('message', 'No products were reactivated: ' + detail
                    + '. Salesforce has been left unchanged.');
                return response;
            }

            // Only flip the products the website actually confirmed. Current pricing went out in
            // the same call as the availability change.
            List<Product_Inventory__c> confirmed = new List<Product_Inventory__c>();
            for (Product_Inventory__c record : records) {
                if (wooResult.succeededIds.contains(record.Id)) {
                    record.Manual_Disable__c = false;
                    record.Manual_Enable__c = true;
                    confirmed.add(record);
                }
            }
            update confirmed;

            // Clear cache
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            String message = confirmed.size() + ' product' + (confirmed.size() > 1 ? 's' : '')
                + ' back on sale - confirmed in stock by the website. Current pricing is being pushed now.';
            if (wooResult.failed > 0) {
                message += ' ' + wooResult.failed + ' failed and were left disabled.';
            }
            if (unmapped > 0) {
                message += ' ' + unmapped + ' skipped - not mapped to a WooCommerce product.';
            }
            if (wooResult.skipped > 0) {
                message += ' ' + wooResult.skipped + ' skipped - see the Website Update Status on each record.';
            }

            response.put('success', true);
            response.put('message', message);
        } catch (DmlException e) {
            response.put('success', false);
            response.put('message', 'The website was updated, but saving the change in Salesforce failed: '
                + e.getDmlMessage(0) + '. Please re-run this reactivation.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Disable product from website
     * Sets In_R4K_Website__c to false
     */
    @RemoteAction
    public static Map<String, Object> disableProductFromWebsite(Id recordId) {
        Map<String, Object> response = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();

        try {
            // Validate recordId
            if (recordId == null) {
                response.put('success', false);
                response.put('message', 'Record ID is required');
                return response;
            }

            // Check permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            // Get the record
            Product_Inventory__c record = [
                SELECT Id, Name, In_R4K_Website__c, Website_Status__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            // Update the record - disable from website and set status to draft
            record.In_R4K_Website__c = false;
            record.Website_Status__c = 'Draft';
            update record;

            // Clear cache to ensure updated data is displayed
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            // Call WooCommerce integration to update product status to draft
            // This is a @Future method so it runs asynchronously
            // Wrap in try-catch to prevent WooCommerce issues from affecting Salesforce updates
            try {
                WooCommerceIntegration.updateProductStatusToDraft(recordId);
            } catch (Exception wooException) {
                System.debug('Warning: WooCommerce integration call failed: ' + wooException.getMessage());
                // Continue - Salesforce update was successful
            }

            response.put('success', true);
            response.put('message', 'Product "' + record.Name + '" has been disabled from website. WooCommerce status will be updated to draft shortly.');
        } catch (DmlException e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Database error: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Bulk mark products as out of stock - take them off sale on the website.
     *
     * Real time, and only the products the website confirms are marked disabled in Salesforce.
     * The previous implementation updated Salesforce first and then handed the raw caller-supplied
     * id list to a single @Future that spent two callouts per product, so it threw an uncatchable
     * "Too many callouts: 101" at product 51 - leaving the first 50 changed on the website, the
     * rest untouched, every record marked disabled in Salesforce, and no record of which was which.
     */
    @RemoteAction
    public static Map<String, Object> bulkMarkProductsOutOfStock(List<Id> recordIds) {
        Map<String, Object> response = new Map<String, Object>();

        try {
            // Validate recordIds
            if (recordIds == null || recordIds.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No products selected');
                return response;
            }

            // Check permissions
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            // Get the records
            List<Product_Inventory__c> records = [
                SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Product_Id__c
                FROM Product_Inventory__c
                WHERE Id IN :recordIds
            ];

            if (records.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No matching products found in the selection');
                return response;
            }

            List<Id> mappedIds = new List<Id>();
            Integer unmapped = 0;
            for (Product_Inventory__c record : records) {
                if (String.isBlank(record.Website_Product_Id__c)) {
                    unmapped++;
                } else {
                    mappedIds.add(record.Id);
                }
            }

            if (mappedIds.isEmpty()) {
                response.put('success', false);
                response.put('message', 'None of the selected products are mapped to a WooCommerce product, '
                    + 'so none can be taken off sale on the website.');
                return response;
            }

            if (mappedIds.size() > WooCommerceStockStatusService.CHUNK_SIZE) {
                WooCommerceStockStatusService.applyAsync(mappedIds, 'outofstock');
                response.put('success', true);
                response.put('message', mappedIds.size() + ' products queued to be taken off sale in batches of '
                    + WooCommerceStockStatusService.CHUNK_SIZE + '. Refresh in a few minutes to see confirmed results.');
                return response;
            }

            // Callout first, before any DML in this transaction.
            WooCommerceStockStatusService.Result wooResult =
                WooCommerceStockStatusService.apply(mappedIds, 'outofstock');

            if (wooResult.succeededIds.isEmpty()) {
                String detail = wooResult.messages.isEmpty()
                    ? 'the website did not confirm any of the changes'
                    : String.join(wooResult.messages, '; ');
                response.put('success', false);
                response.put('message', 'No products were taken off sale: ' + detail
                    + '. They are still being sold on the website and Salesforce has been left unchanged.');
                return response;
            }

            // Only flip the products the website actually confirmed.
            List<Product_Inventory__c> confirmed = new List<Product_Inventory__c>();
            for (Product_Inventory__c record : records) {
                if (wooResult.succeededIds.contains(record.Id)) {
                    record.Manual_Disable__c = true;
                    record.Manual_Enable__c = false;
                    confirmed.add(record);
                }
            }
            update confirmed;

            // Clear cache to ensure updated data is displayed
            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            String message = confirmed.size() + ' product' + (confirmed.size() > 1 ? 's' : '')
                + ' off sale - confirmed out of stock by the website.';
            if (wooResult.failed > 0) {
                message += ' ' + wooResult.failed + ' failed and are STILL being sold.';
            }
            if (unmapped > 0) {
                message += ' ' + unmapped + ' skipped - not mapped to a WooCommerce product.';
            }
            if (wooResult.skipped > 0) {
                message += ' ' + wooResult.skipped + ' skipped - see the Website Update Status on each record.';
            }

            response.put('success', true);
            response.put('message', message);
        } catch (DmlException e) {
            response.put('success', false);
            response.put('message', 'The website was updated, but saving the change in Salesforce failed: '
                + e.getDmlMessage(0) + '. Please re-run this action.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }

        return response;
    }

    /**
     * Get competitor data for focused edit modal
     */
    @RemoteAction
    public static Map<String, Object> getCompetitorData(Id recordId, Integer competitorNumber) {
        try {
            String query = 'SELECT Id, ';
            if (competitorNumber == 1) {
                query += 'Competitor_1__c, Competitor_1_Market_Value__c, Competitor_1_New_Market_Value__c, ' +
                        'Competitor_1_URL__c, Competitor_1_Google_Drive_URL__c, Competitor_1_URL_Notes__c, ' +
                        'Competitor_1_Last_Updated__c ';
            } else if (competitorNumber == 2) {
                query += 'Competitor_2__c, Competitor_2_Market_Value__c, Competitor_2_New_Market_Value__c, ' +
                        'Competitor_2_URL__c, Competitor_2_Google_Drive_URL__c, Competitor_2_URL_Notes__c, ' +
                        'Competitor_2_Last_Updated__c ';
            } else {
                query += 'Competitor_3__c, Competitor_3_Market_Value__c, Competitor_3_New_Market_Value__c, ' +
                        'Competitor_3_URL__c, Competitor_3_Google_Drive_URL__c, Competitor_3_URL_Notes__c, ' +
                        'Competitor_3_Last_Updated__c ';
            }
            query += 'FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1';

            Product_Inventory__c record = Database.query(query);
            Map<String, Object> result = new Map<String, Object>();

            if (competitorNumber == 1) {
                result.put('name', record.Competitor_1__c);
                result.put('price', record.Competitor_1_Market_Value__c);
                result.put('newPrice', record.Competitor_1_New_Market_Value__c);
                result.put('url', record.Competitor_1_URL__c);
                result.put('googleDrive', record.Competitor_1_Google_Drive_URL__c);
                result.put('urlNotes', record.Competitor_1_URL_Notes__c);
                result.put('lastUpdated', record.Competitor_1_Last_Updated__c);
            } else if (competitorNumber == 2) {
                result.put('name', record.Competitor_2__c);
                result.put('price', record.Competitor_2_Market_Value__c);
                result.put('newPrice', record.Competitor_2_New_Market_Value__c);
                result.put('url', record.Competitor_2_URL__c);
                result.put('googleDrive', record.Competitor_2_Google_Drive_URL__c);
                result.put('urlNotes', record.Competitor_2_URL_Notes__c);
                result.put('lastUpdated', record.Competitor_2_Last_Updated__c);
            } else {
                result.put('name', record.Competitor_3__c);
                result.put('price', record.Competitor_3_Market_Value__c);
                result.put('newPrice', record.Competitor_3_New_Market_Value__c);
                result.put('url', record.Competitor_3_URL__c);
                result.put('googleDrive', record.Competitor_3_Google_Drive_URL__c);
                result.put('urlNotes', record.Competitor_3_URL_Notes__c);
                result.put('lastUpdated', record.Competitor_3_Last_Updated__c);
            }

            result.put('success', true);
            return result;
        } catch (Exception e) {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('success', false);
            errorResult.put('error', e.getMessage());
            return errorResult;
        }
    }

    /**
     * Get supplier data for focused edit modal
     */
    @RemoteAction
    public static Map<String, Object> getSupplierData(Id recordId, Integer supplierNumber) {
        try {
            String query = 'SELECT Id, Supplier_Error_Notes__c, ';
            if (supplierNumber == 1) {
                query += 'Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c, ' +
                        'Supplier_1_Google_Drive_URL__c, Supplier_1_Last_Updated__c ';
            } else {
                query += 'Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c, ' +
                        'Supplier_2_Google_Drive_URL__c, Supplier_2_Last_Updated__c ';
            }
            query += 'FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1';

            Product_Inventory__c record = Database.query(query);
            Map<String, Object> result = new Map<String, Object>();

            if (supplierNumber == 1) {
                result.put('name', record.Supplier_1_Name__c);
                result.put('price', record.Supplier_1_Price__c);
                result.put('url', record.Supplier_1_URL__c);
                result.put('googleDrive', record.Supplier_1_Google_Drive_URL__c);
                result.put('lastUpdated', record.Supplier_1_Last_Updated__c);
            } else {
                result.put('name', record.Supplier_2_Name__c);
                result.put('price', record.Supplier_2_Price__c);
                result.put('url', record.Supplier_2_URL__c);
                result.put('googleDrive', record.Supplier_2_Google_Drive_URL__c);
                result.put('lastUpdated', record.Supplier_2_Last_Updated__c);
            }

            result.put('errorNotes', record.Supplier_Error_Notes__c);
            result.put('success', true);
            return result;
        } catch (Exception e) {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('success', false);
            errorResult.put('error', e.getMessage());
            return errorResult;
        }
    }

    /**
     * Get delivery data for focused edit modal
     */
    @RemoteAction
    public static Map<String, Object> getDeliveryData(Id recordId) {
        try {
            Product_Inventory__c record = [
                SELECT Id, Delivery_Partner__c, Delivery_Cost__c, Metro_Delivery_Cost_Inc_GST__c,
                       Regional_Delivery_Cost__c, Regional_Delivery_Cost_Inc_GST__c
                FROM Product_Inventory__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            Map<String, Object> result = new Map<String, Object>();
            result.put('partner', record.Delivery_Partner__c);
            result.put('cost', record.Delivery_Cost__c);
            result.put('metroCost', record.Metro_Delivery_Cost_Inc_GST__c);
            result.put('regionalCost', record.Regional_Delivery_Cost__c);
            result.put('regionalCostGST', record.Regional_Delivery_Cost_Inc_GST__c);
            result.put('success', true);
            return result;
        } catch (Exception e) {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('success', false);
            errorResult.put('error', e.getMessage());
            return errorResult;
        }
    }

    // Optimized wrapper with lazy evaluation
    public class InventoryWrapper {
        public Product_Inventory__c record { get; set; }
        public Boolean hasPriceDiscrepancy { get; set; }
        public Boolean hasMissingURL { get; set; }
        public Boolean hasSupplierError { get; set; }
        public String discrepancyDetails { get; set; }
        public String priceAlertTooltip { get; set; }
        public String missingURLTooltip { get; set; }
        public String noteTooltip { get; set; }
        private Boolean statusEvaluated { get; set; }

        // Price change percentages
        public String comp1PriceChange { get; set; }
        public String comp2PriceChange { get; set; }
        public String comp3PriceChange { get; set; }
        public Boolean comp1HasChange { get; set; }
        public Boolean comp2HasChange { get; set; }
        public Boolean comp3HasChange { get; set; }
        public Boolean hasCompetitorPriceChange { get; set; }
        public String priceChangeTooltip { get; set; }

        // Cash price variance
        public Decimal lowestSupplierPrice { get; set; }
        public Decimal averageCompetitorPrice { get; set; }
        public Decimal priceVariancePercent { get; set; }
        public String priceVarianceDisplay { get; set; }
        public Boolean hasVariance { get; set; }
        public Boolean isVarianceGood { get; set; }
        public Decimal marginPercent { get; set; }
        public String marginDisplay { get; set; }
        public String marginBand { get; set; } // below / near / onTarget / noMargin

        public InventoryWrapper(Product_Inventory__c rec, Boolean evaluateNow) {
            this.record = rec;
            this.statusEvaluated = false;

            if (evaluateNow) {
                evaluateStatus();
            } else {
                // Set default values for lazy evaluation
                this.hasPriceDiscrepancy = false;
                this.hasMissingURL = false;
                this.hasSupplierError = false;
                this.discrepancyDetails = '';
                this.priceAlertTooltip = '';
                this.missingURLTooltip = '';
                this.noteTooltip = '';
                this.comp1PriceChange = '';
                this.comp2PriceChange = '';
                this.comp3PriceChange = '';
                this.comp1HasChange = false;
                this.comp2HasChange = false;
                this.comp3HasChange = false;
                this.hasCompetitorPriceChange = false;
                this.priceChangeTooltip = '';
                this.lowestSupplierPrice = null;
                this.averageCompetitorPrice = null;
                this.priceVariancePercent = null;
                this.priceVarianceDisplay = '';
                this.hasVariance = false;
                this.isVarianceGood = false;
                this.marginPercent = null;
                this.marginDisplay = '';
                this.marginBand = 'noMargin';
            }
        }

        // Evaluate status only when needed
        public void evaluateStatus() {
            if (statusEvaluated) return;

            this.hasPriceDiscrepancy = false;
            this.hasMissingURL = false;
            this.hasSupplierError = false;
            this.discrepancyDetails = '';
            this.priceAlertTooltip = '';
            this.missingURLTooltip = '';
            this.noteTooltip = '';
            this.comp1PriceChange = '';
            this.comp2PriceChange = '';
            this.comp3PriceChange = '';
            this.comp1HasChange = false;
            this.comp2HasChange = false;
            this.comp3HasChange = false;
            this.hasCompetitorPriceChange = false;
            this.priceChangeTooltip = '';
            this.lowestSupplierPrice = null;
            this.averageCompetitorPrice = null;
            this.priceVariancePercent = null;
            this.priceVarianceDisplay = '';
            this.hasVariance = false;
            this.isVarianceGood = false;
            this.marginPercent = null;
            this.marginDisplay = '';
            this.marginBand = 'noMargin';

            checkDiscrepancies();
            calculatePriceChanges();
            calculatePriceVariance();
            buildTooltips();
            statusEvaluated = true;
        }

        private void checkDiscrepancies() {
            List<String> issues = new List<String>();

            // Check for price discrepancies with 25% threshold (optimized comparisons)
            Decimal cashPrice = record.Cash_Price__c;
            if (cashPrice != null) {
                checkPriceDiscrepancy(cashPrice, record.Competitor_1_Market_Value__c, 'Comp1', issues);
                checkPriceDiscrepancy(cashPrice, record.Competitor_2_Market_Value__c, 'Comp2', issues);
                checkPriceDiscrepancy(cashPrice, record.Competitor_3_Market_Value__c, 'Comp3', issues);
                checkPriceDiscrepancy(cashPrice, record.Supplier_1_Price__c, 'Supplier1', issues);
                checkPriceDiscrepancy(cashPrice, record.Supplier_2_Price__c, 'Supplier2', issues);
            }

            // Check for missing URLs (optimized checks)
            checkMissingURL(record.Competitor_1__c, record.Competitor_1_URL__c, 'Comp1', issues);
            checkMissingURL(record.Competitor_2__c, record.Competitor_2_URL__c, 'Comp2', issues);
            checkMissingURL(record.Competitor_3__c, record.Competitor_3_URL__c, 'Comp3', issues);
            checkMissingURL(record.Supplier_1_Name__c, record.Supplier_1_URL__c, 'Supplier1', issues);
            checkMissingURL(record.Supplier_2_Name__c, record.Supplier_2_URL__c, 'Supplier2', issues);

            // Check for supplier errors
            if (String.isNotBlank(record.Supplier_Error_Notes__c)) {
                hasSupplierError = true;
                issues.add('Supplier Error: ' + record.Supplier_Error_Notes__c.abbreviate(50));
            }

            discrepancyDetails = String.join(issues, '; ');
        }

        private void checkPriceDiscrepancy(Decimal cashPrice, Decimal compPrice, String compName, List<String> issues) {
            if (compPrice != null && compPrice > 0) {
                // Calculate percentage variance: ((cashPrice - compPrice) / compPrice) * 100
                Decimal variance = ((cashPrice - compPrice) / compPrice) * 100;

                // Flag if variance is more than 25% (cash price is more than 25% higher)
                if (variance > 25) {
                    hasPriceDiscrepancy = true;
                    issues.add(compName + ': $' + compPrice + ' (' + variance.setScale(1) + '% variance from Cash: $' + cashPrice + ')');
                }
            }
        }

        private void checkMissingURL(String name, String url, String type, List<String> issues) {
            if (String.isNotBlank(name) && String.isBlank(url)) {
                hasMissingURL = true;
                issues.add('Missing ' + type + ' URL');
            }
        }

        // Calculate price changes between current and new market values
        private void calculatePriceChanges() {
            List<String> priceChangeDetails = new List<String>();

            // Competitor 1
            if (record.Competitor_1_Market_Value__c != null && record.Competitor_1_New_Market_Value__c != null) {
                Decimal oldPrice = record.Competitor_1_Market_Value__c;
                Decimal newPrice = record.Competitor_1_New_Market_Value__c;
                if (oldPrice != newPrice && oldPrice != 0) {
                    Decimal percentChange = ((newPrice - oldPrice) / oldPrice) * 100;
                    comp1HasChange = true;
                    comp1PriceChange = (percentChange >= 0 ? '+' : '') + percentChange.setScale(1) + '%';
                    String compName = String.isNotBlank(record.Competitor_1__c) ? record.Competitor_1__c : 'Competitor 1';
                    priceChangeDetails.add(compName + ': $' + oldPrice.setScale(2) + ' → $' + newPrice.setScale(2) + ' (' + comp1PriceChange + ')');
                }
            }

            // Competitor 2
            if (record.Competitor_2_Market_Value__c != null && record.Competitor_2_New_Market_Value__c != null) {
                Decimal oldPrice = record.Competitor_2_Market_Value__c;
                Decimal newPrice = record.Competitor_2_New_Market_Value__c;
                if (oldPrice != newPrice && oldPrice != 0) {
                    Decimal percentChange = ((newPrice - oldPrice) / oldPrice) * 100;
                    comp2HasChange = true;
                    comp2PriceChange = (percentChange >= 0 ? '+' : '') + percentChange.setScale(1) + '%';
                    String compName = String.isNotBlank(record.Competitor_2__c) ? record.Competitor_2__c : 'Competitor 2';
                    priceChangeDetails.add(compName + ': $' + oldPrice.setScale(2) + ' → $' + newPrice.setScale(2) + ' (' + comp2PriceChange + ')');
                }
            }

            // Competitor 3
            if (record.Competitor_3_Market_Value__c != null && record.Competitor_3_New_Market_Value__c != null) {
                Decimal oldPrice = record.Competitor_3_Market_Value__c;
                Decimal newPrice = record.Competitor_3_New_Market_Value__c;
                if (oldPrice != newPrice && oldPrice != 0) {
                    Decimal percentChange = ((newPrice - oldPrice) / oldPrice) * 100;
                    comp3HasChange = true;
                    comp3PriceChange = (percentChange >= 0 ? '+' : '') + percentChange.setScale(1) + '%';
                    String compName = String.isNotBlank(record.Competitor_3__c) ? record.Competitor_3__c : 'Competitor 3';
                    priceChangeDetails.add(compName + ': $' + oldPrice.setScale(2) + ' → $' + newPrice.setScale(2) + ' (' + comp3PriceChange + ')');
                }
            }

            // Set overall flag and tooltip
            this.hasCompetitorPriceChange = comp1HasChange || comp2HasChange || comp3HasChange;
            if (!priceChangeDetails.isEmpty()) {
                this.priceChangeTooltip = 'Price Changes: ' + String.join(priceChangeDetails, ' | ');
            }
        }

        private void calculatePriceVariance() {
            // Use centralized utility methods for consistent calculation
            this.lowestSupplierPrice = getLowestSupplierPrice(record);
            this.averageCompetitorPrice = getAverageCompetitorPrice(record);
            this.priceVariancePercent = calcVariancePercent(lowestSupplierPrice, averageCompetitorPrice);
            this.hasVariance = (priceVariancePercent != null);

            if (hasVariance) {
                this.isVarianceGood = priceVariancePercent > 0; // Positive = supplier cheaper
                String sign = priceVariancePercent >= 0 ? '+' : '';
                this.priceVarianceDisplay = sign + priceVariancePercent.setScale(1) + '%';
            }

            this.marginPercent = calcMarginPercent(record);
            this.marginBand = getMarginBand(marginPercent);
            this.marginDisplay = marginPercent == null ? '' : marginPercent.setScale(1) + '%';
        }

        // Build detailed tooltips for each status badge
        private void buildTooltips() {
            List<String> priceIssues = new List<String>();
            List<String> urlIssues = new List<String>();

            Decimal cashPrice = record.Cash_Price__c;

            // Build Price Alert tooltip with specific competitor prices
            if (cashPrice != null) {
                if (record.Competitor_1_Market_Value__c != null && record.Competitor_1_Market_Value__c < cashPrice) {
                    String compName = String.isNotBlank(record.Competitor_1__c) ? record.Competitor_1__c : 'Competitor 1';
                    priceIssues.add(compName + ': $' + record.Competitor_1_Market_Value__c.setScale(2) + ' (lower than our $' + cashPrice.setScale(2) + ')');
                }
                if (record.Competitor_2_Market_Value__c != null && record.Competitor_2_Market_Value__c < cashPrice) {
                    String compName = String.isNotBlank(record.Competitor_2__c) ? record.Competitor_2__c : 'Competitor 2';
                    priceIssues.add(compName + ': $' + record.Competitor_2_Market_Value__c.setScale(2) + ' (lower than our $' + cashPrice.setScale(2) + ')');
                }
                if (record.Competitor_3_Market_Value__c != null && record.Competitor_3_Market_Value__c < cashPrice) {
                    String compName = String.isNotBlank(record.Competitor_3__c) ? record.Competitor_3__c : 'Competitor 3';
                    priceIssues.add(compName + ': $' + record.Competitor_3_Market_Value__c.setScale(2) + ' (lower than our $' + cashPrice.setScale(2) + ')');
                }
            }

            if (!priceIssues.isEmpty()) {
                priceAlertTooltip = 'Price Alert: ' + String.join(priceIssues, ' | ');
            }

            // Build Missing URL tooltip with specific missing URLs
            if (String.isNotBlank(record.Competitor_1__c) && String.isBlank(record.Competitor_1_URL__c)) {
                urlIssues.add(record.Competitor_1__c);
            }
            if (String.isNotBlank(record.Competitor_2__c) && String.isBlank(record.Competitor_2_URL__c)) {
                urlIssues.add(record.Competitor_2__c);
            }
            if (String.isNotBlank(record.Competitor_3__c) && String.isBlank(record.Competitor_3_URL__c)) {
                urlIssues.add(record.Competitor_3__c);
            }
            if (String.isNotBlank(record.Supplier_1_Name__c) && String.isBlank(record.Supplier_1_URL__c)) {
                urlIssues.add(record.Supplier_1_Name__c);
            }
            if (String.isNotBlank(record.Supplier_2_Name__c) && String.isBlank(record.Supplier_2_URL__c)) {
                urlIssues.add(record.Supplier_2_Name__c);
            }

            if (!urlIssues.isEmpty()) {
                missingURLTooltip = 'Missing URL for: ' + String.join(urlIssues, ', ');
            }

            // Build Note tooltip with supplier error notes
            if (String.isNotBlank(record.Supplier_Error_Notes__c)) {
                noteTooltip = record.Supplier_Error_Notes__c;
            }
        }

        // Get status priority for sorting
        public Integer getStatusPriority() {
            if (!statusEvaluated) {
                evaluateStatus();
            }

            if (hasPriceDiscrepancy) {
                return 1; // Error - highest priority
            } else if (hasMissingURL) {
                return 2; // Warning
            } else if (hasSupplierError) {
                return 3; // Info
            } else {
                return 4; // Success - lowest priority
            }
        }
    }

    /**
     * Remote Action: Check for background updates since last check
     * Used for polling to notify users of stale data without auto-refreshing
     * @param lastCheckTime ISO timestamp of last check
     * @return Map with hasUpdates flag and updateCount
     */
    @RemoteAction
    public static Map<String, Object> checkForUpdates(String lastCheckTime) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Parse the ISO timestamp
            DateTime lastCheck;
            if (String.isNotBlank(lastCheckTime)) {
                // Handle ISO format: 2024-01-15T10:30:00.000Z
                String cleanTime = lastCheckTime.replace('T', ' ').replace('Z', '').replace('.000', '');
                lastCheck = DateTime.valueOfGmt(cleanTime);
            } else {
                // Default to 1 minute ago if no timestamp provided
                lastCheck = DateTime.now().addMinutes(-1);
            }

            // Query for records modified since last check
            Integer updateCount = [
                SELECT COUNT()
                FROM Product_Inventory__c
                WHERE LastModifiedDate > :lastCheck
            ];

            result.put('success', true);
            result.put('hasUpdates', updateCount > 0);
            result.put('updateCount', updateCount);
            result.put('serverTime', DateTime.now().format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));

        } catch (Exception e) {
            System.debug('Error checking for updates: ' + e.getMessage());
            result.put('success', false);
            result.put('hasUpdates', false);
            result.put('updateCount', 0);
            result.put('error', e.getMessage());
        }

        return result;
    }

    /**
     * Read the website now, rather than waiting for the scheduled sweep.
     * Read-only: it can only populate the Woo_* observation fields.
     */
    @RemoteAction
    public static Map<String, Object> checkWebsiteNow() {
        Map<String, Object> response = new Map<String, Object>();
        try {
            System.enqueueJob(new WooAvailabilityObserver());
            response.put('success', true);
            response.put('message', 'Reading the website now. Refresh in a minute to see the results.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Could not start the website check: ' + e.getMessage());
        }
        return response;
    }

    /**
     * Resolve disagreements by pushing the Salesforce decision to the website.
     * This direction cannot overwrite a human decision - it enforces one.
     */
    @RemoteAction
    public static Map<String, Object> resolveByFixingWebsite(List<Id> recordIds) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            WebsiteReconciliationService.Outcome outcome =
                WebsiteReconciliationService.fixWebsite(recordIds);

            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            String message = outcome.resolved + ' product' + (outcome.resolved == 1 ? '' : 's')
                + ' updated on the website to match Salesforce.';
            if (outcome.refused > 0) {
                message += ' ' + outcome.refused + ' could not be updated'
                    + (outcome.messages.isEmpty() ? '.' : ': ' + String.join(outcome.messages, '; '));
            }
            response.put('success', outcome.resolved > 0);
            response.put('message', message);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }

    /**
     * Resolve disagreements by adopting the website's observed state into Salesforce.
     *
     * This is the only action that lets an outside change rewrite the system of record, so it
     * refuses any product where Salesforce never confirmed telling the website about its decision -
     * in that case the website's disagreement is ignorance, not a competing decision.
     *
     * @param confirmOverride pass true ONLY from a second, explicit human confirmation that names
     *                        what is being overridden. Never default it to true.
     */
    @RemoteAction
    public static Map<String, Object> resolveByAcceptingWebsite(List<Id> recordIds, Boolean confirmOverride) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }

            WebsiteReconciliationService.Outcome outcome =
                WebsiteReconciliationService.acceptWebsite(recordIds, confirmOverride == true);

            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            String message = outcome.resolved + ' product' + (outcome.resolved == 1 ? '' : 's')
                + ' updated in Salesforce to match the website.';
            if (outcome.refused > 0) {
                message += ' ' + outcome.refused + ' refused: ' + String.join(outcome.messages, '; ');
            }
            response.put('success', outcome.resolved > 0);
            response.put('refused', outcome.refused);
            response.put('message', message);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }

    // ---------------------------------------------------------------------------------------
    // Contract terms shown on the website
    // ---------------------------------------------------------------------------------------

    /** The terms currently offered for one product, for the editor dialog. */
    @RemoteAction
    public static Map<String, Object> getWebsiteTerms(Id recordId) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            Product_Inventory__c p = [
                SELECT Id, Name, ProductName__c, Website_Terms__c, Website_Product_Id__c,
                       Publish_13_Months__c, Publish_24_Months__c, Publish_36_Months__c,
                       X13_Months_Weekly_Price__c, X13_Months_Fortnightly_Price__c,
                       X24_Months_Weekly_Price__c, X24_Months_Fortnightly_Price__c,
                       X36_Months_Weekly_Price__c, X36_Months_Fortnightly_Price__c
                FROM Product_Inventory__c WHERE Id = :recordId LIMIT 1
            ];

            // Show the EFFECTIVE terms, not the raw checkboxes. A product nobody has reviewed has
            // all four unticked, yet the website offers 24 and 36 - rendering the raw booleans
            // would tell the operator the site shows nothing, which is untrue for 8,000 records.
            Set<String> effective = new Set<String>();
            for (String t : String.isBlank(p.Website_Terms__c)
                    ? new List<String>() : p.Website_Terms__c.split(',')) {
                effective.add(t.trim());
            }

            response.put('success', true);
            response.put('name', String.isNotBlank(p.ProductName__c) ? p.ProductName__c : p.Name);
            response.put('recordName', p.Name);
            response.put('terms', p.Website_Terms__c);
            response.put('mapped', String.isNotBlank(p.Website_Product_Id__c));
            response.put('reviewed', p.Publish_13_Months__c
                || p.Publish_24_Months__c || p.Publish_36_Months__c);
            response.put('p13', effective.contains('13'));
            response.put('p24', effective.contains('24'));
            response.put('p36', effective.contains('36'));
            response.put('price13', p.X13_Months_Weekly_Price__c);
            response.put('price24', p.X24_Months_Weekly_Price__c);
            response.put('price36', p.X36_Months_Weekly_Price__c);
            // The site needs BOTH figures for a term to appear, so an operator has to be able to
            // see which half is missing before they tick something that will not render.
            response.put('missing', String.join(WooCommerceSyncBatch.missingPricesForOfferedTerms(p), ', '));
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }

    /**
     * Set which contract terms the website offers, for a specific set of products.
     *
     * @param pushNow send to the website immediately. When false the choice is only recorded in
     *                Salesforce and reaches the site on its next price push.
     */
    @RemoteAction
    public static Map<String, Object> setWebsiteTerms(List<Id> recordIds, Boolean p13,
                                                     Boolean p24, Boolean p36, Boolean pushNow) {
        return applyTerms(recordIds, p13, p24, p36, pushNow);
    }

    /**
     * The same thing for every product in a category, which is how procurement actually works -
     * "no 13 month terms on furniture" is a category rule, not 300 individual decisions.
     *
     * The category comes from the console's own filter, so an operator can narrow the list, see
     * exactly what they are about to change, and apply it to that set.
     */
    @RemoteAction
    public static Map<String, Object> setWebsiteTermsForCategory(String category, Boolean p13,
                                                                Boolean p24, Boolean p36, Boolean pushNow) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (String.isBlank(category) || category == 'All') {
                response.put('success', false);
                response.put('message', 'Choose a specific category first. Applying a term change to '
                    + 'every product at once is not something this button will do.');
                return response;
            }

            List<Id> ids = new List<Id>();
            for (Product_Inventory__c p : category == 'Uncategorised'
                    ? [SELECT Id FROM Product_Inventory__c WHERE Category__c = null]
                    : [SELECT Id FROM Product_Inventory__c WHERE Category__c = :category]) {
                ids.add(p.Id);
            }

            if (ids.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No products found in ' + category);
                return response;
            }

            return applyTerms(ids, p13, p24, p36, pushNow);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }

    /** How many products a category change would touch, so the operator sees it before confirming. */
    @RemoteAction
    public static Map<String, Object> countProductsInCategory(String category) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            Integer n = String.isBlank(category) || category == 'All'
                ? 0
                : (category == 'Uncategorised'
                    ? [SELECT COUNT() FROM Product_Inventory__c WHERE Category__c = null]
                    : [SELECT COUNT() FROM Product_Inventory__c WHERE Category__c = :category]);
            response.put('success', true);
            response.put('count', n);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }

    private static Map<String, Object> applyTerms(List<Id> recordIds, Boolean p13,
                                                  Boolean p24, Boolean p36, Boolean pushNow) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (!Schema.sObjectType.Product_Inventory__c.isUpdateable()) {
                response.put('success', false);
                response.put('message', 'You do not have permission to update products');
                return response;
            }
            if (recordIds == null || recordIds.isEmpty()) {
                response.put('success', false);
                response.put('message', 'No products selected');
                return response;
            }

            // A product offering no terms cannot be rented at all - the page would show a price
            // with no way to take it. Refuse rather than publish that. This is enforced here and
            // not by a validation rule, because a rule cannot tell "deliberately all off" from
            // "never reviewed", and every existing record is the latter.
            if (p13 != true && p24 != true && p36 != true) {
                response.put('success', false);
                response.put('message', 'Choose at least one term. A product with no terms cannot be '
                    + 'rented - to take it off the website entirely, use Out of Stock instead.');
                return response;
            }

            List<Product_Inventory__c> updates = new List<Product_Inventory__c>();
            for (Id recordId : recordIds) {
                updates.add(new Product_Inventory__c(
                    Id = recordId,
                    Publish_13_Months__c = p13 == true,
                    Publish_24_Months__c = p24 == true,
                    Publish_36_Months__c = p36 == true
                ));
            }
            Database.update(updates, false);

            List<String> chosen = new List<String>();
            if (p13 == true) { chosen.add('13'); }
            if (p24 == true) { chosen.add('24'); }
            if (p36 == true) { chosen.add('36'); }
            String termLabel = String.join(chosen, ', ') + ' month';

            String message = recordIds.size() + ' product' + (recordIds.size() == 1 ? '' : 's')
                + ' set to offer ' + termLabel + (chosen.size() == 1 ? '' : ' terms') + '.';

            if (pushNow == true) {
                // The DML above has to be committed before any callout, so the push cannot happen
                // in this transaction. Queueable keeps the whole set on one code path regardless of
                // size and gives each chunk a fresh callout budget.
                WooCommerceTermsService.publishAsync(recordIds);
                message += ' Sending to the website now'
                    + (recordIds.size() > WooCommerceTermsService.CHUNK_SIZE
                        ? ' in batches of ' + WooCommerceTermsService.CHUNK_SIZE + '.' : '.')
                    + ' Refresh in a moment to see the result against each product.';
            } else {
                message += ' Saved in Salesforce only - the website still offers the old terms until'
                    + ' you publish.';
            }

            queryCache.clear();
            countCache.clear();
            cacheTimestamp = 0;

            response.put('success', true);
            response.put('count', recordIds.size());
            response.put('terms', String.join(chosen, ','));
            response.put('message', message);
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', 'Error: ' + e.getMessage());
        }
        return response;
    }
}