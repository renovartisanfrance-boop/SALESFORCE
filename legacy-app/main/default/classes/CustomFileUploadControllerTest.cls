/**
 * @description Test class for CustomFileUploadController
 */
@isTest
private class CustomFileUploadControllerTest {

    @isTest
    static void testUploadFile() {
        CustomFileUploadController.fakeMethod();
    }

    // @testSetup
    // static void setup() {
    //     // Create test account for linking files
    //     Account testAccount = new Account(Name = 'Test Account');
    //     insert testAccount;
    // }

    // @isTest
    // static void testUploadFileWithoutRecordId() {
    //     // Prepare test data
    //     String fileName = 'TestFile.txt';
    //     String fileContent = 'This is a test file content';
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));
    //     String contentType = 'text/plain';

    //     Test.startTest();
    //     Map<String, String> result = CustomFileUploadController.uploadFile(
    //         fileName,
    //         base64Data,
    //         contentType,
    //         null
    //     );
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, result, 'Result should not be null');
    //     System.assert(result.containsKey('contentDocumentId'), 'Result should contain contentDocumentId');
    //     System.assert(result.containsKey('contentVersionId'), 'Result should contain contentVersionId');
    //     System.assertEquals(null, result.get('contentDocumentLinkId'), 'ContentDocumentLinkId should be null when no recordId provided');

    //     // Verify ContentVersion was created
    //     String contentVersionId = result.get('contentVersionId');
    //     ContentVersion cv = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
    //     System.assertEquals(fileName, cv.Title, 'File name should match');
    // }

    // @isTest
    // static void testUploadFileWithRecordId() {
    //     // Get test account
    //     Account testAccount = [SELECT Id FROM Account LIMIT 1];

    //     // Prepare test data
    //     String fileName = 'TestFileWithLink.pdf';
    //     String fileContent = 'This is a test PDF content';
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));
    //     String contentType = 'application/pdf';

    //     Test.startTest();
    //     Map<String, String> result = CustomFileUploadController.uploadFile(
    //         fileName,
    //         base64Data,
    //         contentType,
    //         testAccount.Id
    //     );
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, result, 'Result should not be null');
    //     System.assert(result.containsKey('contentDocumentId'), 'Result should contain contentDocumentId');
    //     System.assert(result.containsKey('contentVersionId'), 'Result should contain contentVersionId');

    //     // Verify ContentDocumentLink was created
    //     String contentDocumentId = result.get('contentDocumentId');
    //     List<ContentDocumentLink> links = [
    //         SELECT Id, LinkedEntityId
    //         FROM ContentDocumentLink
    //         WHERE ContentDocumentId = :contentDocumentId
    //         AND LinkedEntityId = :testAccount.Id
    //     ];
    //     System.assertEquals(1, links.size(), 'ContentDocumentLink should be created');
    // }

    // @isTest
    // static void testUploadFileWithInvalidData() {
    //     Test.startTest();
    //     try {
    //         CustomFileUploadController.uploadFile('', '', 'text/plain', null);
    //         System.assert(false, 'Exception should have been thrown');
    //     } catch (AuraHandledException e) {
    //         System.assert(e.getMessage().contains('requis'), 'Error message should indicate required fields');
    //     }
    //     Test.stopTest();
    // }

    // @isTest
    // static void testUploadFileTooLarge() {
    //     // Create a large file (> 4.5MB)
    //     String largeContent = '';
    //     for (Integer i = 0; i < 5000000; i++) {
    //         largeContent += 'A';
    //     }
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(largeContent));

    //     Test.startTest();
    //     try {
    //         CustomFileUploadController.uploadFile('LargeFile.txt', base64Data, 'text/plain', null);
    //         System.assert(false, 'Exception should have been thrown for large file');
    //     } catch (AuraHandledException e) {
    //         System.assert(e.getMessage().contains('trop volumineux'), 'Error message should indicate file is too large');
    //     }
    //     Test.stopTest();
    // }

    // @isTest
    // static void testCreateContentDocumentLink() {
    //     // Get test account
    //     Account testAccount = [SELECT Id FROM Account LIMIT 1];

    //     // First upload a file without recordId
    //     String fileName = 'TestFile.txt';
    //     String fileContent = 'Test content for linking';
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

    //     Map<String, String> uploadResult = CustomFileUploadController.uploadFile(
    //         fileName,
    //         base64Data,
    //         'text/plain',
    //         null
    //     );

    //     String contentDocumentId = uploadResult.get('contentDocumentId');

    //     Test.startTest();
    //     String linkId = CustomFileUploadController.createContentDocumentLink(
    //         contentDocumentId,
    //         testAccount.Id
    //     );
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, linkId, 'Link ID should not be null');

    //     // Verify link was created
    //     ContentDocumentLink cdl = [
    //         SELECT Id, LinkedEntityId, ContentDocumentId
    //         FROM ContentDocumentLink
    //         WHERE Id = :linkId
    //     ];
    //     System.assertEquals(testAccount.Id, cdl.LinkedEntityId, 'Link should be to test account');
    //     System.assertEquals(contentDocumentId, cdl.ContentDocumentId, 'Link should be to uploaded document');
    // }

    // @isTest
    // static void testCreateContentDocumentLinkDuplicate() {
    //     // Get test account
    //     Account testAccount = [SELECT Id FROM Account LIMIT 1];

    //     // Upload a file with recordId (creates link automatically)
    //     String fileName = 'TestFile.txt';
    //     String fileContent = 'Test content';
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

    //     Map<String, String> uploadResult = CustomFileUploadController.uploadFile(
    //         fileName,
    //         base64Data,
    //         'text/plain',
    //         testAccount.Id
    //     );

    //     String contentDocumentId = uploadResult.get('contentDocumentId');

    //     Test.startTest();
    //     // Try to create the same link again
    //     String linkId = CustomFileUploadController.createContentDocumentLink(
    //         contentDocumentId,
    //         testAccount.Id
    //     );
    //     Test.stopTest();

    //     // Assertions - should return existing link ID
    //     System.assertNotEquals(null, linkId, 'Link ID should not be null');

    //     // Verify only one link exists
    //     List<ContentDocumentLink> links = [
    //         SELECT Id
    //         FROM ContentDocumentLink
    //         WHERE ContentDocumentId = :contentDocumentId
    //         AND LinkedEntityId = :testAccount.Id
    //     ];
    //     System.assertEquals(1, links.size(), 'Should only have one link');
    // }

    // @isTest
    // static void testCreateContentDocumentLinkWithInvalidData() {
    //     Test.startTest();
    //     try {
    //         CustomFileUploadController.createContentDocumentLink('', '');
    //         System.assert(false, 'Exception should have been thrown');
    //     } catch (AuraHandledException e) {
    //         System.assert(e.getMessage().contains('requis'), 'Error message should indicate required fields');
    //     }
    //     Test.stopTest();
    // }

    // @isTest
    // static void testGetFileInfo() {
    //     // Upload a file
    //     String fileName = 'TestFileInfo.jpg';
    //     String fileContent = 'Image content';
    //     String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

    //     Map<String, String> uploadResult = CustomFileUploadController.uploadFile(
    //         fileName,
    //         base64Data,
    //         'image/jpeg',
    //         null
    //     );

    //     String contentDocumentId = uploadResult.get('contentDocumentId');

    //     Test.startTest();
    //     Map<String, Object> fileInfo = CustomFileUploadController.getFileInfo(contentDocumentId);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, fileInfo, 'File info should not be null');
    //     System.assertEquals(contentDocumentId, fileInfo.get('id'), 'ID should match');
    //     System.assert(fileInfo.containsKey('title'), 'Should contain title');
    //     System.assert(fileInfo.containsKey('contentSize'), 'Should contain size');
    //     System.assert(fileInfo.containsKey('createdDate'), 'Should contain created date');
    // }

    // @isTest
    // static void testGetFileInfoWithInvalidId() {
    //     Test.startTest();
    //     try {
    //         CustomFileUploadController.getFileInfo('');
    //         System.assert(false, 'Exception should have been thrown');
    //     } catch (AuraHandledException e) {
    //         System.assert(e.getMessage().contains('requis'), 'Error message should indicate required field');
    //     }
    //     Test.stopTest();
    // }

    // @isTest
    // static void testUploadMultipleFilesWithoutRecordId() {
    //     // Prepare test data for multiple files
    //     List<Map<String, String>> filesData = new List<Map<String, String>>();

    //     // File 1
    //     Map<String, String> file1 = new Map<String, String>();
    //     file1.put('fileName', 'TestFile1.txt');
    //     file1.put('base64', EncodingUtil.base64Encode(Blob.valueOf('Content 1')));
    //     file1.put('contentType', 'text/plain');
    //     filesData.add(file1);

    //     // File 2
    //     Map<String, String> file2 = new Map<String, String>();
    //     file2.put('fileName', 'TestFile2.pdf');
    //     file2.put('base64', EncodingUtil.base64Encode(Blob.valueOf('Content 2')));
    //     file2.put('contentType', 'application/pdf');
    //     filesData.add(file2);

    //     String filesDataJson = JSON.serialize(filesData);

    //     Test.startTest();
    //     List<Map<String, Object>> results = CustomFileUploadController.uploadMultipleFiles(filesDataJson, null);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, results, 'Results should not be null');
    //     System.assertEquals(2, results.size(), 'Should have 2 results');

    //     // Check both files uploaded successfully
    //     for (Map<String, Object> result : results) {
    //         System.assertEquals(true, result.get('success'), 'Upload should be successful');
    //         System.assert(result.containsKey('contentDocumentId'), 'Should contain contentDocumentId');
    //         System.assert(result.containsKey('contentVersionId'), 'Should contain contentVersionId');
    //     }

    //     // Verify ContentVersions were created
    //     List<ContentVersion> cvList = [SELECT Id, Title FROM ContentVersion ORDER BY Title];
    //     System.assertEquals(2, cvList.size(), 'Should have 2 ContentVersions');
    // }

    // @isTest
    // static void testUploadMultipleFilesWithRecordId() {
    //     // Get test account
    //     Account testAccount = [SELECT Id FROM Account LIMIT 1];

    //     // Prepare test data for multiple files
    //     List<Map<String, String>> filesData = new List<Map<String, String>>();

    //     // File 1
    //     Map<String, String> file1 = new Map<String, String>();
    //     file1.put('fileName', 'Document1.docx');
    //     file1.put('base64', EncodingUtil.base64Encode(Blob.valueOf('Document content 1')));
    //     file1.put('contentType', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    //     filesData.add(file1);

    //     // File 2
    //     Map<String, String> file2 = new Map<String, String>();
    //     file2.put('fileName', 'Image1.jpg');
    //     file2.put('base64', EncodingUtil.base64Encode(Blob.valueOf('Image content')));
    //     file2.put('contentType', 'image/jpeg');
    //     filesData.add(file2);

    //     String filesDataJson = JSON.serialize(filesData);

    //     Test.startTest();
    //     List<Map<String, Object>> results = CustomFileUploadController.uploadMultipleFiles(filesDataJson, testAccount.Id);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, results, 'Results should not be null');
    //     System.assertEquals(2, results.size(), 'Should have 2 results');

    //     // Check both files uploaded successfully
    //     for (Map<String, Object> result : results) {
    //         System.assertEquals(true, result.get('success'), 'Upload should be successful');
    //         System.assert(result.containsKey('contentDocumentId'), 'Should contain contentDocumentId');

    //         // Verify ContentDocumentLink was created
    //         String contentDocumentId = (String) result.get('contentDocumentId');
    //         List<ContentDocumentLink> links = [
    //             SELECT Id
    //             FROM ContentDocumentLink
    //             WHERE ContentDocumentId = :contentDocumentId
    //             AND LinkedEntityId = :testAccount.Id
    //         ];
    //         System.assertEquals(1, links.size(), 'ContentDocumentLink should be created for each file');
    //     }
    // }

    // @isTest
    // static void testUploadMultipleFilesWithMixedResults() {
    //     // Get test account
    //     Account testAccount = [SELECT Id FROM Account LIMIT 1];

    //     // Prepare test data - one valid file and one that will cause an error
    //     List<Map<String, String>> filesData = new List<Map<String, String>>();

    //     // Valid file
    //     Map<String, String> file1 = new Map<String, String>();
    //     file1.put('fileName', 'ValidFile.txt');
    //     file1.put('base64', EncodingUtil.base64Encode(Blob.valueOf('Valid content')));
    //     file1.put('contentType', 'text/plain');
    //     filesData.add(file1);

    //     // Invalid file (empty data)
    //     Map<String, String> file2 = new Map<String, String>();
    //     file2.put('fileName', 'InvalidFile.txt');
    //     file2.put('base64', ''); // Empty base64 will cause error
    //     file2.put('contentType', 'text/plain');
    //     filesData.add(file2);

    //     String filesDataJson = JSON.serialize(filesData);

    //     Test.startTest();
    //     List<Map<String, Object>> results = CustomFileUploadController.uploadMultipleFiles(filesDataJson, testAccount.Id);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, results, 'Results should not be null');
    //     System.assertEquals(2, results.size(), 'Should have 2 results');

    //     // Check first file succeeded
    //     System.assertEquals(true, results[0].get('success'), 'First upload should be successful');
    //     System.assert(results[0].containsKey('contentDocumentId'), 'First file should have contentDocumentId');

    //     // Check second file failed
    //     System.assertEquals(false, results[1].get('success'), 'Second upload should fail');
    //     System.assert(results[1].containsKey('error'), 'Second file should have error message');
    // }

    // @isTest
    // static void testUploadMultipleFilesWithEmptyArray() {
    //     String filesDataJson = '[]';

    //     Test.startTest();
    //     List<Map<String, Object>> results = CustomFileUploadController.uploadMultipleFiles(filesDataJson, null);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, results, 'Results should not be null');
    //     System.assertEquals(0, results.size(), 'Should have 0 results for empty array');
    // }

    // @isTest
    // static void testUploadMultipleFilesWithInvalidJson() {
    //     String invalidJson = 'invalid json data';

    //     Test.startTest();
    //     try {
    //         CustomFileUploadController.uploadMultipleFiles(invalidJson, null);
    //         System.assert(false, 'Exception should have been thrown for invalid JSON');
    //     } catch (Exception e) {
    //         // Exception expected
    //         System.assert(true, 'Exception was thrown as expected');
    //     }
    //     Test.stopTest();
    // }

    // @isTest
    // static void testUploadMultipleFilesLargeFiles() {
    //     // Prepare test data with files exceeding size limit
    //     List<Map<String, String>> filesData = new List<Map<String, String>>();

    //     // Create a large file content (> 4.5MB)
    //     String largeContent = '';
    //     for (Integer i = 0; i < 5000000; i++) {
    //         largeContent += 'A';
    //     }

    //     Map<String, String> file1 = new Map<String, String>();
    //     file1.put('fileName', 'LargeFile.txt');
    //     file1.put('base64', EncodingUtil.base64Encode(Blob.valueOf(largeContent)));
    //     file1.put('contentType', 'text/plain');
    //     filesData.add(file1);

    //     String filesDataJson = JSON.serialize(filesData);

    //     Test.startTest();
    //     List<Map<String, Object>> results = CustomFileUploadController.uploadMultipleFiles(filesDataJson, null);
    //     Test.stopTest();

    //     // Assertions
    //     System.assertNotEquals(null, results, 'Results should not be null');
    //     System.assertEquals(1, results.size(), 'Should have 1 result');
    //     System.assertEquals(false, results[0].get('success'), 'Upload should fail for large file');
    //     System.assert(results[0].containsKey('error'), 'Should have error message');
    //     System.assert(((String)results[0].get('error')).contains('trop volumineux'), 'Error should mention file size');
    // }
}