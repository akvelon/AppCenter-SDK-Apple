// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSChannelGroupProtocol.h"
#import "MSConstants+Internal.h"
#import "MSChannelUnitProtocol.h"
#import "MSCosmosDb.h"
#import "MSCosmosDbPrivate.h"
#import "MSDataSourceError.h"
#import "MSDataStore.h"
#import "MSDataStoreErrors.h"
#import "MSDataStoreInternal.h"
#import "MSDataStorePrivate.h"
#import "MSDocumentWrapper.h"
#import "MSHttpClient.h"
#import "MSMockUserDefaults.h"
#import "MSHttpTestUtil.h"
#import "MSMockUserDefaults.h"
#import "MSPaginatedDocuments.h"
>>>>>>> feature/storage-list-documents
#import "MSServiceAbstract.h"
#import "MSServiceAbstractProtected.h"
#import "MSTestFrameworks.h"
#import "MSTokenExchange.h"
#import "MSTokenExchangePrivate.h"
#import "MSTokenResult.h"
#import "MSUserIdContextPrivate.h"

static NSString *const kMSTestAppSecret = @"TestAppSecret";
static NSString *const kMSCosmosDbHttpCodeKey = @"com.Microsoft.AppCenter.HttpCodeKey";
static NSString *const kMSTokenTest = @"token";
static NSString *const kMSPartitionTest = @"partition";
static NSString *const kMSDbAccountTest = @"dbAccount";
static NSString *const kMSDbNameTest = @"dbName";
static NSString *const kMSDbCollectionNameTest = @"dbCollectionName";
static NSString *const kMSStatusTest = @"status";
static NSString *const kMSExpiresOnTest = @"20191212";
static NSString *const kMSDocumentIdTest = @"documentId";

@interface MSDataStoreTests : XCTestCase

@end

/*
 * Test document object.
 */

@interface SomeObject : NSObject <MSSerializableDocument>

@property(strong, nonatomic) NSString *property1;
@property(strong, nonatomic) NSNumber *property2;

@end

@implementation SomeObject

@synthesize property1 = _property1;
@synthesize property2 = _property2;

- (instancetype)initFromDictionary:(NSDictionary *)dictionary {
  self.property1 = ((NSDictionary *)dictionary[@"document"])[@"property1"];
  self.property2 = ((NSDictionary *)dictionary[@"document"])[@"property2"];
  return self;
}

- (nonnull NSDictionary *)serializeToDictionary {
  return [NSDictionary new];
}

@end

/*
 * Tests.
 */

@implementation MSDataStoreTests

#pragma mark - Tests

- (nullable NSMutableDictionary *)prepareMutableDictionary {
  NSMutableDictionary *_Nullable tokenResultDictionary = [NSMutableDictionary new];
  tokenResultDictionary[@"partition"] = kMSPartitionTest;
  tokenResultDictionary[@"dbAccount"] = kMSDbAccountTest;
  tokenResultDictionary[@"dbName"] = kMSDbNameTest;
  tokenResultDictionary[@"dbCollectionName"] = kMSDbCollectionNameTest;
  tokenResultDictionary[@"token"] = kMSTokenTest;
  tokenResultDictionary[@"status"] = kMSStatusTest;
  tokenResultDictionary[@"expiresOn"] = kMSExpiresOnTest;
  return tokenResultDictionary;
}

