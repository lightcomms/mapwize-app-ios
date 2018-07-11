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
@property (readonly) double lat;
@property (readonly) double lng;
@property (readonly) NSNumber *floor;
@property (readonly) double zoom;
@end
