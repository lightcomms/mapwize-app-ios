//
//  LVLCIndoorLocationProvider.m
//  MapwizeSimpleApp
//
//  Created by Melendez Xavier on 22/02/2018.
//  Copyright © 2018 Etienne Mercier. All rights reserved.
//
#import "LVLCIndoorLocationProvider.h"
#import <CoreLightCom/VLCCallbackDelegate.h>
#import <CoreLightCom/VLCSequencer.hpp>

#define TimeStamp [[NSDate date] timeIntervalSince1970]


@interface LVLCIndoorLocationProvider () <VLCCallbackDelegate>
@property (atomic,strong) dispatch_queue_t backgroundQueue;
@property (atomic,strong) ILIndoorLocation* lastIndoorLocation;
@property (atomic,strong) NSString * vlcID;
@property (atomic) BOOL beaconsFromServerAvailable;
@property (atomic,strong,readwrite) NSDictionary* vlcTable;
@property (atomic,strong) NSTimer * timer;
@property (atomic) BOOL locationLocked;
@end

@implementation LVLCIndoorLocationProvider

-(instancetype)init{
    self =[super init];
    self.lastIndoorLocation=[[ILIndoorLocation alloc]init];
    _beaconsFromServerAvailable = false;
    dispatch_async([self getBackgroundQueue], ^{
        NSError * error =nil;
        NSURL *url = [NSURL URLWithString:@"https://api.mapwize.io/v1/beacons?api_key=49036d2ce04575909ccc816bcec837ca&venueId=5b16841d7892d00013395c5f"];
        NSData *data = [NSData dataWithContentsOfURL:url];
        id beacons = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        // Init tables and loop variable to create the map:
        NSMutableArray * vlcID = [[NSMutableArray alloc] init];
        NSMutableArray * indoorLocations = [[NSMutableArray alloc] init];
        ILIndoorLocation * localLoopIndoorLocation ;
        // loop on keys of the beacons:
        for (id beacon in beacons) {
            if([(NSString *) [beacon objectForKey:@"type"] isEqualToString:@"vlc"]
               && [(NSString *) [[beacon objectForKey:@"properties"] objectForKey:@"lightId" ] hasPrefix:@"0x"]){
                localLoopIndoorLocation = [[ILIndoorLocation alloc]init];
                [localLoopIndoorLocation setAccuracy:0];
                [vlcID addObject:(NSString *) [[beacon objectForKey:@"properties"] objectForKey:@"lightId" ]];
                [localLoopIndoorLocation setLongitude:[[[beacon objectForKey:@"location"] valueForKey:@"lon" ] doubleValue] ] ;
                [localLoopIndoorLocation setLatitude:[[[beacon objectForKey:@"location"] valueForKey:@"lat" ] doubleValue] ] ;
                [localLoopIndoorLocation setFloor: [NSNumber numberWithInteger:[[beacon valueForKey:@"floor"] integerValue]]];
                [indoorLocations addObject:localLoopIndoorLocation  ];
            }
        }
        self.vlcTable = [NSDictionary dictionaryWithObjects:indoorLocations forKeys:vlcID];
        //NSLog(@"List of IDs:%@",self.beacons);
        if (error) _beaconsFromServerAvailable = false;
        else _beaconsFromServerAvailable = true;
    });
    
    
    return self;
}
#pragma mark - Memory/Thread management
-(dispatch_queue_t )getBackgroundQueue{
    if (_backgroundQueue ==nil)
        _backgroundQueue = dispatch_queue_create("io.slms.decoding_queue.vlc", DISPATCH_QUEUE_SERIAL);
    return _backgroundQueue;
}
#pragma mark - start/stop ILLocationProvider implementation
-(void)start{
    [VLCSequencer start:[self getBackgroundQueue] withListener:self];
}

-(void)stop{
    [VLCSequencer stop:[self getBackgroundQueue] withListener:self];
}

