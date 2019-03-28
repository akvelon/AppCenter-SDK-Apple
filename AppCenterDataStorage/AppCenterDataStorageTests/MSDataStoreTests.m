// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSChannelGroupProtocol.h"
#import "MSCosmosDb.h"
#import "MSCosmosDbIngestion.h"
#import "MSCosmosDbPrivate.h"
#import "MSDataSourceError.h"
#import "MSDataStore.h"
#import "MSDataStoreErrors.h"
#import "MSDataStoreInternal.h"
#import "MSDataStorePrivate.h"
#import "MSDocumentWrapper.h"
#import "MSMockUserDefaults.h"
#import "MSTestFrameworks.h"
#import "MSTokenExchange.h"
#import "MSTokenResult.h"
#import "MSTokensResponse.h"

@interface MSFakeSerializableDocument : NSObject <MSSerializableDocument>
- (instancetype)initFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)serializeToDictionary;
@end

@implementation MSFakeSerializableDocument

- (NSDictionary *)serializeToDictionary {
  return [NSDictionary new];
}

- (instancetype)initFromDictionary:(NSDictionary *)__unused dictionary {
  (self = [super init]);
  return self;
}

@end

@interface MSDataStoreTests : XCTestCase

@property(nonatomic) id settingsMock;
@property(nonatomic) id tokenExchangeMock;
@property(nonatomic) id cosmosDbMock;

@end

@implementation MSDataStoreTests

static NSString *const kMSCosmosDbHttpCodeKey = @"com.Microsoft.AppCenter.HttpCodeKey";
static NSString *const kMSTokenTest = @"token";
static NSString *const kMSPartitionTest = @"partition";
static NSString *const kMSDbAccountTest = @"dbAccount";
static NSString *const kMSDbNameTest = @"dbName";
static NSString *const kMSDbCollectionNameTest = @"dbCollectionName";
static NSString *const kMSStatusTest = @"status";
static NSString *const kMSExpiresOnTest = @"20191212";
static NSString *const kMSDocumentIdTest = @"documentId";

- (void)setUp {
  [super setUp];
  self.settingsMock = [MSMockUserDefaults new];
  self.tokenExchangeMock = OCMClassMock([MSTokenExchange class]);
  self.cosmosDbMock = OCMClassMock([MSCosmosDb class]);
}

- (void)tearDown {
  [super tearDown];
  [self.settingsMock stopMocking];
  [self.tokenExchangeMock stopMocking];
  [self.cosmosDbMock stopMocking];
}

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
  MSCosmosDbIngestion *httpClient = OCMPartialMock([MSCosmosDbIngestion new]);
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  __block BOOL completionHandlerCalled = NO;
  MSCosmosDbCompletionHandler handler = ^(NSData *_Nullable data, NSError *_Nullable error) {
    completionHandlerCalled = YES;
  };
  NSString *expectedURLString = @"https://dbAccount.documents.azure.com/dbs/dbName/colls/dbCollectionName/docs/documentId";
  __block NSData *actualData;
  OCMStub([httpClient sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    MSCosmosDbCompletionHandler completionHandler;
    [invocation retainArguments];
    [invocation getArgument:&actualData atIndex:2];
    [invocation getArgument:&completionHandler atIndex:3];
    completionHandler(actualData, nil);
  });
  NSString *expectedUrl = @"123";
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
                                        completionHandler:handler];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(data, actualData);
  XCTAssertTrue([expectedURLString isEqualToString:httpClient.sendURL.absoluteString]);
}

- (void)testPerformCosmosDbAsyncOperationWithHttpClient {

  // If
  MSCosmosDbIngestion *httpClient = OCMPartialMock([MSCosmosDbIngestion new]);
  MSTokenResult *tokenResult = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  __block BOOL completionHandlerCalled = NO;
  MSCosmosDbCompletionHandler handler = ^(NSData *_Nullable data, NSError *_Nullable error) {
    completionHandlerCalled = YES;
  };
  NSString *expectedURLString = @"https://dbAccount.documents.azure.com/dbs/dbName/colls/dbCollectionName/docs/documentId";
  __block NSData *actualData;
  OCMStub([httpClient sendAsync:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
    MSCosmosDbCompletionHandler completionHandler;
    [invocation retainArguments];
    [invocation getArgument:&actualData atIndex:2];
    [invocation getArgument:&completionHandler atIndex:3];
    completionHandler(actualData, nil);
  });
  NSString *expectedUrl = @"123";
  NSDictionary *dic = @{@"abv" : @1, @"foo" : @"bar"};
  __block NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];

  // When
  [MSCosmosDb performCosmosDbAsyncOperationWithHttpClient:httpClient
                                              tokenResult:tokenResult
                                               documentId:kMSDocumentIdTest
                                               httpMethod:kMSHttpMethodGet
                                                     body:data
                                        completionHandler:handler];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(data, actualData);
  XCTAssertTrue([expectedURLString isEqualToString:httpClient.sendURL.absoluteString]);
}

