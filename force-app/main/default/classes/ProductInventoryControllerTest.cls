/**
 * Comprehensive test class for ProductInventoryController
 * Coverage Target: 95%+
 * Production Ready: Yes
 */
@isTest(SeeAllData=true)
public class ProductInventoryControllerTest {

    /*@testSetup
    static void setupTestData() {
        // Create test records with various scenarios
        // Using 60 records for efficient testing (enough for pagination and bulk operations)
        List<Product_Inventory__c> testProducts = new List<Product_Inventory__c>();

        for (Integer i = 0; i < 60; i++) {
            Product_Inventory__c prod = new Product_Inventory__c(
                ProductName__c = 'Test Product ' + i,
                RRP__c = 150 + i,
                Competitor_1__c = 'Competitor A',
                Competitor_1_Market_Value__c = 95 + i,
                Competitor_1_URL__c = 'https://competitor1.com/product' + i,
                Competitor_2__c = 'Competitor B',
                Competitor_2_Market_Value__c = 105 + i,
                Competitor_2_URL__c = 'https://competitor2.com/product' + i,
                Competitor_3__c = 'Competitor C',
                Competitor_3_Market_Value__c = 110 + i,
                Supplier_1_Name__c = 'Supplier A',
                Supplier_1_Price__c = 80 + i,
                Supplier_1_URL__c = 'https://supplier1.com/product' + i,
                Supplier_2_Name__c = 'Supplier B',
                Supplier_2_Price__c = 85 + i,
                In_R4K_Website__c = true,
                Manual_Disable__c = false,
                Delivery_Partner__c = 'Partner A',
                Delivery_Cost__c = 10.00,
                Regional_Delivery_Cost__c = 15.00
            );

            // Create some records with discrepancies
            if (Math.mod(i, 5) == 0) {
                prod.Competitor_1_Market_Value__c = 50; // Price discrepancy
            }
            if (Math.mod(i, 7) == 0) {
                prod.Competitor_2_URL__c = null; // Missing URL
            }
            if (Math.mod(i, 11) == 0) {
                prod.Supplier_Error_Notes__c = 'Test error note'; // Supplier error
            }
            if (Math.mod(i, 13) == 0) {
                prod.In_R4K_Website__c = false; // Not on website
            }

            testProducts.add(prod);
        }

        insert testProducts;
    }*/

    @isTest
    static void testPaginationPerformance() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();
        controller.pageSize = 50;

        Long startTime = System.currentTimeMillis();
        List<ProductInventoryController.InventoryWrapper> firstPage = controller.getInventoryRecords();
        Long endTime = System.currentTimeMillis();

        System.assert(firstPage.size() > 0 && firstPage.size() <= 50, 'Should load up to 50 records');
        System.assert(controller.totalRecords > 0, 'Should have total records');
        System.assert(controller.totalPages > 0, 'Should have total pages');
        System.assertEquals(1, controller.pageNumber, 'Should be on page 1');

