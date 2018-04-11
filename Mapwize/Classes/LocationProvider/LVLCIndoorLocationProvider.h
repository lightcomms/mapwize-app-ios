//
//  LVLCIndoorLocationProvider.h
//  MapwizeSimpleApp
//
//  Created by Melendez Xavier on 22/02/2018.
//  Copyright © 2018 Etienne Mercier. All rights reserved.
//

#import <IndoorLocation/IndoorLocation.h>

@interface LVLCIndoorLocationProvider : ILIndoorLocationProvider
-(void)defineLocation:(ILIndoorLocation*) location;

@end
