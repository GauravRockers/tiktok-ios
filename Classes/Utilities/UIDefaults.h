//
//  UIDefaults.h
//  TikTok
//
//  Created by Moiz Merchant on 12/20/11.
//  Copyright 2011 TikTok. All rights reserved.
//

//-----------------------------------------------------------------------------
// includes
//-----------------------------------------------------------------------------

#import <Foundation/Foundation.h>

//-----------------------------------------------------------------------------
// interface definition
//-----------------------------------------------------------------------------

@interface UIDefaults : NSObject
{
}

//-----------------------------------------------------------------------------

/**
 * Tik's solid color.
 */
+ (UIColor*) getTikColor;

/**
 * Tok's solid color.
 */
+ (UIColor*) getTokColor;

//-----------------------------------------------------------------------------

@end