- (void)testApplyEnabledStateWorks {

  // If
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSChannelGroupProtocol))
                        appSecret:kMSTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  self.sut.httpClient = OCMProtocolMock(@protocol(MSHttpClientProtocol));
  __block int enabledCount = 0;
  OCMStub([self.sut.httpClient setEnabled:YES]).andDo(^(__unused NSInvocation *invocation) {
    enabledCount++;
  });
  __block int disabledCount = 0;
  OCMStub([self.sut.httpClient setEnabled:NO]).andDo(^(__unused NSInvocation *invocation) {
    disabledCount++;
  });

  // When
  [self.sut setEnabled:YES];

  // Then
  XCTAssertTrue([self.sut isEnabled]);

  // It's already enabled at start so the enabled logic is not triggered again.
  XCTAssertEqual(enabledCount, 0);

  // When
  [self.sut setEnabled:NO];

  // Then
  XCTAssertFalse([self.sut isEnabled]);
  XCTAssertEqual(disabledCount, 1);

  // When
  [self.sut setEnabled:NO];

  // Then
  XCTAssertFalse([self.sut isEnabled]);

  // It's already disabled, so the disabled logic is not triggered again.
  XCTAssertEqual(disabledCount, 1);

  // When
  [self.sut setEnabled:YES];

  // Then
  XCTAssertTrue([self.sut isEnabled]);
  XCTAssertEqual(enabledCount, 1);
}

- (void)testDefaultHeaderWithPartitionWithDictionaryNotNull {

  // If
  NSMutableDictionary *_Nullable additionalHeaders = [NSMutableDictionary new];
  additionalHeaders[@"Type1"] = @"Value1";
  additionalHeaders[@"Type2"] = @"Value2";
  additionalHeaders[@"Type3"] = @"Value3";

  // When
  NSDictionary *dic = [MSCosmosDb defaultHeaderWithPartition:kMSPartitionTest dbToken:kMSTokenTest additionalHeaders:additionalHeaders];

  // Then
  XCTAssertNotNil(dic);
  XCTAssertTrue(dic[@"Type1"]);
  XCTAssertTrue(dic[@"Type2"]);
  XCTAssertTrue(dic[@"Type3"]);
}

- (void)testDefaultHeaderWithPartitionWithDictionaryNull {

  // When
  NSDictionary *dic = [MSCosmosDb defaultHeaderWithPartition:kMSPartitionTest dbToken:kMSTokenTest additionalHeaders:nil];

  // Then
  XCTAssertNotNil(dic);
  XCTAssertTrue(dic[@"Content-Type"]);
}

- (void)testDocumentUrlWithTokenResultWithStringToken {

  // If
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithString:kMSTokenTest];

  // When
  NSString *result = [MSCosmosDb documentUrlWithTokenResult:tokenResult documentId:kMSDocumentIdTest];

  // Then
  XCTAssertNotNil(result);
}

- (void)testDocumentUrlWithTokenResultWithObjectToken {

  // When
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  NSString *testResult = [MSCosmosDb documentUrlWithTokenResult:tokenResult documentId:@"documentId"];

  // Then
  XCTAssertNotNil(testResult);
  XCTAssertTrue([testResult containsString:kMSDocumentIdTest]);
  XCTAssertTrue([testResult containsString:kMSDbAccountTest]);
  XCTAssertTrue([testResult containsString:kMSDbNameTest]);
  XCTAssertTrue([testResult containsString:kMSDbCollectionNameTest]);
}

- (void)testDocumentUrlWithTokenResultWithDictionaryToken {

  // If
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];

  // When
  NSString *testResult = [MSCosmosDb documentUrlWithTokenResult:tokenResult documentId:kMSDocumentIdTest];

  // Then
  XCTAssertNotNil(testResult);
  XCTAssertTrue([testResult containsString:kMSDocumentIdTest]);
  XCTAssertTrue([testResult containsString:kMSDbAccountTest]);
  XCTAssertTrue([testResult containsString:kMSDbNameTest]);
  XCTAssertTrue([testResult containsString:kMSDbCollectionNameTest]);
}

