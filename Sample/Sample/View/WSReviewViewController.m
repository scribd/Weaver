//
//  WSReviewViewController.m
//  Sample
//
//  Created by Théophane Rupin on 5/11/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

#import "WSReviewViewController.h"
#import "Sample-Swift.h"
@import API;

NS_ASSUME_NONNULL_BEGIN

@interface WSReviewViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) id<WSReviewViewControllerDependencyResolver> dependencies;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray<Review *> *reviews;

@end

@implementation WSReviewViewController

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [UITableView new];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        [_tableView registerClass:[ReviewTableViewCell class] forCellReuseIdentifier:NSStringFromClass([ReviewTableViewCell class])];
        _tableView.rowHeight = UITableViewAutomaticDimension;
        _tableView.estimatedRowHeight = 140;
    }
    return _tableView;
}

- (instancetype)initWithDependencies:(id<WSReviewViewControllerDependencyResolver>)dependencies {
    self = [super init];
    
    if (self) {
        self.dependencies = dependencies;
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Reviews";

    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;

    [self.view addSubview:self.tableView];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[[self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                                              [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
                                              [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
                                              [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
    
    [self.dependencies.reviewManager getReviewsFor:self.dependencies.movieID completion:^(ReviewPage * _Nullable page, ReviewManagerError * _Nullable error) {
        if (error) {
            NSLog(@"%@: Could not retrieve reviews from server: %@", NSStringFromClass([WSReviewViewController class]), error);
            return;
        }
        
        self.reviews = page.results;
        [self.tableView reloadData];
    }];
}

#pragma pragma - UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.reviews.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([ReviewTableViewCell class]) forIndexPath:indexPath];
    
    if ([cell isKindOfClass:[ReviewTableViewCell class]]) {
        ReviewTableViewCell *reviewCell = (ReviewTableViewCell *)cell;
        Review *review = self.reviews[indexPath.row];
        ReviewTableViewCellViewModel *viewModel = [[ReviewTableViewCellViewModel alloc] initWithReview:review];
        [reviewCell bindWithViewModel:viewModel];
    }
    
    return cell;
}

@end

NS_ASSUME_NONNULL_END
