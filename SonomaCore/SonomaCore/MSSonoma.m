#import "MSConstants+Internal.h"
#import "MSEnvironmentHelper.h"
#import "MSDeviceTracker.h"
#import "SNMDeviceTrackerPrivate.h"
#import "MSFileStorage.h"
#import "MSHttpSender.h"
#import "MSLogManagerDefault.h"
#import "MSLogger.h"
#import "MSSonomaInternal.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>

// Http Headers + Query string.
static NSString *const kSNMHeaderAppSecretKey = @"App-Secret";
static NSString *const kSNMHeaderInstallIDKey = @"Install-ID";
static NSString *const kSNMHeaderContentTypeKey = @"Content-Type";
static NSString *const kSNMContentType = @"application/json";
static NSString *const kSNMAPIVersion = @"1.0.0-preview20160914";
static NSString *const kSNMAPIVersionKey = @"api_version";

// Base URL for HTTP backend API calls.
static NSString *const kSNMDefaultBaseUrl = @"https://in.sonoma.hockeyapp.com";

@implementation MSSonoma

@synthesize installId = _installId;

+ (instancetype)sharedInstance {
  static MSSonoma *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

#pragma mark - public

+ (void)start:(NSString *)appSecret {
  [[self sharedInstance] start:appSecret];
}

+ (void)start:(NSString *)appSecret withFeatures:(NSArray<Class> *)features {
  [[self sharedInstance] start:appSecret withFeatures:features];
}

+ (void)startFeature:(Class)feature {
  [[self sharedInstance] startFeature:feature];
}

+ (BOOL)isInitialized {
  return [[self sharedInstance] sdkStarted];
}

+ (void)setServerUrl:(NSString *)serverUrl {
  [[self sharedInstance] setServerUrl:serverUrl];
}

+ (void)setEnabled:(BOOL)isEnabled {
  @synchronized([self sharedInstance]) {
    if ([[self sharedInstance] canBeUsed]) {
      [[self sharedInstance] setEnabled:isEnabled];
    }
  }
}

+ (BOOL)isEnabled {
  @synchronized([self sharedInstance]) {
    if ([[self sharedInstance] canBeUsed]) {
      return [[self sharedInstance] isEnabled];
    }
  }
  return NO;
}

+ (NSUUID *)installId {
  return [[self sharedInstance] installId];
}

+ (MSLogLevel)logLevel {
  return MSLogger.currentLogLevel;
}

+ (void)setLogLevel:(MSLogLevel)logLevel {
  MSLogger.currentLogLevel = logLevel;
}

+ (void)setLogHandler:(MSLogHandler)logHandler {
  [MSLogger setLogHandler:logHandler];
}

+ (void)setWrapperSdk:(MSWrapperSdk *)wrapperSdk {
  [MSDeviceTracker setWrapperSdk:wrapperSdk];
}

/**
 * Check if the debugger is attached
 *
 * Taken from
 * https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO`
 * otherwise
 */
+ (BOOL)isDebuggerAttached {
  static BOOL debuggerIsAttached = NO;

  static dispatch_once_t debuggerPredicate;
  dispatch_once(&debuggerPredicate, ^{
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];

    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();

    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
      NSLog(@"[SNMCrashes] ERROR: Checking for a running debugger via sysctl() "
            @"failed.");
      debuggerIsAttached = false;
    }

    if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
      debuggerIsAttached = true;
  });

  return debuggerIsAttached;
}

+ (NSString *)getLoggerTag {
  return @"SonomaCore";
}

#pragma mark - private

- (instancetype)init {
  if (self = [super init]) {
    _features = [NSMutableArray new];
    _serverUrl = kSNMDefaultBaseUrl;
    _enabledStateUpdating = NO;
  }
  return self;
}

- (BOOL)start:(NSString *)appSecret {
  if (self.sdkStarted) {
    MSLogWarning([MSSonoma getLoggerTag], @"SDK has already been started. You can call `start` only once.");
    return NO;
  }

  // Validate and set the app secret.
  if ([appSecret length] == 0 || ![[NSUUID alloc] initWithUUIDString:appSecret]) {
    MSLogError([MSSonoma getLoggerTag], @"AppSecret is invalid");
    return NO;
  }
  self.appSecret = appSecret;

  // Set backend API version.
  self.apiVersion = kSNMAPIVersion;

  // Init the main pipeline.
  [self initializePipeline];

  // Enable pipeline as needed.
  if (self.isEnabled) {
    [self applyPipelineEnabledState:self.isEnabled];
  }

  _sdkStarted = YES;

  // If the loglevel hasn't been customized before and we are not running in an app store environment, we set the
  // default loglevel to MSLogLevelWarning.
  if ((![MSLogger isUserDefinedLogLevel]) && ([MSEnvironmentHelper currentAppEnvironment] == SNMEnvironmentOther)) {
    [MSSonoma setLogLevel:MSLogLevelWarning];
  }
  return YES;
}