- (void)testPerformCosmosDbAsyncOperationWithHttpClientWithAdditionalParams {

  // If
  MSHttpClient *httpClient = OCMClassMock([MSHttpClient class]);
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  __block BOOL completionHandlerCalled = NO;
  MSCosmosDbCompletionHandler handler =
      ^(NSData *_Nullable __unused data, NSDictionary *_Nullable __unused headers, NSError *_Nullable __unused error) {
        completionHandlerCalled = YES;
      };
  NSString *expectedURLString = @"https://dbAccount.documents.azure.com/dbs/dbName/colls/dbCollectionName/docs/documentId";
  __block NSURL *actualURL;
  __block NSData *actualData;
  OCMStub([httpClient sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    MSCosmosDbCompletionHandler completionHandler;
    [invocation retainArguments];
    [invocation getArgument:&actualData atIndex:2];
    [invocation getArgument:&completionHandler atIndex:3];
    completionHandler(actualData, nil, (NSError *)nil);
  });
  NSMutableDictionary *additionalHeaders = [NSMutableDictionary new];
  additionalHeaders[@"Foo"] = @"Bar";
  NSDictionary *dic = @{@"abv" : @1, @"foo" : @"bar"};
  __block NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];

  // When
  [MSCosmosDb performCosmosDbAsyncOperationWithHttpClient:httpClient
                                              tokenResult:tokenResult
                                               documentId:kMSDocumentIdTest
                                               httpMethod:kMSHttpMethodGet
                                                     body:data
                                        additionalHeaders:additionalHeaders
                                              offlineMode:NO
                                        completionHandler:handler];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(data, actualData);
  XCTAssertEqualObjects(expectedURLString, [actualURL absoluteString]);
}

- (void)testPerformCosmosDbAsyncOperationWithHttpClient {

  // If
  MSHttpClient *httpClient = OCMClassMock([MSHttpClient class]);
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  __block BOOL completionHandlerCalled = NO;
  MSCosmosDbCompletionHandler handler =
      ^(NSData *_Nullable __unused data, NSDictionary *_Nullable __unused headers, NSError *_Nullable __unused error) {
        completionHandlerCalled = YES;
      };
  NSString *expectedURLString = @"https://dbAccount.documents.azure.com/dbs/dbName/colls/dbCollectionName/docs/documentId";
  __block NSURL *actualURL;
  __block NSData *actualData;
  OCMStub([httpClient sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    MSCosmosDbCompletionHandler completionHandler;
    [invocation retainArguments];
    [invocation getArgument:&actualData atIndex:2];
    [invocation getArgument:&completionHandler atIndex:3];
    completionHandler(actualData, nil, nil);
  });
  NSDictionary *dic = @{@"abv" : @1, @"foo" : @"bar"};
  __block NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];

  // When
  [MSCosmosDb performCosmosDbAsyncOperationWithHttpClient:httpClient
                                              tokenResult:tokenResult
                                               documentId:kMSDocumentIdTest
                                               httpMethod:kMSHttpMethodGet
                                                     body:data
                                        additionalHeaders:nil
                                        completionHandler:handler];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(data, actualData);
  XCTAssertEqualObjects(expectedURLString, [actualURL absoluteString]);
}

- (void)testCreateWithPartitionGoldenPath {

  // If
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  __block MSDocumentWrapper *actualDocumentWrapper;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  NSData *testCosmosDbResponse = [@"{\"test\": true}" dataUsingEncoding:NSUTF8StringEncoding];
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:testToken
                                                              documentId:kMSDocumentIdTest
                                                              httpMethod:kMSHttpMethodPost
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                             offlineMode:NO
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSHttpRequestCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:9];
        cosmosdbOperationCallback(testCosmosDbResponse, nil, nil);
      });

  // When
  [MSDataStore createWithPartition:kMSPartitionTest
                        documentId:kMSDocumentIdTest
                          document:mockSerializableDocument
                 completionHandler:^(MSDocumentWrapper *data) {
                   completionHandlerCalled = YES;
                   actualDocumentWrapper = data;
                 }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertNotNil(actualDocumentWrapper.deserializedValue);
  XCTAssertEqual(actualDocumentWrapper.documentId, kMSDocumentIdTest);
  XCTAssertEqual(actualDocumentWrapper.partition, kMSPartitionTest);
}