- (void)testCreateWithPartitionGoldenPath {

  // If
  NSString *expectedDocumentId = @"testDocumentId";
  NSString *expectedPartition = @"testPartition";
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  __block MSDocumentWrapper *actualDocumentWrapper;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  NSData *testCosmosDbResponse = [@"{\"test\": true}" dataUsingEncoding:NSUTF8StringEncoding];
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:OCMOCK_ANY
                                                              documentId:OCMOCK_ANY
                                                              httpMethod:OCMOCK_ANY
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSCosmosDbCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:8];
        cosmosdbOperationCallback(testCosmosDbResponse, nil);
      });

  // When
  [MSDataStore createWithPartition:expectedPartition
                        documentId:expectedDocumentId
                          document:mockSerializableDocument
                 completionHandler:^(MSDocumentWrapper *data) {
                   completionHandlerCalled = YES;
                   actualDocumentWrapper = data;
                 }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertNotNil(actualDocumentWrapper.deserializedValue);
  XCTAssertEqual(actualDocumentWrapper.documentId, expectedDocumentId);
  XCTAssertEqual(actualDocumentWrapper.partition, expectedPartition);
}

- (void)testCreateWithPartitionWhenTokenExchangeFails {

  // If
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = kMSACDocumentUnauthorizedErrorCode;
  NSError *expectedTokenExchangeError = [NSError errorWithDomain:kMSACErrorDomain
                                                            code:0
                                                        userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(nil, expectedTokenExchangeError);
      });

  // When
  [MSDataStore createWithPartition:@"testPartition"
                        documentId:@"testDocumentId"
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
  NSInteger expectedResponseCode = kMSACDocumentInternalServerErrorErrorCode;
  NSError *expectedCosmosDbError = [NSError errorWithDomain:kMSACErrorDomain
                                                       code:0
                                                   userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:OCMOCK_ANY
                                                              documentId:OCMOCK_ANY
                                                              httpMethod:OCMOCK_ANY
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSCosmosDbCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:8];
        cosmosdbOperationCallback(nil, expectedCosmosDbError);
      });

  // When
  [MSDataStore createWithPartition:@"testPartition"
                        documentId:@"testDocumentId"
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
  NSString *partition = @"partition";
  NSString *documentId = @"documentId";
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSErrorDomain expectedErrorDomain = NSCocoaErrorDomain;
  NSInteger expectedErrorCode = 3840;
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  NSData *brokenCosmosDbResponse = [@"<h1>502 Bad Gateway</h1><p>nginx</p>" dataUsingEncoding:NSUTF8StringEncoding];
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:OCMOCK_ANY
                                                              documentId:OCMOCK_ANY
                                                              httpMethod:OCMOCK_ANY
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSCosmosDbCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:8];
        cosmosdbOperationCallback(brokenCosmosDbResponse, nil);
      });

  // When
  [MSDataStore createWithPartition:partition
                        documentId:documentId
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
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = kMSACDocumentSucceededErrorCode;
  __block NSInteger actualResponseCode;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:OCMOCK_ANY
                                                              documentId:OCMOCK_ANY
                                                              httpMethod:OCMOCK_ANY
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSCosmosDbCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:8];
        cosmosdbOperationCallback(nil, nil);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:@"testPartition"
                                documentId:@"testDocumentId"
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
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = kMSACDocumentUnauthorizedErrorCode;
  NSError *expectedTokenExchangeError = [NSError errorWithDomain:kMSACErrorDomain
                                                            code:0
                                                        userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(nil, expectedTokenExchangeError);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:@"testPartition"
                                documentId:@"testDocumentId"
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
  id<MSSerializableDocument> mockSerializableDocument = [MSFakeSerializableDocument new];
  __block BOOL completionHandlerCalled = NO;
  NSInteger expectedResponseCode = kMSACDocumentInternalServerErrorErrorCode;
  NSError *expectedCosmosDbError = [NSError errorWithDomain:kMSACErrorDomain
                                                       code:0
                                                   userInfo:@{kMSCosmosDbHttpCodeKey : @(expectedResponseCode)}];
  __block MSDataSourceError *actualError;

  // Mock tokens fetching.
  MSTokenResult *testToken = [[MSTokenResult alloc] initWithDictionary:[self prepareMutableDictionary]];
  MSTokensResponse *testTokensResponse = [[MSTokensResponse alloc] initWithTokens:@[ testToken ]];
  OCMStub([self.tokenExchangeMock performDbTokenAsyncOperationWithHttpClient:OCMOCK_ANY partition:OCMOCK_ANY completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSGetTokenAsyncCompletionHandler getTokenCallback;
        [invocation getArgument:&getTokenCallback atIndex:4];
        getTokenCallback(testTokensResponse, nil);
      });

  // Mock CosmosDB requests.
  OCMStub([self.cosmosDbMock performCosmosDbAsyncOperationWithHttpClient:OCMOCK_ANY
                                                             tokenResult:OCMOCK_ANY
                                                              documentId:OCMOCK_ANY
                                                              httpMethod:OCMOCK_ANY
                                                                    body:OCMOCK_ANY
                                                       additionalHeaders:OCMOCK_ANY
                                                       completionHandler:OCMOCK_ANY])
      .andDo(^(NSInvocation *invocation) {
        MSCosmosDbCompletionHandler cosmosdbOperationCallback;
        [invocation getArgument:&cosmosdbOperationCallback atIndex:8];
        cosmosdbOperationCallback(nil, expectedCosmosDbError);
      });

  // When
  [MSDataStore deleteDocumentWithPartition:@"testPartition"
                                documentId:@"testDocumentId"
                         completionHandler:^(MSDataSourceError *error) {
                           completionHandlerCalled = YES;
                           actualError = error;
                         }];

  // Then
  XCTAssertTrue(completionHandlerCalled);
  XCTAssertEqualObjects(actualError.error, expectedCosmosDbError);
  XCTAssertEqual(actualError.errorCode, expectedResponseCode);
}

@end