- (void)start:(NSString *)appSecret withFeatures:(NSArray<Class> *)features {
  BOOL initialized = [self start:appSecret];
  if (initialized) {
    for (Class feature in features) {
      [self startFeature:feature];
    }
  }
}

- (void)startFeature:(Class)clazz {
  id<MSFeatureInternal> feature = [clazz sharedInstance];

  // Set sonomaDelegate.
  [self.features addObject:feature];

  // Start feature with log manager.
  [feature startWithLogManager:self.logManager];
}

- (void)setServerUrl:(NSString *)serverUrl {
  @synchronized(self) {
    _serverUrl = serverUrl;
  }
}

- (void)setEnabled:(BOOL)isEnabled {
  if ([self isEnabled] != isEnabled) {
    self.enabledStateUpdating = YES;

    // Enable/disable pipeline.
    [self applyPipelineEnabledState:isEnabled];

    // Propagate enable/disable on all features.
    for (id<MSFeatureInternal> feature in self.features) {
      [[feature class] setEnabled:isEnabled];
    }

    // Persist the enabled status.
    [kSNMUserDefaults setObject:[NSNumber numberWithBool:isEnabled] forKey:kSNMCoreIsEnabledKey];
    self.enabledStateUpdating = NO;
  }
}

- (BOOL)isEnabled {

  /**
   * Get isEnabled value from persistence.
   * No need to cache the value in a property, user settings already have their cache mechanism.
   */
  NSNumber *isEnabledNumber = [kSNMUserDefaults objectForKey:kSNMCoreIsEnabledKey];

  // Return the persisted value otherwise it's enabled by default.
  return (isEnabledNumber) ? [isEnabledNumber boolValue] : YES;
}

- (void)applyPipelineEnabledState:(BOOL)isEnabled {

  // Remove all notification handlers
  [kSNMNotificationCenter removeObserver:self];

  // Hookup to application life-cycle events
  if (isEnabled) {
    [kSNMNotificationCenter addObserver:self
                               selector:@selector(applicationDidEnterBackground)
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];
    [kSNMNotificationCenter addObserver:self
                               selector:@selector(applicationWillEnterForeground)
                                   name:UIApplicationWillEnterForegroundNotification
                                 object:nil];
  }

  // Propagate to log manager.
  [self.logManager setEnabled:isEnabled andDeleteDataOnDisabled:YES];
}

- (void)initializePipeline {

  // Construct http headers.
  NSDictionary *headers = @{
    kSNMHeaderContentTypeKey : kSNMContentType,
    kSNMHeaderAppSecretKey : _appSecret,
    kSNMHeaderInstallIDKey : [self.installId UUIDString]
  };

  // Construct the query parameters.
  NSDictionary *queryStrings = @{kSNMAPIVersionKey : kSNMAPIVersion};

  MSHttpSender *sender = [[MSHttpSender alloc] initWithBaseUrl:self.serverUrl
                                                         headers:headers
                                                    queryStrings:queryStrings
                                                    reachability:[MS_Reachability reachabilityForInternetConnection]];

  // Construct storage.
  MSFileStorage *storage = [[MSFileStorage alloc] init];

  // Construct log manager.
  _logManager = [[MSLogManagerDefault alloc] initWithSender:sender storage:storage];
}

- (NSString *)appSecret {
  return _appSecret;
}

- (NSString *)apiVersion {
  return _apiVersion;
}

- (NSUUID *)installId {
  @synchronized(self) {
    if (!_installId) {

      // Check if install Id has already been persisted.
      NSString *savedInstallId = [kSNMUserDefaults objectForKey:kSNMInstallIdKey];
      if (savedInstallId) {
        _installId = kSNMUUIDFromString(savedInstallId);
      }

      // Create a new random install Id if persistency failed.
      if (!_installId) {
        _installId = [NSUUID UUID];

        // Persist the install Id string.
        [kSNMUserDefaults setObject:[_installId UUIDString] forKey:kSNMInstallIdKey];
      }
    }
    return _installId;
  }
}

- (BOOL)canBeUsed {
  BOOL canBeUsed = self.sdkStarted;
  if (!canBeUsed) {
    MSLogError([MSSonoma getLoggerTag],
                @"Mobile Center SDK hasn't been initialized. You need to call [MSMobileCenter "
                @"start:YOUR_APP_SECRET withFeatures:LIST_OF_FEATURES] first.");
  }
  return canBeUsed;
}

#pragma mark - Application life cycle

/**
 *  The application will go to the foreground.
 */
- (void)applicationWillEnterForeground {
  [self.logManager setEnabled:YES andDeleteDataOnDisabled:NO];
}

/**
 *  The application will go to the background.
 */
- (void)applicationDidEnterBackground {
  [self.logManager setEnabled:NO andDeleteDataOnDisabled:NO];
}

@end