- (void)testCreateWithPartitionWhenTokenExchangeFails {

  // If
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = MSACDocumentUnauthorizedErrorCode;
  NSError *expectedTokenExchangeError = [NSError errorWithDomain:kMSACErrorDomain
                                                            code:0
                                                        userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:nil];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, expectedTokenExchangeError);
      });

  // When
  [MSDataStore createWithPartition:kMSPartitionTest
                        documentId:kMSDocumentIdTest
                          document:mockSerializableDocument
                 completionHandler:^(MSDocumentWrapper *data) {
                   completionHandlerCalled = YES;
                   actualError = data.error;
                 }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(actualError.error, expectedTokenExchangeError);
  XCTAssertEqual(actualError.errorCode, expectedResponseCode);
}

- (void)testCreateWithPartitionWhenCreationFails {

  // If
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = MSACDocumentInternalServerErrorErrorCode;
  NSError *expectedCosmosDbError = [NSError errorWithDomain:kMSACErrorDomain
                                                       code:0
                                                   userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:testToken
                                                              documentId:kMSDocumentIdTest
                                                              httpMethod:kMSHttpMethodPost
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                             offlineMode:NO
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSHttpRequestCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:9];
        cosmosdbOperationCallback(nil, nil, expectedCosmosDbError);
      });

  // When
  [MSDataStore createWithPartition:kMSPartitionTest
                        documentId:kMSDocumentIdTest
                          document:mockSerializableDocument
                 completionHandler:^(MSDocumentWrapper *data) {
                   completionHandlerCalled = YES;
                   actualError = data.error;
                 }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(actualError.error, expectedCosmosDbError);
  XCTAssertEqual(actualError.errorCode, expectedResponseCode);
}

- (void)testCreateWithPartitionWhenDeserializationFails {

  // If
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSErrorDomain expectedErrorDomain = NSCocoaErrorDomain;
  NSInteger expectedErrorCode = 3840;
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  NSData *brokenCosmosDbResponse = [@"<h1>502 Bad Gateway</h1><p>nginx</p>" dataUsingEncoding:NSUTF8StringEncoding];
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:testToken
                                                              documentId:kMSDocumentIdTest
                                                              httpMethod:kMSHttpMethodPost
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                             offlineMode:NO
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSHttpRequestCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:9];
        cosmosdbOperationCallback(brokenCosmosDbResponse, nil, nil);
      });

  // When
  [MSDataStore createWithPartition:kMSPartitionTest
                        documentId:kMSDocumentIdTest
                          document:mockSerializableDocument
                 completionHandler:^(MSDocumentWrapper *data) {
                   completionHandlerCalled = YES;
                   actualError = data.error;
                 }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqual(actualError.error.domain, expectedErrorDomain);
  XCTAssertEqual(actualError.error.code, expectedErrorCode);
}

- (void)testDeleteDocumentWithPartitionGoldenPath {

  // If
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = MSACDocumentSucceededErrorCode;
  __block NSInteger actualResponseCode;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:testToken
                                                              documentId:kMSDocumentIdTest
                                                              httpMethod:kMSHttpMethodDelete
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                             offlineMode:NO
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSHttpRequestCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:9];
        cosmosdbOperationCallback(nil, nil, nil);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:kMSPartitionTest
                                documentId:kMSDocumentIdTest
                         completionHandler:^(MSDataSourceError *error) {
                           completionHandlerCalled = YES;
                           actualResponseCode = error.errorCode;
                         }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqual(actualResponseCode, expectedResponseCode);
}

- (void)testDeleteDocumentWithPartitionWhenTokenExchangeFails {

  // If
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = MSACDocumentUnauthorizedErrorCode;
  NSError *expectedTokenExchangeError = [NSError errorWithDomain:kMSACErrorDomain
                                                            code:0
                                                        userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:nil];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, expectedTokenExchangeError);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:kMSPartitionTest
                                documentId:kMSDocumentIdTest
                         completionHandler:^(MSDataSourceError *error) {
                           completionHandlerCalled = YES;
                           actualError = error;
                         }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(actualError.error, expectedTokenExchangeError);
  XCTAssertEqual(actualError.errorCode, expectedResponseCode);
}