-(ILIndoorLocation*) locationFromServer:(NSString*) vlcid{
    if (!self.vlcTable) return nil;
    
    for (id aVLCID in self.vlcTable) {
        if([aVLCID hasPrefix:[vlcid substringToIndex:4]]){
            ILIndoorLocation * location=[self.vlcTable valueForKey:aVLCID];
            NSLog(@"VLC-ID\t%@  ,\naltitude:\t%f",aVLCID,[(ILIndoorLocation *)[self.vlcTable valueForKey:aVLCID]  latitude]);
            return location ;
        }
    }
    return nil;
}

-(ILIndoorLocation*) locationFromHardVLCTable:(NSString*) vlcid{
    ILIndoorLocation * innerIndoorLocation = [[ILIndoorLocation alloc]init];
    if([vlcid hasPrefix:@"0x71"]){
        [innerIndoorLocation setAccuracy:0];
        [innerIndoorLocation setLongitude:2.168635725975037];
        [innerIndoorLocation setLatitude:48.887988338992166];
        [innerIndoorLocation setFloor: [NSNumber numberWithInteger:7]];
        return innerIndoorLocation;
    }else if ([vlcid hasPrefix:@"0x68"]){
        [innerIndoorLocation setAccuracy:0];
        [innerIndoorLocation setLongitude:2.1684533357620244];
        [innerIndoorLocation setLatitude:48.8880923937327];
        [innerIndoorLocation setFloor: [NSNumber numberWithInteger:7]];
        return innerIndoorLocation;
    }else {
        return nil;
    }
    
}
#pragma mark - VLCCallbacks
-(void)onError:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized(message)
        {
            [self dispatchDidFailWithError:nil];
        }
    });
    
}
-(void)onNewMessage:(NSString *)message
{
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    self.vlcID = [json valueForKey:@"data"];
    //NSLog(@"vlcID: %@",json);
    ILIndoorLocation * localIndoorLocation ;
    if (self.beaconsFromServerAvailable)
        localIndoorLocation=[self locationFromServer:self.vlcID];
    else
        localIndoorLocation=[self locationFromHardVLCTable:self.vlcID];
    if (localIndoorLocation==nil) return;
    if (([localIndoorLocation floor]!=[self.lastIndoorLocation floor])
        ||([localIndoorLocation longitude]!=[self.lastIndoorLocation longitude])
        ||([localIndoorLocation latitude]!=[self.lastIndoorLocation latitude])
        ){
        [self.lastIndoorLocation setFloor:localIndoorLocation.floor];
        [self.lastIndoorLocation setLatitude:localIndoorLocation.latitude];
        [self.lastIndoorLocation setLongitude:localIndoorLocation.longitude];
        [self.lastIndoorLocation setTimestamp:[NSDate date] ];
        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized(self.lastIndoorLocation)
            {
                [self dispatchDidUpdateLocation:self.lastIndoorLocation];
            }
        });
    }else{
        [self.lastIndoorLocation setTimestamp:[NSDate date] ];
    }
}

-(void)onProcessStarted:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized(message)
        {
            [self dispatchDidStart];
        }
    });
}
-(void)onProcessStopped:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @synchronized(message)
        {
            [self dispatchDidStop];
        }
    });
}

-(void)defineLocation:(ILIndoorLocation*) location {
    if (self.timer) [self.timer invalidate];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(tick) userInfo:nil repeats:NO];
  //  Timer.scheduledTimer(timeInterval: maxLockedTime, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
    self.locationLocked = YES;
    
    [self dispatchDidUpdateLocation:location];
    
    /*for delegate in self.delegates {
     let castedDelegate = delegate as? ILIndoorLocationProviderDelegate
     castedDelegate?.didLocationChange(location)
     }*/
}

-(void)tick {
    self.locationLocked = NO;
    [VLCSequencer start :[self getBackgroundQueue] withListener:self];
}

@end
