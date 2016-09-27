/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

/**
 *  Protected declarations for SNMFeatureAbstract.
 */
@interface SNMFeatureAbstract ()

/**
 *  Enable/Disable this feature.
 *
 *  @param isEnabled is this feature enabled or not.
 */
- (void)setEnabled:(BOOL)isEnabled;

/**
 *  Check whether this feature is enabled or not.
 */
- (BOOL)isEnabled;

@end