- (void)testDeleteDocumentWithPartitionWhenDeletionFails {

  // If
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = MSACDocumentInternalServerErrorErrorCode;
  NSError *expectedCosmosDbError = [NSError errorWithDomain:kMSACErrorDomain
                                                       code:0
                                                   userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:testToken
                                                              documentId:kMSDocumentIdTest
                                                              httpMethod:kMSHttpMethodDelete
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                             offlineMode:NO
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSHttpRequestCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:9];
        cosmosdbOperationCallback(nil, nil, expectedCosmosDbError);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:kMSPartitionTest
                                documentId:kMSDocumentIdTest
                         completionHandler:^(MSDataSourceError *error) {
                           completionHandlerCalled = YES;
                           actualError = error;
                         }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(actualError.error, expectedCosmosDbError);
  XCTAssertEqual(actualError.errorCode, expectedResponseCode);
}

// TODO: add more tests for list operation.
- (void)testListSingleDocument {

  // If
  MSDataStore *sut = [MSDataStore new];
  id httpClient = OCMClassMock([MSCosmosDbIngestion class]);
  OCMStub([httpClient new]).andReturn(httpClient);
  id msTokenEchange = OCMClassMock([MSTokenExchange class]);
  OCMStub([msTokenEchange retrieveCachedToken:[OCMArg any]])
      .andReturn([[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]]);
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"List single document"];
  OCMStub([httpClient sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    [invocation retainArguments];
    MSSendAsyncCompletionHandler completionHandler;
    [invocation getArgument:&completionHandler atIndex:3];
    NSData *payload = [self getJsonFixture:@"oneDocumentPage"];
    completionHandler(@"callId", [MSHttpTestUtil createMockResponseForStatusCode:200 headers:nil], payload, nil);
  });

  // When
  __block MSPaginatedDocuments *testDocuments;
  [sut listWithPartition:@"partition"
            documentType:[SomeObject class]
             readOptions:nil
       continuationToken:nil
       completionHandler:^(MSPaginatedDocuments *_Nonnull documents) {
         testDocuments = documents;
         [expectation fulfill];
       }];

  // Then
  id handler = ^(NSError *_Nullable error) {
    if (error) {
      XCTFail(@"Expectation Failed with error: %@", error);
    } else {
      XCTAssertNotNil(testDocuments);
      XCTAssertFalse([testDocuments hasNextPage]);
      XCTAssertEqual([[testDocuments currentPage] items].count, 1);
      [testDocuments nextPageWithCompletionHandler:^(MSPage *page) {
        XCTAssertNil(page);
      }];
      MSDocumentWrapper<SomeObject *> *documentWrapper = [[testDocuments currentPage] items][0];
      XCTAssertTrue([[documentWrapper documentId] isEqualToString:@"doc1"]);
      XCTAssertNil([documentWrapper error]);
      XCTAssertNotNil([documentWrapper jsonValue]);
      XCTAssertTrue([[documentWrapper eTag] isEqualToString:@"etag value"]);
      XCTAssertTrue([[documentWrapper partition] isEqualToString:@"partition"]);
      XCTAssertNotNil([documentWrapper lastUpdatedDate]);
      SomeObject *deserializedDocument = [documentWrapper deserializedValue];
      XCTAssertNotNil(deserializedDocument);
      XCTAssertTrue([[deserializedDocument property1] isEqualToString:@"property 1 string"]);
      XCTAssertTrue([[deserializedDocument property2] isEqual:@42]);
    }
  };
  [self waitForExpectationsWithTimeout:1 handler:handler];
  [httpClient stopMocking];
}

- (void)testSetOfflineMode {

  // Then
  XCTAssertFalse([MSDataStore isOfflineModeEnabled]);

  // When
  [MSDataStore setOfflineModeEnabled:YES];

  // Then
  XCTAssertTrue([MSDataStore isOfflineModeEnabled]);

  // When
  [MSDataStore setOfflineModeEnabled:NO];

  // Then
  XCTAssertFalse([MSDataStore isOfflineModeEnabled]);
}

