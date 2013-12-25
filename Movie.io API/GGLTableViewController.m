//
//  GGLTableViewController.m
//  Movie.io API
//
//  Created by Yuan-Yi Chang on 2013/12/25.
//  Copyright (c) 2013年 Yuan-Yi Chang. All rights reserved.
//

#import "GGLTableViewController.h"

@interface GGLTableViewController ()

@property (nonatomic, strong) NSMutableArray *items;
@property (nonatomic, strong) NSMutableDictionary *cacheImage;
@property (nonatomic, strong) NSMutableDictionary *checkQuery;

@end

@implementation GGLTableViewController

#pragma mark - property init

- (NSMutableArray *)items
{
    if (!_items) {
        _items = [[NSMutableArray alloc] init];
    }
    return _items;
}

- (NSMutableDictionary *)cacheImage
{
    if (!_cacheImage) {
        _cacheImage = [[NSMutableDictionary alloc] init];
    }
    return _cacheImage;
}

- (NSMutableDictionary *)checkQuery
{
    if (!_checkQuery) {
        _checkQuery = [[NSMutableDictionary alloc] init];
    }
    return _checkQuery;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    if (self.refreshControl) {
        [self.refreshControl addTarget:self action:@selector(queryBegin) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self queryBegin];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    [self.cacheImage removeAllObjects];
}

- (void)queryBegin
{
    NSLog(@"queryBegin");
    
    // Step 1: Reset all
    [self.items removeAllObjects];
    [self.checkQuery removeAllObjects];
    [self.cacheImage removeAllObjects];
    
    // Step 2: Update table view status
    [self.tableView reloadData];
    if (self.refreshControl && !self.refreshControl.isRefreshing) {
        [self.tableView setContentOffset:CGPointMake(0, -self.refreshControl.frame.size.height) animated:YES];
        [self.refreshControl beginRefreshing];
    }
    
    // Step 3: Query ...
    NSString *pattern = @"query data";
    if (!self.checkQuery[pattern]) {
        self.checkQuery[pattern] = @"";
        
        __weak GGLTableViewController * weakSelf = self;
        dispatch_async(dispatch_queue_create("query_data", NULL), ^{
            NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
            @try {
                NSDictionary *response = [NSJSONSerialization
                                          JSONObjectWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://api.movies.io/movies/search?q=hobbit"]]
                                          options:NSJSONReadingMutableContainers
                                          error:nil];
                ret[@"status"] = @"ok";
                ret[@"data"] = response;
            }
            @catch (NSException *exception) {
            }
            @finally {
            }
            [weakSelf queryEnd:ret];
            [weakSelf.checkQuery removeObjectForKey:pattern];
        });
    }
}

- (void)queryEnd:(NSDictionary *)data
{
    //NSLog(@"queryEnd");
    if ([data[@"status"] isEqualToString:@"ok"]) {
        //NSLog(@"%@", data[@"data"][@"movies"]);
        for (NSDictionary *movie in data[@"data"][@"movies"]) {
            if (movie[@"title"] && movie[@"year"] && movie[@"rating"] && [movie valueForKeyPath:@"poster.urls.w92"]) {
                [self.items addObject:movie];
            }
        }
    }

    if (self.refreshControl) {
        [self.refreshControl endRefreshing];
    }
    [self.tableView reloadData];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    NSString *pattern = [NSString stringWithFormat:@"thumb-%d", indexPath.row];
    
    for (UIView *v in [cell.contentView subviews]) {
        switch (v.tag) {
            case 10:    // poster (UIImageView)
            {
                if (self.cacheImage[pattern]) {
                    ((UIImageView *)v).image = self.cacheImage[pattern];//[self.cacheImage[pattern] imageByScalingAndCroppingForSize:CGSizeMake(92, 138)];
                } else if (!self.checkQuery[pattern]) {
                    self.checkQuery[pattern] = @"";
                    // do query
                    __weak GGLTableViewController *weakSelf = self;
                    dispatch_async(dispatch_queue_create("thumb-query", NULL), ^{
                        NSString *url = [weakSelf.items[indexPath.row] valueForKeyPath:@"poster.urls.w92"];
                        UIImage *image;
                        if ([url rangeOfString:@"http"].location == NSNotFound)
                            image = [UIImage imageNamed:@"default.jpg"];
                        else
                            image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:url]]];
                        
                        NSLog(@"dispatch_async: %@, image: %@", [weakSelf.items[indexPath.row] valueForKeyPath:@"poster.urls.w92"], image);
                        if (image) {
                            weakSelf.cacheImage[pattern] = image;
                            [weakSelf.tableView reloadData];
                        }
                    });
                } else {
                    ((UIImageView *)v).image = nil;
                }
            }
                break;
            case 11:    // title (UILabel)
                ((UILabel *)v).text = self.items[indexPath.row][@"title"];
                break;
            case 12:    // year (UILabel)
                ((UILabel *)v).text = [NSString stringWithFormat:@"%@", self.items[indexPath.row][@"year"] ];
                break;
            case 13:    // rating (UILabel)
                ((UILabel *)v).text = [NSString stringWithFormat:@"%@", self.items[indexPath.row][@"rating"] ];
                break;
            case 14:    // loading
                if (self.cacheImage[pattern]) {
                    [((UIActivityIndicatorView *)v) setHidden:YES];
                    [((UIActivityIndicatorView *)v) stopAnimating];
                } else {
                    [((UIActivityIndicatorView *)v) setHidden:NO];
                    [((UIActivityIndicatorView *)v) startAnimating];
                }
                
                break;
        }
    }
    
    
    
    
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