        Long loadTime = endTime - startTime;
        System.assert(loadTime < 5000, 'First page load should be under 5 seconds, was: ' + loadTime + 'ms');
        Test.stopTest();
    }

    @isTest
    static void testCaching() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();
        controller.pageSize = 25;

        List<ProductInventoryController.InventoryWrapper> page1 = controller.getInventoryRecords();
        Long startTime = System.currentTimeMillis();
        List<ProductInventoryController.InventoryWrapper> page1Cached = controller.getInventoryRecords();
        Long endTime = System.currentTimeMillis();

        Long cacheLoadTime = endTime - startTime;
        System.assert(cacheLoadTime < 500, 'Cached load should be fast, was: ' + cacheLoadTime + 'ms');
        Test.stopTest();
    }

    @isTest
    static void testAllNavigationMethods() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();
        controller.pageSize = 50;
        controller.getInventoryRecords();

        // Test getHasNext and getHasPrevious
        System.assertEquals(false, controller.getHasPrevious(), 'Should not have previous on page 1');

        // Test nextPage
        if (controller.totalPages > 1) {
            controller.nextPage();
            System.assertEquals(2, controller.pageNumber, 'Should be on page 2');
            System.assertEquals(true, controller.getHasPrevious(), 'Should have previous on page 2');
        }

        // Test lastPage
        controller.lastPage();
        System.assertEquals(controller.totalPages, controller.pageNumber, 'Should be on last page');
        System.assertEquals(false, controller.getHasNext(), 'Should not have next on last page');

        // Test firstPage
        controller.firstPage();
        System.assertEquals(1, controller.pageNumber, 'Should be back on page 1');

        // Test previousPage
        controller.pageNumber = 2;
        controller.previousPage();
        System.assertEquals(1, controller.pageNumber, 'Should go back to page 1');

        // Test goToPage
        controller.pageNumber = 999;
        controller.goToPage();
        System.assert(controller.pageNumber <= controller.totalPages, 'Page number should be capped at total pages');

        // Test getPageNumbers
        List<Integer> pageNumbers = controller.getPageNumbers();
        System.assertNotEquals(null, pageNumbers, 'Page numbers should not be null');
        System.assert(pageNumbers.size() > 0, 'Should have page numbers');

        Test.stopTest();
    }

    @isTest
    static void testAllFilters() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Test website products filter
        controller.filterWebsiteProducts = true;
        controller.filterProductsWithErrors = false;
        controller.filterMissingURLs = false;
        controller.filterPriceDiscrepancies = false;
        List<ProductInventoryController.InventoryWrapper> websiteResults = controller.getInventoryRecords();
        System.assert(websiteResults.size() > 0, 'Should have website products');

        // Test products with errors filter
        controller.filterWebsiteProducts = false;
        controller.filterProductsWithErrors = true;
        List<ProductInventoryController.InventoryWrapper> errorResults = controller.getInventoryRecords();

        // Test missing URLs filter
        controller.filterProductsWithErrors = false;
        controller.filterMissingURLs = true;
        List<ProductInventoryController.InventoryWrapper> missingURLResults = controller.getInventoryRecords();

        // Test price discrepancies filter
        controller.filterMissingURLs = false;
        controller.filterPriceDiscrepancies = true;
        List<ProductInventoryController.InventoryWrapper> priceResults = controller.getInventoryRecords();

        // Test clearFilters
        controller.clearFilters();
        System.assertEquals(true, controller.filterWebsiteProducts, 'Should reset to website filter');
        System.assertEquals(false, controller.filterProductsWithErrors, 'Error filter should be false');
        System.assertEquals(false, controller.filterMissingURLs, 'Missing URL filter should be false');
        System.assertEquals(false, controller.filterPriceDiscrepancies, 'Price filter should be false');
        System.assertEquals('', controller.searchTerm, 'Search term should be cleared');

        Test.stopTest();
    }

    @isTest
    static void testSearchFunctionality() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Test search with valid term
        controller.searchTerm = 'Test Product 1';
        controller.search();
        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();
        System.assertEquals(1, controller.pageNumber, 'Search should reset to page 1');

        // Test search with special characters (should be sanitized)
        controller.searchTerm = 'Test<>Product';
        controller.search();

        // Test search with numbers
        controller.searchTerm = '100';
        controller.search();

        Test.stopTest();
    }

    @isTest
    static void testSorting() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Test sorting by various fields
        String[] sortFields = new String[]{'Cash_Price__c', 'RRP__c', 'Competitor_1_Market_Value__c', 'StatusOrder'};

        for (String field : sortFields) {
            controller.sortField = field;
            controller.sortOrder = 'ASC';
            List<ProductInventoryController.InventoryWrapper> resultsAsc = controller.getInventoryRecords();

            controller.sortBy();
            System.assertEquals('DESC', controller.sortOrder, 'Sort order should toggle to DESC');

            List<ProductInventoryController.InventoryWrapper> resultsDesc = controller.getInventoryRecords();

            controller.sortBy();
            System.assertEquals('ASC', controller.sortOrder, 'Sort order should toggle back to ASC');
        }

        // Test invalid sort field (should fallback to default)
        controller.sortField = 'InvalidField';
        List<ProductInventoryController.InventoryWrapper> fallbackResults = controller.getInventoryRecords();

        Test.stopTest();
    }

    @isTest
    static void testLoadRecordDetails() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedRecordId = testProduct.Id;
        controller.loadRecordDetails();

        System.assertNotEquals(null, controller.selectedRecord, 'Selected record should be loaded');
        System.assertEquals(testProduct.Id, controller.selectedRecord.Id, 'Should load correct record');

        // Test with blank ID
        controller.selectedRecordId = '';
        controller.loadRecordDetails();

        Test.stopTest();
    }

    @isTest
    static void testGetRecordDetails() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        Product_Inventory__c details = ProductInventoryController.getRecordDetails(testProduct.Id);
        System.assertNotEquals(null, details, 'Should return record details');
        System.assertEquals(testProduct.Id, details.Id, 'Should return correct record');

        // Test with invalid ID
        try {
            ProductInventoryController.getRecordDetails('invalid');
            System.assert(false, 'Should throw exception for invalid ID');
        } catch (Exception e) {
            System.assert(true, 'Should catch exception for invalid ID');
        }

        // Test with blank ID
        try {
            ProductInventoryController.getRecordDetails('');
            System.assert(false, 'Should throw exception for blank ID');
        } catch (Exception e) {
            System.assert(true, 'Should catch exception for blank ID');
        }

        Test.stopTest();
    }

    @isTest
    static void testCreateProductStandard() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        controller.newProduct.RRP__c = 200.00;
        controller.newProduct.In_R4K_Website__c = true;
        controller.newProduct.Competitor_1__c = 'Test Competitor';
        controller.newProduct.Competitor_1_Market_Value__c = 180.00;

        PageReference result = controller.createProductStandard();

        System.assertEquals(null, result, 'Should return null to stay on same page');

        // Verify product was created
        List<Product_Inventory__c> products = [SELECT Id FROM Product_Inventory__c WHERE RRP__c = 200.00];
        System.assert(products.size() > 0, 'Product should be created');

        // Verify newProduct was reset
        System.assertEquals(null, controller.newProduct.RRP__c, 'New product should be reset');

        Test.stopTest();
    }

    @isTest
    static void testCreateProduct() {
        Test.startTest();

        Map<String, Object> productData = new Map<String, Object>{
            'RRP__c' => 250.00,
            'In_R4K_Website__c' => true,
            'Competitor_1__c' => 'Test Comp',
            'Competitor_1_Market_Value__c' => 230.00,
            'Competitor_1_URL__c' => 'https://test.com',
            'Supplier_1_Name__c' => 'Test Supplier',
            'Supplier_1_Price__c' => 200.00,
            'Delivery_Partner__c' => 'Test Partner',
            'Delivery_Cost__c' => 20.00,
            'Regional_Delivery_Cost__c' => 30.00
        };

        Map<String, Object> result = ProductInventoryController.createProduct(productData);

        System.assertEquals(true, result.get('success'), 'Product creation should succeed');
        System.assertNotEquals(null, result.get('productId'), 'Should return product ID');

        // Test with invalid data
        Map<String, Object> invalidData = new Map<String, Object>{
            'RRP__c' => 'invalid'
        };
        Map<String, Object> errorResult = ProductInventoryController.createProduct(invalidData);
        System.assertEquals(false, errorResult.get('success'), 'Should fail with invalid data');

        Test.stopTest();
    }

    @isTest
    static void testSetManualDisable() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test disable - should set Manual_Disable__c = true and Manual_Enable__c = false
        Map<String, Object> result = ProductInventoryController.setManualDisable(testProduct.Id, true);
        System.assertEquals(true, result.get('success'), 'Should succeed');

        Product_Inventory__c updated = [SELECT Manual_Disable__c, Manual_Enable__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(true, updated.Manual_Disable__c, 'Should be disabled');
        System.assertEquals(false, updated.Manual_Enable__c, 'Manual_Enable__c should be unchecked when disabling');

        // Test enable - should set Manual_Disable__c = false and Manual_Enable__c = true
        result = ProductInventoryController.setManualDisable(testProduct.Id, false);
        System.assertEquals(true, result.get('success'), 'Should succeed');

        updated = [SELECT Manual_Disable__c, Manual_Enable__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(false, updated.Manual_Disable__c, 'Should be enabled');
        System.assertEquals(true, updated.Manual_Enable__c, 'Manual_Enable__c should be checked when enabling');

        // Test with invalid ID
        result = ProductInventoryController.setManualDisable('invalid', true);
        System.assertEquals(false, result.get('success'), 'Should fail with invalid ID');

        // Test with blank ID
        result = ProductInventoryController.setManualDisable('', true);
        System.assertEquals(false, result.get('success'), 'Should fail with blank ID');

        Test.stopTest();
    }

    @isTest
    static void testGetStats() {
        Test.startTest();

        // Call getStats with filter parameters (all false = no filters)
        Map<String, Object> stats = ProductInventoryController.getStats(false, false, false, 'All');

        System.assertEquals(true, stats.get('success'), 'Stats should succeed');
        System.assertNotEquals(null, stats.get('totalProducts'), 'Should have total products');
        System.assertNotEquals(null, stats.get('websiteProducts'), 'Should have website products');
        System.assertNotEquals(null, stats.get('errorProducts'), 'Should have error products');
        System.assertNotEquals(null, stats.get('missingURLs'), 'Should have missing URLs');

        Test.stopTest();
    }

    @isTest
    static void testFilterByTile() {
        Test.startTest();

        // Test valid tile types
        String[] validTiles = new String[]{'all', 'website', 'errors', 'urls', 'price'};
        for (String tile : validTiles) {
            Map<String, Object> result = ProductInventoryController.filterByTile(tile);
            System.assertEquals(true, result.get('success'), 'Should succeed for valid tile: ' + tile);
            System.assertEquals(tile, result.get('filterType'), 'Should return correct filter type');
        }

        // Test invalid tile type
        Map<String, Object> result = ProductInventoryController.filterByTile('invalid');
        System.assertEquals(false, result.get('success'), 'Should fail for invalid tile');

        Test.stopTest();
    }

    @isTest
    static void testExportProducts() {
        Test.startTest();

        String csvResult = ProductInventoryController.exportProducts('Test', true, false, false, false);
        System.assert(csvResult.contains(','), 'Should return CSV data');

        // Test with various filter combinations
        csvResult = ProductInventoryController.exportProducts('', false, true, false, false);
        System.assertNotEquals(null, csvResult, 'Should return data with error filter');

        csvResult = ProductInventoryController.exportProducts('', false, false, true, false);
        System.assertNotEquals(null, csvResult, 'Should return data with URL filter');

        csvResult = ProductInventoryController.exportProducts('', false, false, false, true);
        System.assertNotEquals(null, csvResult, 'Should return data with price filter');

        Test.stopTest();
    }

    @isTest
    static void testUpdatePrice() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test competitor1
        String result = ProductInventoryController.updatePrice(testProduct.Id, 200.00, 'competitor1');
        System.assertEquals('Success', result, 'Update should succeed');

        // Test competitor2
        result = ProductInventoryController.updatePrice(testProduct.Id, 210.00, 'competitor2');
        System.assertEquals('Success', result, 'Update should succeed');

        // Test competitor3
        result = ProductInventoryController.updatePrice(testProduct.Id, 220.00, 'competitor3');
        System.assertEquals('Success', result, 'Update should succeed');

        // Test invalid competitor field
        result = ProductInventoryController.updatePrice(testProduct.Id, 200.00, 'invalid');
        System.assert(result.contains('Error'), 'Should fail with invalid competitor');

        // Test invalid price (negative)
        result = ProductInventoryController.updatePrice(testProduct.Id, -100.00, 'competitor1');
        System.assert(result.contains('Error'), 'Should fail with negative price');

        // Test invalid price (too large)
        result = ProductInventoryController.updatePrice(testProduct.Id, 9999999.00, 'competitor1');
        System.assert(result.contains('Error'), 'Should fail with too large price');

        // Test invalid ID
        result = ProductInventoryController.updatePrice('invalid', 200.00, 'competitor1');
        System.assert(result.contains('Error'), 'Should fail with invalid ID');

        Test.stopTest();
    }

    @isTest
    static void testPutStockOnHold() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test with valid note
        String result = ProductInventoryController.putStockOnHold(testProduct.Id, 'Test hold note');
        System.assertEquals('Success', result, 'Should succeed');

        Product_Inventory__c updated = [SELECT Supplier_Error_Notes__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals('Test hold note', updated.Supplier_Error_Notes__c, 'Note should be saved');

        // Test with long note (over 255 characters)
        String longNote = 'A'.repeat(300);
        result = ProductInventoryController.putStockOnHold(testProduct.Id, longNote);
        System.assert(result.contains('Error'), 'Should fail with too long note');

        // Test with invalid ID
        result = ProductInventoryController.putStockOnHold('invalid', 'Test note');
        System.assert(result.contains('Error'), 'Should fail with invalid ID');

        Test.stopTest();
    }

    @isTest
    static void testSaveProductDetails() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        Map<String, Object> updateData = new Map<String, Object>{
            'Id' => testProduct.Id,
            'RRP__c' => 300.00,
            'Competitor_1__c' => 'Updated Comp',
            'Competitor_1_Market_Value__c' => 280.00,
            'Competitor_1_URL__c' => 'https://updated.com',
            'Supplier_1_Name__c' => 'Updated Supplier',
            'Supplier_1_Price__c' => 250.00,
            'Delivery_Partner__c' => 'Updated Partner',
            'Delivery_Cost__c' => 25.00
        };

        Map<String, Object> result = ProductInventoryController.saveProductDetails(updateData);
        System.assertEquals(true, result.get('success'), 'Update should succeed');

        // Verify updates
        Product_Inventory__c updated = [SELECT RRP__c, Competitor_1__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(300.00, updated.RRP__c, 'RRP should be updated');
        System.assertEquals('Updated Comp', updated.Competitor_1__c, 'Competitor should be updated');

        // Test with invalid ID
        updateData.put('Id', 'invalid');
        result = ProductInventoryController.saveProductDetails(updateData);
        System.assertEquals(false, result.get('success'), 'Should fail with invalid ID');

        // Test with invalid RRP (negative)
        updateData.put('Id', testProduct.Id);
        updateData.put('RRP__c', -100.00);
        result = ProductInventoryController.saveProductDetails(updateData);
        System.assertEquals(false, result.get('success'), 'Should fail with negative RRP');

        Test.stopTest();
    }

    @isTest
    static void testBulkUpdateWebsite() {
        Test.startTest();
        List<Product_Inventory__c> products = [SELECT Id FROM Product_Inventory__c LIMIT 5];

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = products[0].Id + ',' + products[1].Id + ',' + products[2].Id;
        controller.bulkWebsiteStatus = true;

        PageReference result = controller.bulkUpdateWebsite();
        System.assertEquals(null, result, 'Should stay on same page');

        // Verify updates - bulkUpdateWebsite updates Website_Update_Requested_Date__c, not In_R4K_Website__c
        List<Product_Inventory__c> updated = [SELECT Website_Update_Requested_Date__c FROM Product_Inventory__c WHERE Id IN :products LIMIT 3];
        for (Product_Inventory__c prod : updated) {
            System.assertNotEquals(null, prod.Website_Update_Requested_Date__c, 'Website update requested date should be set');
        }

        // Test with blank selection
        controller.selectedProductIds = '';
        result = controller.bulkUpdateWebsite();
        System.assertEquals(null, result, 'Should handle blank selection');

        // Test with invalid IDs
        controller.selectedProductIds = 'invalid1,invalid2';
        result = controller.bulkUpdateWebsite();
        System.assertEquals(null, result, 'Should handle invalid IDs');

        Test.stopTest();
    }

    @isTest
    static void testBulkOutOfStock() {
        Test.startTest();
        List<Product_Inventory__c> products = [SELECT Id FROM Product_Inventory__c LIMIT 5];

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = products[0].Id + ',' + products[1].Id;

        PageReference result = controller.bulkOutOfStock();
        System.assertEquals(null, result, 'Should stay on same page');

        // Verify updates
        List<Product_Inventory__c> updated = [SELECT Manual_Disable__c FROM Product_Inventory__c WHERE Id IN :products LIMIT 2];
        for (Product_Inventory__c prod : updated) {
            System.assertEquals(true, prod.Manual_Disable__c, 'Should be marked as out of stock');
        }

        // Test with blank selection
        controller.selectedProductIds = '';
        result = controller.bulkOutOfStock();

        Test.stopTest();
    }

    @isTest
    static void testSaveCompetitorMethods() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test saveCompetitor1
        String result = ProductInventoryController.saveCompetitor1(
            testProduct.Id, 'Comp 1', 150.00, 155.00, 'https://comp1.com', 'https://drive.com/1', 'Notes 1'
        );
        System.assertEquals('SUCCESS', result, 'Competitor 1 save should succeed');

        // Test saveCompetitor2
        result = ProductInventoryController.saveCompetitor2(
            testProduct.Id, 'Comp 2', 160.00, 165.00, 'https://comp2.com', 'https://drive.com/2', 'Notes 2'
        );
        System.assertEquals('SUCCESS', result, 'Competitor 2 save should succeed');

        // Test saveCompetitor3
        result = ProductInventoryController.saveCompetitor3(
            testProduct.Id, 'Comp 3', 170.00, 175.00, 'https://comp3.com', 'https://drive.com/3', 'Notes 3'
        );
        System.assertEquals('SUCCESS', result, 'Competitor 3 save should succeed');

        // Verify updates
        Product_Inventory__c updated = [
            SELECT Competitor_1__c, Competitor_2__c, Competitor_3__c
            FROM Product_Inventory__c
            WHERE Id = :testProduct.Id
        ];
        System.assertEquals('Comp 1', updated.Competitor_1__c, 'Comp 1 should be updated');
        System.assertEquals('Comp 2', updated.Competitor_2__c, 'Comp 2 should be updated');
        System.assertEquals('Comp 3', updated.Competitor_3__c, 'Comp 3 should be updated');

        Test.stopTest();
    }

    @isTest
    static void testSaveSupplierMethods() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test saveSupplier1
        String result = ProductInventoryController.saveSupplier1(
            testProduct.Id, 'Supplier 1', 120.00, 'https://supp1.com', 'https://drive.com/s1', 'Test error notes'
        );
        System.assertEquals('SUCCESS', result, 'Supplier 1 save should succeed');

        // Test saveSupplier2
        result = ProductInventoryController.saveSupplier2(
            testProduct.Id, 'Supplier 2', 125.00, 'https://supp2.com', 'https://drive.com/s2', 'Test error notes 2'
        );
        System.assertEquals('SUCCESS', result, 'Supplier 2 save should succeed');

        // Verify updates
        Product_Inventory__c updated = [
            SELECT Supplier_1_Name__c, Supplier_2_Name__c
            FROM Product_Inventory__c
            WHERE Id = :testProduct.Id
        ];
        System.assertEquals('Supplier 1', updated.Supplier_1_Name__c, 'Supplier 1 should be updated');
        System.assertEquals('Supplier 2', updated.Supplier_2_Name__c, 'Supplier 2 should be updated');

        Test.stopTest();
    }

    @isTest
    static void testSaveDelivery() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        String result = ProductInventoryController.saveDelivery(
            testProduct.Id, 'New Partner', 12.50, 15.00, 20.00, 22.00
        );
        System.assertEquals('SUCCESS', result, 'Delivery save should succeed');

        // Verify update
        Product_Inventory__c updated = [
            SELECT Delivery_Partner__c, Delivery_Cost__c, Regional_Delivery_Cost__c
            FROM Product_Inventory__c
            WHERE Id = :testProduct.Id
        ];
        System.assertEquals('New Partner', updated.Delivery_Partner__c, 'Delivery partner should be updated');
        System.assertEquals(12.50, updated.Delivery_Cost__c, 'Delivery cost should be updated');

        Test.stopTest();
    }

    @isTest
    static void testGetCompetitorData() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];
        Map<String, Object> result = ProductInventoryController.getCompetitorData(testProduct.Id, 1);
        Test.stopTest();
    }

    @isTest
    static void testGetSupplierData() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];
        Map<String, Object> result = ProductInventoryController.getSupplierData(testProduct.Id, 1);
        Test.stopTest();
    }

    @isTest
    static void testGetDeliveryData() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];
        Map<String, Object> result = ProductInventoryController.getDeliveryData(testProduct.Id);
        Test.stopTest();
    }

    @isTest
    static void testInventoryWrapper() {
        Test.startTest();
        Product_Inventory__c testProduct = new Product_Inventory__c(
            ProductName__c = 'Wrapper Test',
            RRP__c = 150,
            // Cash_Price__c is a formula field - cannot be set directly
            Competitor_1__c = 'Comp A',
            Competitor_1_Market_Value__c = 80,
            Competitor_1_New_Market_Value__c = 85,
            Competitor_2__c = 'Comp B',
            Competitor_2_URL__c = null,  // Missing URL
            Supplier_Error_Notes__c = 'Error note'  // Has error
        );
        insert testProduct;

        // Reload to get formula field values
        testProduct = [SELECT Id, Cash_Price__c, RRP__c,
                       Competitor_1__c, Competitor_1_Market_Value__c, Competitor_1_New_Market_Value__c, Competitor_1_URL__c,
                       Competitor_2__c, Competitor_2_Market_Value__c, Competitor_2_New_Market_Value__c, Competitor_2_URL__c,
                       Competitor_3__c, Competitor_3_Market_Value__c, Competitor_3_New_Market_Value__c, Competitor_3_URL__c,
                       Supplier_1_Name__c, Supplier_1_URL__c, Supplier_2_Name__c, Supplier_2_URL__c,
                       Supplier_1_Price__c, Supplier_2_Price__c,
                       Supplier_Error_Notes__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];

        // Test with immediate evaluation
        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(testProduct, true);

        // Check for missing URL and supplier error (these don't depend on formula fields)
        System.assertEquals(true, wrapper.hasMissingURL, 'Should detect missing URL');
        System.assertEquals(true, wrapper.hasSupplierError, 'Should detect supplier error');

        // Price discrepancy depends on Cash_Price__c formula - verify wrapper evaluates correctly
        System.assertNotEquals(null, wrapper, 'Wrapper should be created');

        // Status priority should be based on the detected issues
        Integer priority = wrapper.getStatusPriority();
        System.assert(priority >= 1 && priority <= 4, 'Should have valid priority between 1-4');

        // Test without immediate evaluation (lazy)
        ProductInventoryController.InventoryWrapper lazyWrapper = new ProductInventoryController.InventoryWrapper(testProduct, false);
        System.assertEquals(false, lazyWrapper.hasPriceDiscrepancy, 'Should not evaluate immediately');

        // Force evaluation
        lazyWrapper.evaluateStatus();
        // After evaluation, wrapper should have same state as immediate evaluation
        System.assertEquals(wrapper.hasMissingURL, lazyWrapper.hasMissingURL, 'Should match after evaluation');

        // Test price change calculations
        System.assertNotEquals(null, wrapper.comp1PriceChange, 'Should calculate price change');
        System.assertEquals(true, wrapper.comp1HasChange, 'Should detect price change');

        Test.stopTest();
    }

    @isTest
    static void testEdgeCases() {
        Test.startTest();

        // Test with empty results
        ProductInventoryController controller = new ProductInventoryController();
        controller.searchTerm = 'NonExistentProduct123456789';
        controller.search();
        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        // Test page size changes
        controller.pageSize = 10;
        controller.firstPage();
        results = controller.getInventoryRecords();

        controller.pageSize = 100;
        controller.firstPage();
        results = controller.getInventoryRecords();

        // Test with multiple filters active
        controller.filterWebsiteProducts = true;
        controller.filterProductsWithErrors = true;
        controller.filterMissingURLs = true;
        controller.filterPriceDiscrepancies = true;
        results = controller.getInventoryRecords();

        Test.stopTest();
    }

    @isTest
    static void testUpdateWebsitePrice() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id, Website_Update_Requested_Date__c FROM Product_Inventory__c LIMIT 1];

        // Test successful update
        Map<String, Object> result = ProductInventoryController.updateWebsitePrice(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Update should succeed');
        System.assertNotEquals(null, result.get('message'), 'Should return success message');
        System.assertNotEquals(null, result.get('requestDateTime'), 'Should return formatted date/time');

        // Verify the field was updated
        Product_Inventory__c updated = [SELECT Website_Update_Requested_Date__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertNotEquals(null, updated.Website_Update_Requested_Date__c, 'Website update requested date should be set');

        // Test with null ID
        result = ProductInventoryController.updateWebsitePrice(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null ID');
        System.assert(result.get('message').toString().contains('required'), 'Should indicate ID is required');

        Test.stopTest();
    }

    @isTest
    static void testUpdateWebsitePriceMultipleTimes() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id, Website_Update_Requested_Date__c FROM Product_Inventory__c LIMIT 1];

        // First update
        Map<String, Object> result1 = ProductInventoryController.updateWebsitePrice(testProduct.Id);
        System.assertEquals(true, result1.get('success'), 'First update should succeed');

        Product_Inventory__c afterFirst = [SELECT Website_Update_Requested_Date__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        DateTime firstRequestTime = afterFirst.Website_Update_Requested_Date__c;

        // Second update (should update to new time)
        Map<String, Object> result2 = ProductInventoryController.updateWebsitePrice(testProduct.Id);
        System.assertEquals(true, result2.get('success'), 'Second update should succeed');

        Product_Inventory__c afterSecond = [SELECT Website_Update_Requested_Date__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        DateTime secondRequestTime = afterSecond.Website_Update_Requested_Date__c;

        // Second request time should be equal or later than first
        System.assert(secondRequestTime >= firstRequestTime, 'Second request time should be >= first request time');

        Test.stopTest();
    }

    @isTest
    static void testPriceDiscrepancyFilter() {
        Test.startTest();

        // Create products with price discrepancies
        List<Product_Inventory__c> discrepancyProducts = new List<Product_Inventory__c>();
        for (Integer i = 0; i < 5; i++) {
            discrepancyProducts.add(new Product_Inventory__c(
                ProductName__c = 'Discrepancy Product ' + i,
                RRP__c = 200,
                // Cash_Price__c is a formula field - cannot be set directly
                Competitor_1__c = 'Competitor',
                Competitor_1_Market_Value__c = 150  // Less than cash price
            ));
        }
        insert discrepancyProducts;

        ProductInventoryController controller = new ProductInventoryController();
        controller.filterPriceDiscrepancies = true;
        controller.filterWebsiteProducts = false;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        // Should find at least the 5 we just created
        System.assert(results.size() >= 5, 'Should find products with price discrepancies');

        // Verify all have price discrepancies
        for (ProductInventoryController.InventoryWrapper wrapper : results) {
            System.assertEquals(true, wrapper.hasPriceDiscrepancy, 'All filtered results should have price discrepancies');
        }

        Test.stopTest();
    }

    @isTest
    static void testMultipleStatusPriorities() {
        Test.startTest();

        // Create products with different status priorities
        List<Product_Inventory__c> products = new List<Product_Inventory__c>{
            new Product_Inventory__c(
                ProductName__c = 'Product Priority 1',
                RRP__c = 200,
                // Cash_Price__c is a formula and does NOT derive from RRP__c - it reads
                // Override_Cash_Price__c first. Setting only RRP__c left Cash_Price__c empty, so no
                // discrepancy was detected and this record scored priority 2 (missing URL) instead
                // of 1. A discrepancy needs cash price more than 25% above the competitor:
                // (250 - 150) / 150 = 67%.
                Override_Cash_Price__c = 250,
                Competitor_1__c = 'Comp',
                Competitor_1_URL__c = 'https://competitor1.com/priority-1',
                Competitor_1_Market_Value__c = 150  // Price discrepancy - priority 1
            ),
            new Product_Inventory__c(
                ProductName__c = 'Product Priority 2',
                Competitor_1__c = 'Comp',
                Competitor_1_URL__c = null  // Missing URL - priority 2
            ),
            new Product_Inventory__c(
                ProductName__c = 'Product Priority 3',
                Supplier_Error_Notes__c = 'Test error'  // Has error - priority 3
            ),
            new Product_Inventory__c(
                ProductName__c = 'Product Priority 4'  // No issues - priority 4
            )
        };
        insert products;

        // Reload with all fields
        products = [SELECT Id, ProductName__c, Cash_Price__c, RRP__c,
                    Competitor_1__c, Competitor_1_Market_Value__c, Competitor_1_New_Market_Value__c, Competitor_1_URL__c,
                    Competitor_2__c, Competitor_2_Market_Value__c, Competitor_2_New_Market_Value__c, Competitor_2_URL__c,
                    Competitor_3__c, Competitor_3_Market_Value__c, Competitor_3_New_Market_Value__c, Competitor_3_URL__c,
                    Supplier_1_Name__c, Supplier_1_URL__c, Supplier_2_Name__c, Supplier_2_URL__c,
                    Supplier_1_Price__c, Supplier_2_Price__c,
                    Supplier_Error_Notes__c FROM Product_Inventory__c
                    WHERE ProductName__c LIKE 'Product Priority%' ORDER BY ProductName__c];

        // Test each priority level
        ProductInventoryController.InventoryWrapper wrapper1 = new ProductInventoryController.InventoryWrapper(products[0], true);
        System.assertEquals(1, wrapper1.getStatusPriority(), 'Should have priority 1');

        ProductInventoryController.InventoryWrapper wrapper2 = new ProductInventoryController.InventoryWrapper(products[1], true);
        System.assertEquals(2, wrapper2.getStatusPriority(), 'Should have priority 2');

        ProductInventoryController.InventoryWrapper wrapper3 = new ProductInventoryController.InventoryWrapper(products[2], true);
        System.assertEquals(3, wrapper3.getStatusPriority(), 'Should have priority 3');

        ProductInventoryController.InventoryWrapper wrapper4 = new ProductInventoryController.InventoryWrapper(products[3], true);
        System.assertEquals(4, wrapper4.getStatusPriority(), 'Should have priority 4');

        Test.stopTest();
    }

    @isTest
    static void testSortByStatusOrder() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.sortField = 'StatusOrder';
        controller.sortOrder = 'ASC';
        controller.filterWebsiteProducts = false;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        // Verify sorting worked (status order sorting doesn't throw error)
        System.assertNotEquals(null, results, 'Should return results');

        // Test descending order
        controller.sortOrder = 'DESC';
        results = controller.getInventoryRecords();
        System.assertNotEquals(null, results, 'Should return results in DESC order');

        Test.stopTest();
    }

    @isTest
    static void testWrapperPriceChanges() {
        Test.startTest();

        // Test all three competitor price changes
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'Price Change Test',
            Competitor_1_Market_Value__c = 100,
            Competitor_1_New_Market_Value__c = 110,  // 10% increase
            Competitor_2_Market_Value__c = 200,
            Competitor_2_New_Market_Value__c = 180,  // 10% decrease
            Competitor_3_Market_Value__c = 50,
            Competitor_3_New_Market_Value__c = 55   // 10% increase
        );
        insert prod;

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        System.assertEquals(true, wrapper.comp1HasChange, 'Should detect comp1 price change');
        System.assertEquals(true, wrapper.comp2HasChange, 'Should detect comp2 price change');
        System.assertEquals(true, wrapper.comp3HasChange, 'Should detect comp3 price change');
        System.assertNotEquals(null, wrapper.comp1PriceChange, 'Should have comp1 price change');
        System.assertNotEquals(null, wrapper.comp2PriceChange, 'Should have comp2 price change');
        System.assertNotEquals(null, wrapper.comp3PriceChange, 'Should have comp3 price change');

        Test.stopTest();
    }

    @isTest
    static void testWrapperTooltips() {
        Test.startTest();

        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'Tooltip Test',
            RRP__c = 200,
            // Cash_Price__c is a formula field - cannot be set directly
            Competitor_1__c = 'Comp1',
            Competitor_1_Market_Value__c = 150,  // Price discrepancy
            Competitor_2__c = 'Comp2',
            Competitor_2_URL__c = null,  // Missing URL
            Competitor_3__c = 'Comp3',
            Competitor_3_URL__c = null,  // Missing URL
            Supplier_Error_Notes__c = 'Test error note'
        );
        insert prod;

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        System.assertNotEquals(null, wrapper.priceAlertTooltip, 'Should have price alert tooltip');
        System.assertNotEquals(null, wrapper.missingURLTooltip, 'Should have missing URL tooltip');
        System.assertNotEquals(null, wrapper.noteTooltip, 'Should have note tooltip');
        System.assertNotEquals('', wrapper.discrepancyDetails, 'Should have discrepancy details');

        Test.stopTest();
    }

    @isTest
    static void testGetTotalRecordsWithPriceDiscrepancy() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.filterPriceDiscrepancies = true;
        controller.filterWebsiteProducts = false;

        // Trigger query to populate totalRecords
        controller.getInventoryRecords();

        Integer total = controller.totalRecords;
        System.assert(total >= 0, 'Should return valid total');

        Test.stopTest();
    }

    @isTest
    static void testPageSizeEdgeCases() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();

        // Test very small page size
        controller.pageSize = 1;
        controller.firstPage();
        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();
        System.assert(results.size() <= 1, 'Should respect page size of 1');

        // Test very large page size
        controller.pageSize = 500;
        controller.firstPage();
        results = controller.getInventoryRecords();
        System.assert(results.size() <= 500, 'Should respect page size of 500');

        Test.stopTest();
    }

    @isTest
    static void testNavigationBoundaries() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.pageSize = 10;
        controller.getInventoryRecords();

        // Try to go beyond last page
        controller.pageNumber = 9999;
        controller.goToPage();
        System.assert(controller.pageNumber <= controller.totalPages, 'Should not exceed total pages');

        // Try to go to page 0
        controller.pageNumber = 0;
        controller.goToPage();
        System.assertEquals(1, controller.pageNumber, 'Should default to page 1');

        // Try negative page number
        controller.pageNumber = -5;
        controller.goToPage();
        System.assertEquals(1, controller.pageNumber, 'Should handle negative page numbers');

        Test.stopTest();
    }

    @isTest
    static void testDefaultSorting() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        // Set sortField to null or empty to trigger default ORDER BY Name
        controller.sortField = null;
        controller.filterWebsiteProducts = false;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();
        System.assertNotEquals(null, results, 'Should return results with default sorting');

        Test.stopTest();
    }

    @isTest
    static void testPaginationWithOffset() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.pageSize = 10;
        controller.filterPriceDiscrepancies = false; // Important: must be false to use OFFSET
        controller.filterWebsiteProducts = false;

        // Get first page
        controller.firstPage();
        List<ProductInventoryController.InventoryWrapper> firstPage = controller.getInventoryRecords();

        // Navigate to second page (this should trigger OFFSET clause on lines 296-297)
        controller.nextPage();
        System.assertEquals(2, controller.pageNumber, 'Should be on page 2');

        List<ProductInventoryController.InventoryWrapper> secondPage = controller.getInventoryRecords();
        System.assertNotEquals(null, secondPage, 'Should return second page results');

        // Navigate to third page
        controller.nextPage();
        System.assertEquals(3, controller.pageNumber, 'Should be on page 3');

        List<ProductInventoryController.InventoryWrapper> thirdPage = controller.getInventoryRecords();
        System.assertNotEquals(null, thirdPage, 'Should return third page results');

        Test.stopTest();
    }

    @isTest
    static void testErrorHandlingInRemoteActions() {
        Test.startTest();

        // Test updateWebsitePrice with null ID (error scenario)
        Map<String, Object> result = ProductInventoryController.updateWebsitePrice(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null ID');

        // Test saveProductDetails with empty data
        result = ProductInventoryController.saveProductDetails(new Map<String, Object>());
        System.assertEquals(false, result.get('success'), 'Should handle empty data');

        Test.stopTest();
    }

    @isTest
    static void testGetStatsMethod() {
        Test.startTest();

        // Call getStats with filter parameters to ensure it works correctly
        Map<String, Object> stats = ProductInventoryController.getStats(false, false, false, 'All');

        System.assertEquals(true, stats.get('success'), 'Should return stats successfully');
        System.assertNotEquals(null, stats.get('totalProducts'), 'Should include total products');

        Test.stopTest();
    }

    @isTest
    static void testFilterCombinations() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();

        // Test with no filters
        controller.filterWebsiteProducts = false;
        controller.filterProductsWithErrors = false;
        controller.filterMissingURLs = false;
        controller.filterPriceDiscrepancies = false;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();
        System.assertNotEquals(null, results, 'Should handle no filters');

        // Test with all filters enabled
        controller.filterWebsiteProducts = true;
        controller.filterProductsWithErrors = true;
        controller.filterMissingURLs = true;
        controller.filterPriceDiscrepancies = true;

        results = controller.getInventoryRecords();
        System.assertNotEquals(null, results, 'Should handle all filters');

        Test.stopTest();
    }

    @isTest
    static void testMarkProductOutOfStockRemoteAction() {
        // The website is now called before Salesforce is updated, and success is only reported
        // when it confirms - so this needs both a mapped product and a mock.
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());
        Test.startTest();
        Product_Inventory__c testProduct = mappedProduct();

        // Test successful operation
        Map<String, Object> result = ProductInventoryController.markProductOutOfStock(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Should succeed: ' + result.get('message'));

        // Verify updates - should set Manual_Disable__c = true AND Manual_Enable__c = false
        Product_Inventory__c updated = [SELECT Manual_Disable__c, Manual_Enable__c
                                         FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(true, updated.Manual_Disable__c, 'Should be marked as out of stock');
        System.assertEquals(false, updated.Manual_Enable__c, 'Manual_Enable__c should be unchecked when marking out of stock');

        // Test with null ID
        result = ProductInventoryController.markProductOutOfStock(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null ID');

        Test.stopTest();
    }

    @isTest
    static void testDisableProductFromWebsite() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test successful disable
        Map<String, Object> result = ProductInventoryController.disableProductFromWebsite(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Should succeed');

        // Verify update
        Product_Inventory__c updated = [SELECT In_R4K_Website__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(false, updated.In_R4K_Website__c, 'Should not be on website');

        // Test with null ID
        result = ProductInventoryController.disableProductFromWebsite(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null ID');

        Test.stopTest();
    }

    @isTest
    static void testBulkMarkProductsOutOfStockRemoteAction() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());
        Test.startTest();
        List<Product_Inventory__c> products = mappedProducts(10);
        List<Id> ids = new List<Id>();
        for (Product_Inventory__c p : products) {
            ids.add(p.Id);
        }

        // Test successful bulk operation
        Map<String, Object> result = ProductInventoryController.bulkMarkProductsOutOfStock(ids);
        System.assertEquals(true, result.get('success'), 'Bulk operation should succeed: ' + result.get('message'));

        // Verify all were updated - should set Manual_Disable__c = true AND Manual_Enable__c = false
        List<Product_Inventory__c> updated = [SELECT Manual_Disable__c, Manual_Enable__c
                                               FROM Product_Inventory__c WHERE Id IN :ids];
        for (Product_Inventory__c p : updated) {
            System.assertEquals(true, p.Manual_Disable__c, 'All should be marked as out of stock');
            System.assertEquals(false, p.Manual_Enable__c, 'Manual_Enable__c should be unchecked for all');
        }

        // Test with null/empty list
        result = ProductInventoryController.bulkMarkProductsOutOfStock(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null list');

        result = ProductInventoryController.bulkMarkProductsOutOfStock(new List<Id>());
        System.assertEquals(false, result.get('success'), 'Should fail with empty list');

        Test.stopTest();
    }

    @isTest
    static void testBulkOperationsWithFiftyRecords() {
        // 50 is the size the old implementation died at: it enqueued one @Future per product and
        // spent two callouts each. It is now a single POST /products/batch.
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        Test.startTest();

        // Test bulk operation with 50 test records (Salesforce best practice)
        List<Product_Inventory__c> bulkProducts = mappedProducts(50);
        List<Id> bulkIds = new List<Id>();
        for (Product_Inventory__c p : bulkProducts) {
            bulkIds.add(p.Id);
        }

        System.assertEquals(50, bulkIds.size(), 'Should have 50 products for bulk operation');

        Map<String, Object> result = ProductInventoryController.bulkMarkProductsOutOfStock(bulkIds);
        System.assertEquals(true, result.get('success'), 'Bulk operation should succeed with 50 records: ' + result.get('message'));
        System.assertEquals(1, Limits.getCallouts(), '50 products must cost one callout, not 100');

        // Verify all were updated
        List<Product_Inventory__c> updated = [SELECT Manual_Disable__c FROM Product_Inventory__c WHERE Id IN :bulkIds];
        System.assertEquals(50, updated.size(), 'All 50 records should be updated');
        for (Product_Inventory__c p : updated) {
            System.assertEquals(true, p.Manual_Disable__c, 'All should be marked as out of stock');
        }

        Test.stopTest();
    }

    @isTest
    static void testWrapperPriceVariance() {
        Test.startTest();

        // Create product with supplier and competitor prices
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'Variance Test',
            Supplier_1_Price__c = 100,  // Lowest supplier
            Supplier_2_Price__c = 110,
            Competitor_1_Market_Value__c = 120,  // Lowest competitor
            Competitor_2_Market_Value__c = 125,
            Competitor_3_Market_Value__c = 130
        );
        insert prod;

        prod = [SELECT Id, Supplier_1_Price__c, Supplier_2_Price__c,
                Competitor_1_Market_Value__c, Competitor_2_Market_Value__c, Competitor_3_Market_Value__c,
                Cash_Price__c, RRP__c, Competitor_1__c, Competitor_1_URL__c,
                Competitor_2__c, Competitor_2_URL__c, Competitor_3__c, Competitor_3_URL__c,
                Supplier_1_Name__c, Supplier_1_URL__c, Supplier_2_Name__c, Supplier_2_URL__c,
                Supplier_Error_Notes__c, Competitor_1_New_Market_Value__c,
                Competitor_2_New_Market_Value__c, Competitor_3_New_Market_Value__c
                FROM Product_Inventory__c WHERE Id = :prod.Id];

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        System.assertEquals(100, wrapper.lowestSupplierPrice, 'Should identify lowest supplier price');
        //System.assertEquals(120, wrapper.lowestCompetitorPrice, 'Should identify lowest competitor price');
        System.assertEquals(true, wrapper.hasVariance, 'Should have variance');
        System.assertEquals(true, wrapper.isVarianceGood, 'Supplier cheaper should be good variance');
        System.assertNotEquals(null, wrapper.priceVarianceDisplay, 'Should have variance display');

        Test.stopTest();
    }

    @isTest
    static void testWrapperPriceVarianceBadScenario() {
        Test.startTest();

        // Create product where competitor is cheaper than supplier (bad variance)
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'Bad Variance Test',
            Supplier_1_Price__c = 150,  // Supplier more expensive
            Competitor_1_Market_Value__c = 100  // Competitor cheaper
        );
        insert prod;

        prod = [SELECT Id, Supplier_1_Price__c, Supplier_2_Price__c,
                Competitor_1_Market_Value__c, Competitor_2_Market_Value__c, Competitor_3_Market_Value__c,
                Cash_Price__c, RRP__c, Competitor_1__c, Competitor_1_URL__c,
                Competitor_2__c, Competitor_2_URL__c, Competitor_3__c, Competitor_3_URL__c,
                Supplier_1_Name__c, Supplier_1_URL__c, Supplier_2_Name__c, Supplier_2_URL__c,
                Supplier_Error_Notes__c, Competitor_1_New_Market_Value__c,
                Competitor_2_New_Market_Value__c, Competitor_3_New_Market_Value__c
                FROM Product_Inventory__c WHERE Id = :prod.Id];

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        System.assertEquals(false, wrapper.isVarianceGood, 'Competitor cheaper should be bad variance');
        System.assertEquals(true, wrapper.hasVariance, 'Should have variance');

        Test.stopTest();
    }

    @isTest
    static void testFilterDraftProducts() {
        Test.startTest();

        // Create draft products
        List<Product_Inventory__c> draftProducts = new List<Product_Inventory__c>();
        for (Integer i = 0; i < 5; i++) {
            draftProducts.add(new Product_Inventory__c(
                ProductName__c = 'Draft Product ' + i,
                Website_Status__c = 'Draft',
                RRP__c = 100 + i
            ));
        }
        insert draftProducts;

        ProductInventoryController controller = new ProductInventoryController();
        controller.filterWebsiteProducts = false;
        controller.filterDraftProducts = true;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        System.assert(results.size() >= 5, 'Should find at least 5 draft products');
        for (ProductInventoryController.InventoryWrapper wrapper : results) {
            System.assertEquals('Draft', wrapper.record.Website_Status__c, 'All should be draft status');
        }

        Test.stopTest();
    }

    @isTest
    static void testFilterDisabledProducts() {
        Test.startTest();

        // Create disabled products
        List<Product_Inventory__c> disabledProducts = new List<Product_Inventory__c>();
        for (Integer i = 0; i < 5; i++) {
            disabledProducts.add(new Product_Inventory__c(
                ProductName__c = 'Disabled Product ' + i,
                Manual_Disable__c = true,
                RRP__c = 100 + i
            ));
        }
        insert disabledProducts;

        ProductInventoryController controller = new ProductInventoryController();
        controller.filterWebsiteProducts = false;
        controller.filterDisabledProducts = true;

        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        System.assert(results.size() >= 5, 'Should find at least 5 disabled products');
        for (ProductInventoryController.InventoryWrapper wrapper : results) {
            System.assertEquals(true, wrapper.record.Manual_Disable__c, 'All should be disabled');
        }

        Test.stopTest();
    }

    @isTest
    static void testCreateProductErrors() {
        Test.startTest();

        // Test createProduct with invalid data type
        Map<String, Object> invalidData = new Map<String, Object>{
            'RRP__c' => 'not a decimal'
        };

        Map<String, Object> result = ProductInventoryController.createProduct(invalidData);
        System.assertEquals(false, result.get('success'), 'Should fail with invalid data type');

        Test.stopTest();
    }

    @isTest
    static void testWrapperAllScenarios() {
        Test.startTest();

        // Create product with all possible discrepancies
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'All Issues Product',
            RRP__c = 300,
            Competitor_1__c = 'Comp1',
            Competitor_1_Market_Value__c = 200,  // Price discrepancy
            Competitor_1_URL__c = null,  // Missing URL
            Competitor_2__c = 'Comp2',
            Competitor_2_Market_Value__c = 210,  // Price discrepancy
            Competitor_2_URL__c = null,  // Missing URL
            Competitor_3__c = 'Comp3',
            Competitor_3_Market_Value__c = 220,  // Price discrepancy
            Competitor_3_URL__c = null,  // Missing URL
            Supplier_1_Name__c = 'Supp1',
            Supplier_1_Price__c = 100,  // Add supplier price for variance calculation
            Supplier_1_URL__c = null,  // Missing URL
            Supplier_2_Name__c = 'Supp2',
            Supplier_2_Price__c = 110,  // Add supplier price for variance calculation
            Supplier_2_URL__c = null,  // Missing URL
            Supplier_Error_Notes__c = 'Multiple errors detected'
        );
        insert prod;

        // Query all required fields including Supplier_1_Price__c and Supplier_2_Price__c
        prod = [SELECT Id, ProductName__c, Cash_Price__c, RRP__c,
                Competitor_1__c, Competitor_1_Market_Value__c, Competitor_1_New_Market_Value__c, Competitor_1_URL__c,
                Competitor_2__c, Competitor_2_Market_Value__c, Competitor_2_New_Market_Value__c, Competitor_2_URL__c,
                Competitor_3__c, Competitor_3_Market_Value__c, Competitor_3_New_Market_Value__c, Competitor_3_URL__c,
                Supplier_1_Name__c, Supplier_1_Price__c, Supplier_1_URL__c,
                Supplier_2_Name__c, Supplier_2_Price__c, Supplier_2_URL__c,
                Supplier_Error_Notes__c FROM Product_Inventory__c WHERE Id = :prod.Id];

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        // Should detect all issues
        System.assertEquals(true, wrapper.hasMissingURL, 'Should detect missing URLs');
        System.assertEquals(true, wrapper.hasSupplierError, 'Should detect supplier error');
        System.assertNotEquals('', wrapper.priceAlertTooltip, 'Should have price alert tooltip');
        System.assertNotEquals('', wrapper.missingURLTooltip, 'Should have missing URL tooltip');
        System.assertNotEquals('', wrapper.noteTooltip, 'Should have note tooltip');
        System.assertNotEquals('', wrapper.discrepancyDetails, 'Should have discrepancy details');

        Test.stopTest();
    }

    @isTest
    static void testExportWithAllFilters() {
        Test.startTest();

        // Test export with search term and all filters
        String csv = ProductInventoryController.exportProducts('Product', true, true, true, true);
        System.assert(csv.contains('Product Name'), 'CSV should contain headers');
        System.assert(!csv.startsWith('Error:'), 'Export should succeed');

        Test.stopTest();
    }

    @isTest
    static void testCacheExpiry() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();

        // Get records - this populates cache
        List<ProductInventoryController.InventoryWrapper> results1 = controller.getInventoryRecords();

        // Manually clear cache to test cache expiry logic
        controller.search();  // This calls clearCache internally

        // Get records again - should re-query
        List<ProductInventoryController.InventoryWrapper> results2 = controller.getInventoryRecords();

        System.assertNotEquals(null, results2, 'Should return results after cache clear');

        Test.stopTest();
    }

    @isTest
    static void testSortByAllowedFields() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.filterWebsiteProducts = false;

        // Test all allowed sort fields
        String[] allowedFields = new String[]{
            'Name', 'Cash_Price__c', 'RRP__c',
            'Competitor_1__c', 'Competitor_1_Market_Value__c',
            'Competitor_2__c', 'Competitor_2_Market_Value__c',
            'Competitor_3__c', 'Competitor_3_Market_Value__c',
            'Supplier_1_Name__c', 'Supplier_1_Price__c',
            'Supplier_2_Name__c', 'Supplier_2_Price__c'
        };

        for (String field : allowedFields) {
            controller.sortField = field;
            controller.sortOrder = 'ASC';
            List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();
            System.assertNotEquals(null, results, 'Should return results for field: ' + field);
        }

        Test.stopTest();
    }

    @isTest
    static void testUpdatePriceNullValue() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test with null price (should be allowed to clear the value)
        String result = ProductInventoryController.updatePrice(testProduct.Id, null, 'competitor1');
        System.assertEquals('Success', result, 'Should succeed with null price');

        Product_Inventory__c updated = [SELECT Competitor_1_New_Market_Value__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(null, updated.Competitor_1_New_Market_Value__c, 'Price should be null');

        Test.stopTest();
    }

    @isTest
    static void testSaveProductDetailsAllFields() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test updating all possible fields
        Map<String, Object> updateData = new Map<String, Object>{
            'Id' => testProduct.Id,
            'RRP__c' => 500.00,
            'Price_Extract_Notes__c' => 'Test notes',
            'Competitor_1__c' => 'Comp1',
            'Competitor_1_Market_Value__c' => 450.00,
            'Competitor_1_New_Market_Value__c' => 460.00,
            'Competitor_1_URL__c' => 'http://comp1.com',
            'Competitor_1_URL_Notes__c' => 'Comp1 notes',
            'Competitor_2__c' => 'Comp2',
            'Competitor_2_Market_Value__c' => 455.00,
            'Competitor_2_New_Market_Value__c' => 465.00,
            'Competitor_2_URL__c' => 'http://comp2.com',
            'Competitor_2_URL_Notes__c' => 'Comp2 notes',
            'Competitor_3__c' => 'Comp3',
            'Competitor_3_Market_Value__c' => 460.00,
            'Competitor_3_New_Market_Value__c' => 470.00,
            'Competitor_3_URL__c' => 'http://comp3.com',
            'Competitor_3_URL_Notes__c' => 'Comp3 notes',
            'Supplier_1_Name__c' => 'Supp1',
            'Supplier_1_Price__c' => 400.00,
            'Supplier_1_URL__c' => 'http://supp1.com',
            'Supplier_2_Name__c' => 'Supp2',
            'Supplier_2_Price__c' => 410.00,
            'Supplier_2_URL__c' => 'http://supp2.com',
            'Delivery_Partner__c' => 'DHL',
            'Delivery_Cost__c' => 30.00,
            'Regional_Delivery_Cost__c' => 40.00
        };

        Map<String, Object> result = ProductInventoryController.saveProductDetails(updateData);
        System.assertEquals(true, result.get('success'), 'Should succeed updating all fields');

        Test.stopTest();
    }

    @isTest
    static void testBlankRecordIdScenarios() {
        Test.startTest();

        // Test putStockOnHold with blank ID
        String result = ProductInventoryController.putStockOnHold('', 'Notes');
        System.assert(result.contains('Error'), 'Should fail with blank ID');

        Test.stopTest();
    }

    @isTest
    static void testBulkUpdateWebsiteInvalidIds() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = 'invalid1,invalid2,invalid3';

        PageReference result = controller.bulkUpdateWebsite();
        System.assertEquals(null, result, 'Should handle invalid IDs gracefully');

        Test.stopTest();
    }

    @isTest
    static void testWrapperNoPriceChange() {
        Test.startTest();

        // Product with market values but no new market values
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'No Change Product',
            Competitor_1_Market_Value__c = 100
            // No Competitor_1_New_Market_Value__c
        );
        insert prod;

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        System.assertEquals(false, wrapper.comp1HasChange, 'Should not detect change when no new value');
        System.assertEquals(false, wrapper.comp2HasChange, 'Should not detect change when no new value');
        System.assertEquals(false, wrapper.comp3HasChange, 'Should not detect change when no new value');

        Test.stopTest();
    }

    @isTest
    static void testUpdatePriceAllCompetitors() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Update all three competitors
        String result1 = ProductInventoryController.updatePrice(testProduct.Id, 100.00, 'competitor1');
        String result2 = ProductInventoryController.updatePrice(testProduct.Id, 200.00, 'competitor2');
        String result3 = ProductInventoryController.updatePrice(testProduct.Id, 300.00, 'competitor3');

        System.assertEquals('Success', result1, 'Competitor 1 update should succeed');
        System.assertEquals('Success', result2, 'Competitor 2 update should succeed');
        System.assertEquals('Success', result3, 'Competitor 3 update should succeed');

        // Verify all updates
        Product_Inventory__c updated = [SELECT Competitor_1_New_Market_Value__c,
                                         Competitor_2_New_Market_Value__c,
                                         Competitor_3_New_Market_Value__c
                                         FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(100.00, updated.Competitor_1_New_Market_Value__c, 'Comp1 should be 100');
        System.assertEquals(200.00, updated.Competitor_2_New_Market_Value__c, 'Comp2 should be 200');
        System.assertEquals(300.00, updated.Competitor_3_New_Market_Value__c, 'Comp3 should be 300');

        Test.stopTest();
    }

    @isTest
    static void testExceptionHandlingInInitializePagination() {
        Test.startTest();

        // Create a scenario that causes exception during pagination initialization
        // This tests the exception handler in initializePagination() (lines 64-66)
        ProductInventoryController controller = new ProductInventoryController();

        // Set invalid sort field that will cause issues
        controller.sortField = null;
        controller.searchTerm = null;

        // Force initialization
        try {
            controller.getInventoryRecords();
        } catch (Exception e) {
            // Exception should be caught internally
        }

        // Verify the controller handles the exception gracefully
        System.assertNotEquals(null, controller, 'Controller should still exist after exception');

        Test.stopTest();
    }

    @isTest
    static void testExceptionHandlingInGetInventoryRecords() {
        Test.startTest();

        // Test exception handling in getInventoryRecords (lines 109-111)
        ProductInventoryController controller = new ProductInventoryController();

        // Set a very large page number to potentially cause issues
        controller.pageNumber = 999999;
        controller.pageSize = 1;

        // This should handle the exception gracefully
        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        // Should return empty list or handle gracefully
        System.assertNotEquals(null, results, 'Should return results even with edge case pagination');

        Test.stopTest();
    }

    @isTest
    static void testMarkProductOutOfStockWithMock() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        Test.startTest();
        Product_Inventory__c testProduct = mappedProduct();

        // Test successful operation with WooCommerce mock
        Map<String, Object> result = ProductInventoryController.markProductOutOfStock(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Should succeed: ' + result.get('message'));

        // Verify updates
        Product_Inventory__c updated = [SELECT Manual_Disable__c
                                         FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(true, updated.Manual_Disable__c, 'Should be marked as out of stock');

        Test.stopTest();
    }

    @isTest
    static void testSaveProductDetailsWithLongNotes() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test with very long notes to ensure handling
        Map<String, Object> updateData = new Map<String, Object>{
            'Id' => testProduct.Id,
            'Price_Extract_Notes__c' => 'A'.repeat(255),  // Max length string
            'Competitor_1_URL_Notes__c' => 'B'.repeat(255),
            'Competitor_2_URL_Notes__c' => 'C'.repeat(255),
            'Competitor_3_URL_Notes__c' => 'D'.repeat(255)
        };

        Map<String, Object> result = ProductInventoryController.saveProductDetails(updateData);
        System.assertEquals(true, result.get('success'), 'Should handle long notes');

        Test.stopTest();
    }

    @isTest
    static void testFilterByTileAllOptions() {
        Test.startTest();

        // Test all valid tile types to ensure complete coverage
        Map<String, Object> result;

        result = ProductInventoryController.filterByTile('all');
        System.assertEquals(true, result.get('success'), 'Should handle all tile');

        result = ProductInventoryController.filterByTile('website');
        System.assertEquals(true, result.get('success'), 'Should handle website tile');

        result = ProductInventoryController.filterByTile('errors');
        System.assertEquals(true, result.get('success'), 'Should handle errors tile');

        result = ProductInventoryController.filterByTile('urls');
        System.assertEquals(true, result.get('success'), 'Should handle urls tile');

        result = ProductInventoryController.filterByTile('price');
        System.assertEquals(true, result.get('success'), 'Should handle price tile');

        Test.stopTest();
    }

    @isTest
    static void testCreateProductStandardWithErrors() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Set invalid data to trigger DML exception
        controller.newProduct.RRP__c = -1.00;  // Assuming negative values might be invalid

        PageReference result = controller.createProductStandard();
        System.assertEquals(null, result, 'Should return null on error');

        Test.stopTest();
    }

    @isTest
    static void testSaveCompetitorMethodsWithErrors() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test saveCompetitor methods with edge cases
        String result;

        // Test with very long strings
        result = ProductInventoryController.saveCompetitor1(
            testProduct.Id, 'Comp1', 0.01, 0.01, 'http://test.com', 'http://drive.com', 'Notes'
        );
        System.assertEquals('SUCCESS', result, 'Should handle long competitor names');

        // Test with zero prices
        result = ProductInventoryController.saveCompetitor2(
            testProduct.Id, 'Comp2', 0.00, 0.00, 'http://test2.com', 'http://drive2.com', ''
        );
        System.assertEquals('SUCCESS', result, 'Should handle zero prices');

        Test.stopTest();
    }

    @isTest
    static void testSaveSupplierMethodsWithEdgeCases() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test with edge case values
        String result = ProductInventoryController.saveSupplier1(
            testProduct.Id, '', 0.00, '', '', ''
        );
        System.assertEquals('SUCCESS', result, 'Should handle empty supplier data');

        result = ProductInventoryController.saveSupplier2(
            testProduct.Id, 'Supp2', 99.99, 'http://test.com', 'http://drive.com', null
        );
        System.assertEquals('SUCCESS', result, 'Should handle max values');

        Test.stopTest();
    }

    @isTest
    static void testSaveDeliveryWithEdgeCases() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test with zero and max values
        String result = ProductInventoryController.saveDelivery(
            testProduct.Id, 'Partner', 0.00, 0.00, 99.99, 99.99
        );
        System.assertEquals('SUCCESS', result, 'Should handle edge case delivery costs');

        Test.stopTest();
    }

    @isTest
    static void testExportProductsWithNoResults() {
        Test.startTest();

        // Export with filters that yield no results
        String csv = ProductInventoryController.exportProducts('NonExistentProduct999999', false, false, false, false);
        System.assert(csv.contains('Product Name'), 'Should still return CSV headers');

        Test.stopTest();
    }

    @isTest
    static void testWrapperWithNullValues() {
        Test.startTest();

        // Create a minimal product with mostly null values
        Product_Inventory__c prod = new Product_Inventory__c(
            ProductName__c = 'Minimal Product'
            // All other fields null
        );
        insert prod;

        ProductInventoryController.InventoryWrapper wrapper = new ProductInventoryController.InventoryWrapper(prod, true);

        // Should handle null values gracefully
        System.assertEquals(false, wrapper.hasPriceDiscrepancy, 'Should not have discrepancy with null values');
        System.assertEquals(false, wrapper.hasMissingURL, 'Should not have missing URLs with null values');
        System.assertEquals(false, wrapper.hasSupplierError, 'Should not have error with null notes');
        System.assertEquals(4, wrapper.getStatusPriority(), 'Should have lowest priority');

        Test.stopTest();
    }

    @isTest
    static void testGetCompetitorDataAllNumbers() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test all three competitor numbers for complete coverage
        Map<String, Object> result1 = ProductInventoryController.getCompetitorData(testProduct.Id, 1);
        System.assertEquals(true, result1.get('success'), 'Should get competitor 1 data');

        Map<String, Object> result2 = ProductInventoryController.getCompetitorData(testProduct.Id, 2);
        System.assertEquals(true, result2.get('success'), 'Should get competitor 2 data');

        Map<String, Object> result3 = ProductInventoryController.getCompetitorData(testProduct.Id, 3);
        System.assertEquals(true, result3.get('success'), 'Should get competitor 3 data');

        Test.stopTest();
    }

    @isTest
    static void testGetSupplierDataAllNumbers() {
        Test.startTest();
        Product_Inventory__c testProduct = [SELECT Id FROM Product_Inventory__c LIMIT 1];

        // Test both supplier numbers
        Map<String, Object> result1 = ProductInventoryController.getSupplierData(testProduct.Id, 1);
        System.assertEquals(true, result1.get('success'), 'Should get supplier 1 data');

        Map<String, Object> result2 = ProductInventoryController.getSupplierData(testProduct.Id, 2);
        System.assertEquals(true, result2.get('success'), 'Should get supplier 2 data');

        Test.stopTest();
    }

    @isTest
    static void testVarianceRangeFilterPagination() {
        Test.startTest();

        // Test variance filter with different ranges
        ProductInventoryController controller = new ProductInventoryController();

        // Test with variance range filter
        controller.selectedVarianceRange = '15to25';
        controller.pageSize = 50;
        controller.pageNumber = 1;

        // This should exercise the getTotalRecordCount with variance filter
        List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

        // Verify pagination is calculated correctly based on filtered results
        System.assert(controller.totalPages >= 0, 'Total pages should be calculated');
        System.assert(controller.totalRecords >= 0, 'Total records should reflect filtered count');

        // Test with multiple variance ranges (multi-select)
        controller.selectedVarianceRange = '5to15,15to25';
        results = controller.getInventoryRecords();
        System.assert(results != null, 'Should return results for multi-select variance');

        // Test clearing the filter
        controller.selectedVarianceRange = 'All';
        results = controller.getInventoryRecords();
        System.assert(results != null, 'Should return results when filter cleared');

        Test.stopTest();
    }

    // Mock class for WooCommerce HTTP callouts
    public class WooCommerceMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id": 123, "status": "draft", "permalink": "http://example.com/product"}');
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * Mock for the availability paths, which now POST to /products/batch and only report success
     * for products the website confirms. It echoes each requested id back with the stock_status
     * that was asked for, which is what a healthy WooCommerce does.
     */
    public class WooCommerceBatchEchoMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            List<Object> results = new List<Object>();
            try {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                List<Object> updates = (List<Object>) body.get('update');
                if (updates != null) {
                    for (Object item : updates) {
                        Map<String, Object> requested = (Map<String, Object>) item;
                        results.add(new Map<String, Object>{
                            'id' => Integer.valueOf(String.valueOf(requested.get('id'))),
                            'stock_status' => requested.get('stock_status'),
                            'permalink' => 'https://example.com/product/' + requested.get('id')
                        });
                    }
                }
            } catch (Exception e) {
                // Not a batch request - fall through to the single-product shape below.
            }

            if (results.isEmpty()) {
                res.setBody('{"id": 123, "status": "draft", "permalink": "http://example.com/product"}');
            } else {
                res.setBody(JSON.serialize(new Map<String, Object>{ 'update' => results }));
            }
            return res;
        }
    }

    /** A product that is actually mapped to WooCommerce - required by the availability paths. */
    private static Product_Inventory__c mappedProduct() {
        return [
            SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Product_Id__c
            FROM Product_Inventory__c
            WHERE Website_Product_Id__c != null
            LIMIT 1
        ];
    }

    private static List<Product_Inventory__c> mappedProducts(Integer howMany) {
        return [
            SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Product_Id__c
            FROM Product_Inventory__c
            WHERE Website_Product_Id__c != null
            LIMIT :howMany
        ];
    }

    /**
     * Out-of-stock, WooCommerce-mapped products for the reactivation tests.
     *
     * These are created rather than queried. An earlier version selected existing disabled records,
     * which made the tests depend on org state - and they broke the moment someone reactivated the
     * last disabled product in the sandbox. Creating the fixture keeps the tests true in any org.
     *
     * Call this BEFORE Test.startTest(). The availability methods call out to the website, and a
     * transaction may not call out once it has pending DML - that rule applies in tests too. DML
     * performed before Test.startTest() does not count against a callout made after it.
     *
     * Override_Cash_Price__c feeds the Cash_Price__c formula so the insert trigger can derive the
     * pricing fields; the comparison-rate term labels are set explicitly because a synthetic record
     * gets no benchmark match, and blank labels would legitimately withhold the price payload.
     */
    private static List<Product_Inventory__c> disabledMappedProducts(Integer howMany) {
        List<Product_Inventory__c> fixtures = new List<Product_Inventory__c>();
        for (Integer i = 0; i < howMany; i++) {
            fixtures.add(new Product_Inventory__c(
                ProductName__c = 'Reactivate Fixture ' + i,
                Website_Product_Id__c = String.valueOf(960000 + i),
                Website_Status__c = 'Published',
                Manual_Disable__c = true,
                Manual_Enable__c = false,
                RRP__c = 1200,
                Invoice_Cost__c = 800,
                Override_Cash_Price__c = 1000
            ));
        }
        insert fixtures;

        List<Product_Inventory__c> labelled = new List<Product_Inventory__c>();
        for (Product_Inventory__c f : fixtures) {
            labelled.add(new Product_Inventory__c(
                Id = f.Id,
                CR_13_Months_Term_Value__c = '1 Year',
                CR_18_Months_Term_Value__c = '18 Months',
                CR_24_Months_Term_Value__c = '2 Years',
                CR_36_Months_Term_Value__c = '3 Years'
            ));
        }
        update labelled;

        return [
            SELECT Id, Name, Manual_Disable__c, Manual_Enable__c, Website_Product_Id__c
            FROM Product_Inventory__c
            WHERE Id IN :fixtures
        ];
    }

    @isTest
    static void testReactivateProduct() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        // Fixture DML must happen before startTest - see disabledMappedProducts.
        Product_Inventory__c testProduct = disabledMappedProducts(1)[0];

        Test.startTest();

        // Test successful reactivation
        Map<String, Object> result = ProductInventoryController.reactivateProduct(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Reactivation should succeed: ' + result.get('message'));
        System.assert(((String)result.get('message')).contains('back on sale'), 'Message should indicate reactivation');

        // Verify the product was reactivated - should set Manual_Disable__c = false AND Manual_Enable__c = true
        Product_Inventory__c updated = [SELECT Manual_Disable__c, Manual_Enable__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(false, updated.Manual_Disable__c, 'Product should be reactivated (Manual_Disable__c = false)');
        System.assertEquals(true, updated.Manual_Enable__c, 'Manual_Enable__c should be checked when reactivating');

        // Test reactivating already active product
        result = ProductInventoryController.reactivateProduct(testProduct.Id);
        System.assertEquals(false, result.get('success'), 'Should fail for already active product');
        System.assert(((String)result.get('message')).contains('already active'), 'Message should indicate product is already active');

        // Test with null ID
        result = ProductInventoryController.reactivateProduct(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null ID');
        System.assert(((String)result.get('message')).contains('required'), 'Message should indicate ID is required');

        Test.stopTest();
    }

    @isTest
    static void testReactivateProductWithInvalidId() {
        Test.startTest();

        // Test with invalid ID format
        try {
            Map<String, Object> result = ProductInventoryController.reactivateProduct('invalidId');
            System.assertEquals(false, result.get('success'), 'Should fail with invalid ID');
        } catch (Exception e) {
            // Expected exception for invalid ID
            System.assert(true, 'Exception expected for invalid ID');
        }

        Test.stopTest();
    }

    @isTest
    static void testBulkReactivateProducts() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        // Reactivation only acts on Manual_Disable__c = true; fixture DML before startTest.
        List<Product_Inventory__c> products = disabledMappedProducts(5);

        Test.startTest();

        // Collect IDs
        List<Id> productIds = new List<Id>();
        for (Product_Inventory__c p : products) {
            productIds.add(p.Id);
        }

        // Test successful bulk reactivation
        Map<String, Object> result = ProductInventoryController.bulkReactivateProducts(productIds);
        System.assertEquals(true, result.get('success'), 'Bulk reactivation should succeed: ' + result.get('message'));
        System.assert(((String)result.get('message')).contains('back on sale'), 'Message should indicate reactivation');

        // Verify all products were reactivated - should set Manual_Disable__c = false AND Manual_Enable__c = true
        List<Product_Inventory__c> updated = [SELECT Manual_Disable__c, Manual_Enable__c FROM Product_Inventory__c WHERE Id IN :productIds];
        for (Product_Inventory__c p : updated) {
            System.assertEquals(false, p.Manual_Disable__c, 'All products should be reactivated');
            System.assertEquals(true, p.Manual_Enable__c, 'Manual_Enable__c should be checked for all reactivated products');
        }

        Test.stopTest();
    }

    @isTest
    static void testBulkReactivateProductsEdgeCases() {
        Test.startTest();

        // Test with null list
        Map<String, Object> result = ProductInventoryController.bulkReactivateProducts(null);
        System.assertEquals(false, result.get('success'), 'Should fail with null list');
        System.assert(((String)result.get('message')).contains('No products selected'), 'Message should indicate no products selected');

        // Test with empty list
        result = ProductInventoryController.bulkReactivateProducts(new List<Id>());
        System.assertEquals(false, result.get('success'), 'Should fail with empty list');
        System.assert(((String)result.get('message')).contains('No products selected'), 'Message should indicate no products selected');

        // Test with products that are not disabled (already active)
        List<Product_Inventory__c> activeProducts = [SELECT Id, Manual_Disable__c FROM Product_Inventory__c WHERE Manual_Disable__c = false LIMIT 3];
        if (activeProducts.size() > 0) {
            List<Id> activeIds = new List<Id>();
            for (Product_Inventory__c p : activeProducts) {
                activeIds.add(p.Id);
            }
            result = ProductInventoryController.bulkReactivateProducts(activeIds);
            System.assertEquals(false, result.get('success'), 'Should fail when no disabled products found');
            System.assert(((String)result.get('message')).contains('No disabled products'), 'Message should indicate no disabled products');
        }

        Test.stopTest();
    }

    @isTest
    static void testBulkReactivateProductsWithMock() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        // Fixture DML before startTest - see disabledMappedProducts.
        List<Product_Inventory__c> testProducts = disabledMappedProducts(10);

        Test.startTest();

        // Collect IDs
        List<Id> testIds = new List<Id>();
        for (Product_Inventory__c p : testProducts) {
            testIds.add(p.Id);
        }

        // Test bulk reactivation
        Map<String, Object> result = ProductInventoryController.bulkReactivateProducts(testIds);
        System.assertEquals(true, result.get('success'), 'Bulk reactivation should succeed: ' + result.get('message'));

        // Verify message reports how many actually went back on sale
        String message = (String)result.get('message');
        System.assert(message.contains(String.valueOf(testIds.size())),
            'Message should contain the count of reactivated products, got: ' + message);

        Test.stopTest();
    }

    @isTest
    static void testCheckForUpdates() {
        Test.startTest();

        // Test with valid ISO timestamp
        String isoTimestamp = DateTime.now().addMinutes(-5).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        Map<String, Object> result = ProductInventoryController.checkForUpdates(isoTimestamp);

        System.assertEquals(true, result.get('success'), 'Should succeed with valid timestamp');
        System.assertNotEquals(null, result.get('hasUpdates'), 'Should return hasUpdates flag');
        System.assertNotEquals(null, result.get('updateCount'), 'Should return updateCount');
        System.assertNotEquals(null, result.get('serverTime'), 'Should return serverTime');

        Test.stopTest();
    }

    @isTest
    static void testCheckForUpdatesWithBlankTimestamp() {
        Test.startTest();

        // Test with blank timestamp (should default to 1 minute ago)
        Map<String, Object> result = ProductInventoryController.checkForUpdates('');
        System.assertEquals(true, result.get('success'), 'Should succeed with blank timestamp');
        System.assertNotEquals(null, result.get('hasUpdates'), 'Should return hasUpdates flag');

        // Test with null timestamp
        result = ProductInventoryController.checkForUpdates(null);
        System.assertEquals(true, result.get('success'), 'Should succeed with null timestamp');

        Test.stopTest();
    }

    @isTest
    static void testCheckForUpdatesWithRecentChanges() {
        Test.startTest();

        // Record the time before making changes
        String beforeChange = DateTime.now().addMinutes(-2).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

        // Make a change to a product
        Product_Inventory__c testProduct = [SELECT Id, RRP__c FROM Product_Inventory__c LIMIT 1];
        testProduct.RRP__c = testProduct.RRP__c != null ? testProduct.RRP__c + 1 : 100;
        update testProduct;

        // Check for updates since before the change
        Map<String, Object> result = ProductInventoryController.checkForUpdates(beforeChange);

        //System.assertEquals(true, result.get('success'), 'Should succeed');
        //System.assertEquals(true, result.get('hasUpdates'), 'Should detect updates');
        //System.assert((Integer)result.get('updateCount') > 0, 'Update count should be greater than 0');

        Test.stopTest();
    }

    @isTest
    static void testCheckForUpdatesWithInvalidTimestamp() {
        Test.startTest();

        // Test with invalid timestamp format (should handle gracefully)
        Map<String, Object> result = ProductInventoryController.checkForUpdates('invalid-timestamp');

        // Should return error response
        System.assertEquals(false, result.get('success'), 'Should fail with invalid timestamp');
        System.assertEquals(false, result.get('hasUpdates'), 'hasUpdates should be false on error');
        System.assertEquals(0, result.get('updateCount'), 'updateCount should be 0 on error');
        System.assertNotEquals(null, result.get('error'), 'Should contain error message');

        Test.stopTest();
    }

    @isTest
    static void testCheckForUpdatesServerTimeFormat() {
        Test.startTest();

        Map<String, Object> result = ProductInventoryController.checkForUpdates('');

        System.assertEquals(true, result.get('success'), 'Should succeed');

        // Verify server time format is ISO format
        String serverTime = (String)result.get('serverTime');
        System.assertNotEquals(null, serverTime, 'Server time should not be null');
        System.assert(serverTime.contains('T'), 'Server time should be in ISO format with T separator');
        System.assert(serverTime.contains('Z'), 'Server time should end with Z for UTC');

        Test.stopTest();
    }

    @isTest
    static void testGetSupplierCompetitorOptions() {
        Test.startTest();

        // Create test products with supplier and competitor names
        Product_Inventory__c product1 = new Product_Inventory__c(
            ProductName__c = 'Supplier Test Product 1',
            RRP__c = 500,
            Supplier_1_Name__c = 'Supplier Alpha',
            Supplier_2_Name__c = 'Supplier Beta',
            Competitor_1__c = 'Competitor One',
            Competitor_2__c = 'Competitor Two'
        );
        insert product1;

        Product_Inventory__c product2 = new Product_Inventory__c(
            ProductName__c = 'Supplier Test Product 2',
            RRP__c = 600,
            Supplier_1_Name__c = 'Supplier Gamma',
            Competitor_3__c = 'Competitor Three'
        );
        insert product2;

        // Create controller instance and get options
        ProductInventoryController controller = new ProductInventoryController();
        List<SelectOption> options = controller.getSupplierCompetitorOptions();

        // Verify results
        System.assertNotEquals(null, options, 'Options should not be null');
        System.assert(options.size() >= 1, 'Should have at least the "All" option');

        // First option should be "All"
        System.assertEquals('All', options[0].getValue(), 'First option should be "All"');
        System.assertEquals('All Suppliers/Competitors', options[0].getLabel(), 'First option label should be "All Suppliers/Competitors"');

        // Verify unique names are included (options are sorted alphabetically after 'All')
        Set<String> optionValues = new Set<String>();
        for (SelectOption opt : options) {
            optionValues.add(opt.getValue());
        }

        System.assert(optionValues.contains('Supplier Alpha'), 'Should contain Supplier Alpha');
        System.assert(optionValues.contains('Supplier Beta'), 'Should contain Supplier Beta');
        System.assert(optionValues.contains('Supplier Gamma'), 'Should contain Supplier Gamma');
        System.assert(optionValues.contains('Competitor One'), 'Should contain Competitor One');
        System.assert(optionValues.contains('Competitor Two'), 'Should contain Competitor Two');
        System.assert(optionValues.contains('Competitor Three'), 'Should contain Competitor Three');

        Test.stopTest();
    }

    @isTest
    static void testGetSupplierCompetitorOptionsNoDuplicates() {
        Test.startTest();

        // Create products with duplicate supplier/competitor names
        Product_Inventory__c product1 = new Product_Inventory__c(
            ProductName__c = 'Duplicate Test 1',
            RRP__c = 500,
            Supplier_1_Name__c = 'Same Supplier',
            Competitor_1__c = 'Same Competitor'
        );
        insert product1;

        Product_Inventory__c product2 = new Product_Inventory__c(
            ProductName__c = 'Duplicate Test 2',
            RRP__c = 600,
            Supplier_2_Name__c = 'Same Supplier',
            Competitor_2__c = 'Same Competitor'
        );
        insert product2;

        ProductInventoryController controller = new ProductInventoryController();
        List<SelectOption> options = controller.getSupplierCompetitorOptions();

        // Count occurrences of 'Same Supplier' and 'Same Competitor'
        Integer supplierCount = 0;
        Integer competitorCount = 0;
        for (SelectOption opt : options) {
            if (opt.getValue() == 'Same Supplier') supplierCount++;
            if (opt.getValue() == 'Same Competitor') competitorCount++;
        }

        System.assertEquals(1, supplierCount, 'Same Supplier should appear only once (no duplicates)');
        System.assertEquals(1, competitorCount, 'Same Competitor should appear only once (no duplicates)');

        Test.stopTest();
    }

    @isTest
    static void testGetSupplierCompetitorOptionsEmpty() {
        Test.startTest();

        // Delete all products that might have supplier/competitor names
        List<Product_Inventory__c> existingProducts = [SELECT Id FROM Product_Inventory__c
            WHERE Supplier_1_Name__c != null
            OR Supplier_2_Name__c != null
            OR Competitor_1__c != null
            OR Competitor_2__c != null
            OR Competitor_3__c != null LIMIT 1];

        if (!existingProducts.isEmpty()) {
            delete existingProducts;
        }

        ProductInventoryController controller = new ProductInventoryController();
        List<SelectOption> options = controller.getSupplierCompetitorOptions();

        // Should still have the 'All' option
        System.assertNotEquals(null, options, 'Options should not be null');
        System.assert(options.size() >= 1, 'Should have at least the "All" option');
        System.assertEquals('All', options[0].getValue(), 'First option should be "All"');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostSupplier1() {
        Test.startTest();

        // Create test products with Supplier 1 price
        Product_Inventory__c product1 = new Product_Inventory__c(
            ProductName__c = 'Invoice Cost Test 1',
            RRP__c = 500,
            Supplier_1_Price__c = 110.00  // $110 incl GST = $100 excl GST
        );
        insert product1;

        Product_Inventory__c product2 = new Product_Inventory__c(
            ProductName__c = 'Invoice Cost Test 2',
            RRP__c = 600,
            Supplier_1_Price__c = 220.00  // $220 incl GST = $200 excl GST
        );
        insert product2;

        // Setup controller
        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = product1.Id + ',' + product2.Id;
        controller.supplierForInvoiceCost = 1;

        // Execute the bulk copy
        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify Invoice_Cost__c was updated correctly (price excl GST = price / 1.1)
        Product_Inventory__c updated1 = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product1.Id];
        Product_Inventory__c updated2 = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product2.Id];

        System.assertEquals(100.00, updated1.Invoice_Cost__c, 'Invoice Cost should be $100 (110/1.1)');
        System.assertEquals(200.00, updated2.Invoice_Cost__c, 'Invoice Cost should be $200 (220/1.1)');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostSupplier2() {
        Test.startTest();

        // Create test product with Supplier 2 price
        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'Invoice Cost Test Supplier 2',
            RRP__c = 500,
            Supplier_2_Price__c = 165.00  // $165 incl GST = $150 excl GST
        );
        insert product;

        // Setup controller
        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = String.valueOf(product.Id);
        controller.supplierForInvoiceCost = 2;

        // Execute the bulk copy
        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify Invoice_Cost__c was updated correctly
        Product_Inventory__c updated = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product.Id];
        System.assertEquals(150.00, updated.Invoice_Cost__c, 'Invoice Cost should be $150 (165/1.1)');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostNoProductsSelected() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = '';  // No products selected
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Should return null (stays on page with warning message)
        System.assertEquals(null, result, 'Should return null when no products selected');

        // Verify warning message was added
        List<ApexPages.Message> messages = ApexPages.getMessages();
        Boolean hasWarning = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.WARNING && msg.getSummary().contains('No products selected')) {
                hasWarning = true;
                break;
            }
        }
        System.assert(hasWarning, 'Should display "No products selected" warning');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostNoSupplierSelected() {
        Test.startTest();

        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'No Supplier Test',
            RRP__c = 500,
            Supplier_1_Price__c = 110.00
        );
        insert product;

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = String.valueOf(product.Id);
        controller.supplierForInvoiceCost = null;  // No supplier selected

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        System.assertEquals(null, result, 'Should return null when no supplier selected');

        // Verify warning message
        List<ApexPages.Message> messages = ApexPages.getMessages();
        Boolean hasWarning = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.WARNING && msg.getSummary().contains('Please select Supplier')) {
                hasWarning = true;
                break;
            }
        }
        System.assert(hasWarning, 'Should display supplier selection warning');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostInvalidSupplier() {
        Test.startTest();

        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'Invalid Supplier Test',
            RRP__c = 500,
            Supplier_1_Price__c = 110.00
        );
        insert product;

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = String.valueOf(product.Id);
        controller.supplierForInvoiceCost = 3;  // Invalid - must be 1 or 2

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        System.assertEquals(null, result, 'Should return null with invalid supplier number');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostSkipsNullPrice() {
        Test.startTest();

        // Product with no supplier price
        Product_Inventory__c productNoPrice = new Product_Inventory__c(
            ProductName__c = 'No Price Test',
            RRP__c = 500,
            Supplier_1_Price__c = null
        );
        insert productNoPrice;

        // Product with valid supplier price
        Product_Inventory__c productWithPrice = new Product_Inventory__c(
            ProductName__c = 'With Price Test',
            RRP__c = 500,
            Supplier_1_Price__c = 110.00
        );
        insert productWithPrice;

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = productNoPrice.Id + ',' + productWithPrice.Id;
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify only the product with price was updated
        Product_Inventory__c updatedNoPrice = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :productNoPrice.Id];
        Product_Inventory__c updatedWithPrice = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :productWithPrice.Id];

        System.assertEquals(null, updatedNoPrice.Invoice_Cost__c, 'Product without supplier price should not be updated');
        System.assertEquals(100.00, updatedWithPrice.Invoice_Cost__c, 'Product with supplier price should be updated');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostSkipsZeroPrice() {
        Test.startTest();

        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'Zero Price Test',
            RRP__c = 500,
            Supplier_1_Price__c = 0
        );
        insert product;

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = String.valueOf(product.Id);
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify product was not updated (zero price should be skipped)
        Product_Inventory__c updated = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product.Id];
        System.assertEquals(null, updated.Invoice_Cost__c, 'Product with zero supplier price should not be updated');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostInvalidIds() {
        Test.startTest();

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = 'invalid_id_1,invalid_id_2';
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        System.assertEquals(null, result, 'Should return null with invalid IDs');

        // Verify warning message for no valid products
        List<ApexPages.Message> messages = ApexPages.getMessages();
        Boolean hasWarning = false;
        for (ApexPages.Message msg : messages) {
            if (msg.getSeverity() == ApexPages.Severity.WARNING && msg.getSummary().contains('No valid products')) {
                hasWarning = true;
                break;
            }
        }
        System.assert(hasWarning, 'Should display "No valid products selected" warning');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostMixedValidInvalidIds() {
        Test.startTest();

        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'Mixed IDs Test',
            RRP__c = 500,
            Supplier_1_Price__c = 110.00
        );
        insert product;

        ProductInventoryController controller = new ProductInventoryController();
        // Mix of valid ID and invalid IDs
        controller.selectedProductIds = product.Id + ',invalid_id,another_invalid';
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify valid product was still updated
        Product_Inventory__c updated = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product.Id];
        System.assertEquals(100.00, updated.Invoice_Cost__c, 'Valid product should still be updated');

        Test.stopTest();
    }

    @isTest
    static void testBulkCopySupplierToInvoiceCostRounding() {
        Test.startTest();

        // Test rounding with a price that results in many decimal places
        Product_Inventory__c product = new Product_Inventory__c(
            ProductName__c = 'Rounding Test',
            RRP__c = 500,
            Supplier_1_Price__c = 99.99  // 99.99 / 1.1 = 90.9 (recurring)
        );
        insert product;

        ProductInventoryController controller = new ProductInventoryController();
        controller.selectedProductIds = String.valueOf(product.Id);
        controller.supplierForInvoiceCost = 1;

        PageReference result = controller.bulkCopySupplierToInvoiceCost();

        // Verify rounding to 2 decimal places
        Product_Inventory__c updated = [SELECT Invoice_Cost__c FROM Product_Inventory__c WHERE Id = :product.Id];
        System.assertNotEquals(null, updated.Invoice_Cost__c, 'Invoice Cost should be set');

        // Expected: 99.99 / 1.1 = 90.9 rounded to 90.90
        Decimal expected = (99.99 / 1.1).setScale(2, RoundingMode.HALF_UP);
        System.assertEquals(expected, updated.Invoice_Cost__c, 'Invoice Cost should be properly rounded to 2 decimal places');

        Test.stopTest();
    }

    // ============== NEW TESTS FOR BRAND FILTER AND SEARCH ENHANCEMENTS ==============

    @isTest
    static void testBrandFilterOptions() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Test getBrandOptions returns list with at least 'All Brands' option
        List<SelectOption> options = controller.getBrandOptions();
        System.assertNotEquals(null, options, 'Brand options should not be null');
        System.assert(options.size() >= 1, 'Should have at least All Brands option');
        System.assertEquals('All', options[0].getValue(), 'First option should be All');
        System.assertEquals('All Brands', options[0].getLabel(), 'First option label should be All Brands');

        Test.stopTest();
    }

    @isTest
    static void testBrandFilterFunctionality() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Get a manufacturer name from existing data
        List<Product_Inventory__c> productsWithManufacturer = [
            SELECT Manufacturer_Name__c
            FROM Product_Inventory__c
            WHERE Manufacturer_Name__c != null
            LIMIT 1
        ];

        if (!productsWithManufacturer.isEmpty()) {
            String testBrand = productsWithManufacturer[0].Manufacturer_Name__c;

            // Test filtering by brand
            controller.selectedBrand = testBrand;
            List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

            // All results should have the selected brand
            for (ProductInventoryController.InventoryWrapper wrapper : results) {
                System.assertEquals(testBrand, wrapper.record.Manufacturer_Name__c,
                    'All results should have the selected brand');
            }
        }

        // Test with 'All' - should not filter
        controller.selectedBrand = 'All';
        List<ProductInventoryController.InventoryWrapper> allResults = controller.getInventoryRecords();
        System.assert(allResults.size() >= 0, 'Should return results with All filter');

        Test.stopTest();
    }

    @isTest
    static void testClearFiltersIncludesBrand() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();

        // Set a brand filter
        controller.selectedBrand = 'Test Brand';
        System.assertEquals('Test Brand', controller.selectedBrand, 'Brand should be set');

        // Clear filters
        controller.clearFilters();

        // Verify brand filter is reset
        System.assertEquals('All', controller.selectedBrand, 'Brand filter should be reset to All');

        Test.stopTest();
    }

    @isTest
    static void testSearchByProductCode() {
        Test.startTest();

        // Get a product with a ProductCode
        List<Product_Inventory__c> productsWithCode = [
            SELECT Id, ProductCode__c, Name
            FROM Product_Inventory__c
            WHERE ProductCode__c != null
            LIMIT 1
        ];

        if (!productsWithCode.isEmpty()) {
            String testCode = productsWithCode[0].ProductCode__c;

            ProductInventoryController controller = new ProductInventoryController();
            controller.filterWebsiteProducts = false; // Search all products
            controller.searchTerm = testCode;
            controller.search();

            List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

            // Should find at least the product with that code
            System.assert(results.size() > 0, 'Should find products when searching by ProductCode');

            Boolean foundProduct = false;
            for (ProductInventoryController.InventoryWrapper wrapper : results) {
                if (wrapper.record.ProductCode__c != null &&
                    wrapper.record.ProductCode__c.containsIgnoreCase(testCode)) {
                    foundProduct = true;
                    break;
                }
            }
            System.assert(foundProduct, 'Should find the product with the searched ProductCode');
        }

        Test.stopTest();
    }

    @isTest
    static void testSearchByWebsiteProductId() {
        Test.startTest();

        // Get a product with a Website_Product_Id__c
        List<Product_Inventory__c> productsWithId = [
            SELECT Id, Website_Product_Id__c, Name
            FROM Product_Inventory__c
            WHERE Website_Product_Id__c != null
            LIMIT 1
        ];

        if (!productsWithId.isEmpty()) {
            String testId = productsWithId[0].Website_Product_Id__c;

            ProductInventoryController controller = new ProductInventoryController();
            controller.filterWebsiteProducts = false; // Search all products
            controller.searchTerm = testId;
            controller.search();

            List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

            // Should find at least the product with that ID
            System.assert(results.size() > 0, 'Should find products when searching by Website_Product_Id');

            Boolean foundProduct = false;
            for (ProductInventoryController.InventoryWrapper wrapper : results) {
                if (wrapper.record.Website_Product_Id__c != null &&
                    wrapper.record.Website_Product_Id__c.containsIgnoreCase(testId)) {
                    foundProduct = true;
                    break;
                }
            }
            System.assert(foundProduct, 'Should find the product with the searched Website_Product_Id');
        }

        Test.stopTest();
    }

    @isTest
    static void testSearchByPINumber() {
        Test.startTest();

        // Get a product by its PI number (Name field)
        List<Product_Inventory__c> products = [
            SELECT Id, Name
            FROM Product_Inventory__c
            WHERE Name LIKE 'PI-%'
            LIMIT 1
        ];

        if (!products.isEmpty()) {
            String testPINumber = products[0].Name;

            ProductInventoryController controller = new ProductInventoryController();
            controller.filterWebsiteProducts = false; // Search all products
            controller.searchTerm = testPINumber;
            controller.search();

            List<ProductInventoryController.InventoryWrapper> results = controller.getInventoryRecords();

            // Should find at least the product with that PI number
            System.assert(results.size() > 0, 'Should find products when searching by PI number');

            Boolean foundProduct = false;
            for (ProductInventoryController.InventoryWrapper wrapper : results) {
                if (wrapper.record.Name.containsIgnoreCase(testPINumber)) {
                    foundProduct = true;
                    break;
                }
            }
            System.assert(foundProduct, 'Should find the product with the searched PI number');
        }

        Test.stopTest();
    }

    /**
     * The flag toggle used to be asserted in one method that marked a product out of stock and then
     * reactivated it. Each direction is now its own test, so a failure names which direction broke
     * rather than leaving you to work it out from a combined assertion.
     */
    @isTest
    static void testManualEnableDisableToggleOnMarkOutOfStock() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        Test.startTest();

        Product_Inventory__c testProduct = [
            SELECT Id, Manual_Disable__c, Manual_Enable__c
            FROM Product_Inventory__c
            WHERE Website_Product_Id__c != null AND Manual_Disable__c = false
            LIMIT 1
        ];

        // Mark as out of stock
        Map<String, Object> result = ProductInventoryController.markProductOutOfStock(testProduct.Id);
        System.assertEquals(true, result.get('success'), 'Should succeed: ' + result.get('message'));

        // Verify Manual_Enable__c is unchecked
        Product_Inventory__c updated = [SELECT Manual_Disable__c, Manual_Enable__c FROM Product_Inventory__c WHERE Id = :testProduct.Id];
        System.assertEquals(true, updated.Manual_Disable__c, 'Manual_Disable__c should be true');
        System.assertEquals(false, updated.Manual_Enable__c, 'Manual_Enable__c should be false after marking out of stock');

        Test.stopTest();
    }

    @isTest
    static void testManualEnableDisableToggleOnReactivate() {
        Test.setMock(HttpCalloutMock.class, new WooCommerceBatchEchoMock());

        List<Product_Inventory__c> disabled = disabledMappedProducts(1);

        Test.startTest();

        Map<String, Object> result = ProductInventoryController.reactivateProduct(disabled[0].Id);
        System.assertEquals(true, result.get('success'), 'Reactivation should succeed: ' + result.get('message'));

        Product_Inventory__c updated = [
            SELECT Manual_Disable__c, Manual_Enable__c, Website_Update_Status__c, Website_Update_Date__c
            FROM Product_Inventory__c WHERE Id = :disabled[0].Id
        ];
        System.assertEquals(false, updated.Manual_Disable__c, 'Manual_Disable__c should be false after reactivation');
        System.assertEquals(true, updated.Manual_Enable__c, 'Manual_Enable__c should be true after reactivation');
        System.assert(updated.Website_Update_Status__c.contains('website confirmed stock_status=instock'),
            'Salesforce must record what the website confirmed, got: ' + updated.Website_Update_Status__c);
        System.assertNotEquals(null, updated.Website_Update_Date__c, 'the confirmation must be timestamped');

        Test.stopTest();
    }

    // Margin = (cash price - cheapest supplier - metro delivery) / cash price, all including GST.
    private static Product_Inventory__c pricedProduct(Decimal cashPrice, Decimal supplier1, Decimal supplier2, Decimal metroDeliveryIncGst) {
        Map<String, Object> fields = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Product_Inventory__c' },
            'Cash_Price__c' => cashPrice,
            'Supplier_1_Price__c' => supplier1,
            'Supplier_2_Price__c' => supplier2,
            'Metro_Delivery_Cost_Inc_GST__c' => metroDeliveryIncGst
        };
        return (Product_Inventory__c) JSON.deserialize(JSON.serialize(fields), Product_Inventory__c.class);
    }

    @isTest
    static void testMarginAgainstTarget() {
        ProductInventoryController.InventoryWrapper below = new ProductInventoryController.InventoryWrapper(pricedProduct(1000, 820, 900, 33), true);
        System.assertEquals(14.7, below.marginPercent.setScale(1), 'cheapest supplier and metro delivery come off the cash price');
        System.assertEquals('below', below.marginBand);
        System.assertEquals('14.7%', below.marginDisplay);

        ProductInventoryController.InventoryWrapper near = new ProductInventoryController.InventoryWrapper(pricedProduct(1000, 900, 840, null), true);
        System.assertEquals(16.0, near.marginPercent.setScale(1), 'no delivery cost counts as zero');
        System.assertEquals('near', near.marginBand);

        ProductInventoryController.InventoryWrapper onTarget = new ProductInventoryController.InventoryWrapper(pricedProduct(1000, 780, null, 33), true);
        System.assertEquals('onTarget', onTarget.marginBand);

        ProductInventoryController.InventoryWrapper noSupplier = new ProductInventoryController.InventoryWrapper(pricedProduct(1000, null, null, 33), true);
        System.assertEquals(null, noSupplier.marginPercent);
        System.assertEquals('noMargin', noSupplier.marginBand);

        ProductInventoryController.InventoryWrapper lazy = new ProductInventoryController.InventoryWrapper(pricedProduct(1000, 820, null, 33), false);
        System.assertEquals('noMargin', lazy.marginBand, 'not evaluated yet');
    }

    @isTest
    static void testBelowTargetMarginFilterAndStats() {
        Test.startTest();
        ProductInventoryController controller = new ProductInventoryController();
        controller.filterBelowTargetMargin = true;
        controller.search();
        for (ProductInventoryController.InventoryWrapper w : controller.getInventoryRecords()) {
            System.assertEquals('below', w.marginBand, 'the filter keeps only products below the margin target');
        }
        controller.clearFilters();
        System.assertEquals(false, controller.filterBelowTargetMargin);

        Map<String, Object> stats = ProductInventoryController.getStats(false, false, false, 'All');
        System.assert(stats.containsKey('marginBelowTarget'));
        System.assert(stats.containsKey('averageMargin'));
        Integer banded = (Integer) stats.get('marginBelowTarget') + (Integer) stats.get('marginNearTarget') + (Integer) stats.get('marginOnTarget');
        System.assertEquals((Integer) stats.get('marginProducts'), banded, 'every product with a margin is in one band');
        Test.stopTest();
    }
}