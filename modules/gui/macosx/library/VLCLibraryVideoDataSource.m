/*****************************************************************************
 * VLCLibraryVideoDataSource.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan -dot- org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCLibraryVideoDataSource.h"

#import "library/VLCLibraryCollectionViewFlowLayout.h"
#import "library/VLCLibraryCollectionViewItem.h"
#import "library/VLCLibraryCollectionViewMediaItemSupplementaryDetailView.h"
#import "library/VLCLibraryCollectionViewSupplementaryElementView.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryDataTypes.h"

#import "main/CompatibilityFixes.h"
#import "extensions/NSString+Helpers.h"

@interface VLCLibraryVideoDataSource () <NSCollectionViewDelegate, NSCollectionViewDataSource>
{
    NSArray *_recentsArray;
    NSArray *_libraryArray;
    VLCLibraryCollectionViewFlowLayout *_collectionViewFlowLayout;
}

@end

@implementation VLCLibraryVideoDataSource

- (instancetype)init
{
    self = [super init];
    if(self) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelVideoMediaListUpdated
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(libraryModelUpdated:)
                                   name:VLCLibraryModelRecentMediaListUpdated
                                 object:nil];
    }
    return self;
}

- (void)libraryModelUpdated:(NSNotification *)aNotification
{
    [self reloadData];
}

- (void)reloadData
{
    if(!_libraryModel) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _recentsArray = [_libraryModel listOfRecentMedia];
        _libraryArray = [_libraryModel listOfVideoMedia];
        [_libraryMediaCollectionView reloadData];
    });
}

- (void)setupAppearance
{
    _libraryMediaCollectionView.dataSource = self;
    _libraryMediaCollectionView.delegate = self;
    
    [_libraryMediaCollectionView registerClass:[VLCLibraryCollectionViewItem class] forItemWithIdentifier:VLCLibraryCellIdentifier];
    [_libraryMediaCollectionView registerClass:[VLCLibraryCollectionViewSupplementaryElementView class]
                    forSupplementaryViewOfKind:NSCollectionElementKindSectionHeader
                                withIdentifier:VLCLibrarySupplementaryElementViewIdentifier];

    _collectionViewFlowLayout = [[VLCLibraryCollectionViewFlowLayout alloc] init];
    _collectionViewFlowLayout.headerReferenceSize = [VLCLibraryCollectionViewSupplementaryElementView defaultHeaderSize];
    _libraryMediaCollectionView.collectionViewLayout = _collectionViewFlowLayout;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section
{
    if (!_libraryModel) {
        return 0;
    }

    switch(section) {
        case VLCVideoLibraryRecentsSection:
            return [_libraryModel numberOfRecentMedia];
        case VLCVideoLibraryLibrarySection:
        default:
            return [_libraryModel numberOfVideoMedia];
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView
{
    return 2;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    VLCLibraryCollectionViewItem *viewItem = [collectionView makeItemWithIdentifier:VLCLibraryCellIdentifier forIndexPath:indexPath];

    switch(indexPath.section) {
        case VLCVideoLibraryRecentsSection:
            viewItem.representedItem = _recentsArray[indexPath.item];
            break;
        case VLCVideoLibraryLibrarySection:
        default:
            viewItem.representedItem = _libraryArray[indexPath.item];
            break;
    }

    return viewItem;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView
viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind
               atIndexPath:(NSIndexPath *)indexPath
{
    VLCLibraryCollectionViewSupplementaryElementView *view = [collectionView makeSupplementaryViewOfKind:kind
                                                                                          withIdentifier:VLCLibrarySupplementaryElementViewIdentifier
                                                                                            forIndexPath:indexPath];

    switch(indexPath.section) {
        case VLCVideoLibraryRecentsSection:
            view.stringValue = _NS("Recent");
            break;
        case VLCVideoLibraryLibrarySection:
        default:
            view.stringValue = _NS("Library");
            break;
    }

    return view;
}

#pragma mark - drag and drop support

- (BOOL)collectionView:(NSCollectionView *)collectionView
canDragItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
             withEvent:(NSEvent *)event
{
    return YES;
}

- (BOOL)collectionView:(NSCollectionView *)collectionView
writeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
          toPasteboard:(NSPasteboard *)pasteboard
{
    NSUInteger numberOfIndexPaths = indexPaths.count;
    NSMutableArray *encodedLibraryItemsArray = [NSMutableArray arrayWithCapacity:numberOfIndexPaths];
    NSMutableArray *filePathsArray = [NSMutableArray arrayWithCapacity:numberOfIndexPaths];
    for (NSIndexPath *indexPath in indexPaths) {
        VLCMediaLibraryMediaItem *mediaItem = _libraryArray[indexPath.item];
        [encodedLibraryItemsArray addObject:mediaItem];

        VLCMediaLibraryFile *file = mediaItem.files.firstObject;
        if (file) {
            NSURL *url = [NSURL URLWithString:file.MRL];
            [filePathsArray addObject:url.path];
        }
    }

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:encodedLibraryItemsArray];
    [pasteboard declareTypes:@[VLCMediaLibraryMediaItemPasteboardType, NSFilenamesPboardType] owner:self];
    [pasteboard setPropertyList:filePathsArray forType:NSFilenamesPboardType];
    [pasteboard setData:data forType:VLCMediaLibraryMediaItemPasteboardType];

    return YES;
}

@end