- (void)testOfflineModeCallsCompletionHandlerWithError {

  // If
  MSHttpClient *httpClient = OCMClassMock([MSHttpClient class]);
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  __block BOOL completionHandlerCalled = NO;
  NSDictionary *dic = @{@"abv" : @1, @"foo" : @"bar"};
  __block NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Completion handler called."];

  // When
  [MSCosmosDb
      performCosmosDbAsyncOperationWithHttpClient:httpClient
                                      tokenResult:tokenResult
                                       documentId:kMSDocumentIdTest
                                       httpMethod:kMSHttpMethodGet
                                             body:data
                                additionalHeaders:nil
                                      offlineMode:YES
                                completionHandler:^(NSData *_Nullable __unused responseBody, NSHTTPURLResponse *_Nullable __unused response,
                                                    NSError *_Nullable __unused error) {
                                  completionHandlerCalled = YES;
                                  XCTAssertNotNil(error);
                                  XCTAssertEqualObjects(error.domain, kMSDataStorageErrorDomain);
                                  XCTAssertEqual(error.code, NSURLErrorNotConnectedToInternet);
                                  OCMReject([httpClient sendAsync:OCMOCK_ANY
                                                           method:OCMOCK_ANY
                                                          headers:OCMOCK_ANY
                                                             data:OCMOCK_ANY
                                                completionHandler:OCMOCK_ANY]);
                                  [expectation fulfill];
                                }];

  // Then
  [self waitForExpectationsWithTimeout:1
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testSetTokenExchangeUrl {

  // If we change the default token URL.
  NSString *expectedUrl = @"https://another.domain.com";
  [MSDataStore setTokenExchangeUrl:expectedUrl];
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSChannelGroupProtocol))
                        appSecret:kMSTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  __block NSURL *actualUrl;
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:OCMOCK_ANY
                                                                   partition:OCMOCK_ANY
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        [invocation getArgument:&actualUrl atIndex:3];
      });

  // When doing any API call, it will request a token.
  [MSDataStore deleteDocumentWithPartition:kMSPartitionTest
                                documentId:kMSDocumentIdTest
                         completionHandler:^(__unused MSDataSourceError *error){
                         }];

  // Then that call uses the base URL we specified.
  XCTAssertEqualObjects([actualUrl scheme], @"https");
  XCTAssertEqualObjects([actualUrl host], @"another.domain.com");
}

- (void)testOfflineModeBehavior {

  // If
  [self.sut startWithChannelGroup:OCMProtocolMock(@protocol(MSChannelGroupProtocol))
                        appSecret:kMSTestAppSecret
          transmissionTargetToken:nil
                  fromApplication:YES];
  [MSDataStore setOfflineModeEnabled:YES];

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY
                                                            tokenExchangeUrl:OCMOCK_ANY
                                                                   appSecret:kMSTestAppSecret
                                                                   partition:kMSPartitionTest
                                                           completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:6];
        getTokenCallback(testTokensResponse, nil);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:kMSPartitionTest
                                documentId:kMSDocumentIdTest
                         completionHandler:^(__unused MSDataSourceError *error){
                         }];

  // Then
  OCMVerify([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                               tokenResult:OCMOCK_ANY
                                                                documentId:OCMOCK_ANY
                                                                httpMethod:OCMOCK_ANY
                                                                      body:OCMOCK_ANY
                                                         additionalHeaders:OCMOCK_ANY
                                                               offlineMode:YES
                                                         completionHandler:OCMOCK_ANY]);
}

/*
 * Utils.
 */

- (NSData *)getJsonFixture:(NSString *)fixture {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *path = [bundle pathForResource:fixture ofType:@"json"];
  return [NSData dataWithContentsOfFile:path];
}

@end
