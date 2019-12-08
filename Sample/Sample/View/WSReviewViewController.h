//
//  WSReviewViewController.h
//  Sample
//
//  Created by Théophane Rupin on 5/11/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MovieIDResolver;
@protocol ReviewManagerResolver;

typedef id<
    ReviewManagerResolver
> WSReviewViewControllerDependencyResolver;

NS_ASSUME_NONNULL_BEGIN

@interface WSReviewViewController : UIViewController

- (instancetype)initWithDependencies:(WSReviewViewControllerDependencyResolver)dependencies movieID:(NSUInteger)movieID NS_SWIFT_NAME(init(_:movieID:));

@end

NS_ASSUME_NONNULL_END
