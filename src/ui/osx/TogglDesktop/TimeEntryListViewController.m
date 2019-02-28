//
//  TimeEntryListViewController.m
//  Toggl Desktop on the Mac
//
//  Created by Tanel Lebedev on 19/09/2013.
//  Copyright (c) 2013 TogglDesktop developers. All rights reserved.
//

#import "TimeEntryListViewController.h"
#import "TimeEntryViewItem.h"
#import "TimerEditViewController.h"
#import "UIEvents.h"
#import "toggl_api.h"
#import "LoadMoreCell.h"
#import "TimeEntryCell.h"
#import "UIEvents.h"
#import "DisplayCommand.h"
#import "TimeEntryEditViewController.h"
#import "ConvertHexColor.h"
#include <Carbon/Carbon.h>
#import "TogglDesktop-Swift.h"
#import "TimeEntryCollectionView.h"

@interface TimeEntryListViewController ()
@property (nonatomic, strong) IBOutlet TimerEditViewController *timerEditViewController;
@property NSNib *nibTimeEntryCell;
@property NSNib *nibTimeEntryEditViewController;
@property NSNib *nibLoadMoreCell;
@property NSInteger defaultPopupHeight;
@property NSInteger defaultPopupWidth;
@property NSInteger addedHeight;
@property NSInteger minimumEditFormWidth;
@property BOOL runningEdit;
@property TimeEntryCell *selectedEntryCell;
@property (copy, nonatomic) NSString *lastSelectedGUID;
@property (nonatomic, strong) IBOutlet TimeEntryEditViewController *timeEntryEditViewController;
@property (nonatomic, strong) NSArray<TimeEntryViewItem *> *viewitems;
@property (weak) IBOutlet TimeEntryCollectionView *collectionView;

@end

@implementation TimeEntryListViewController

extern void *ctx;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self)
	{
		self.timerEditViewController = [[TimerEditViewController alloc]
										initWithNibName:@"TimerEditViewController" bundle:nil];
		self.timeEntryEditViewController = [[TimeEntryEditViewController alloc]
											initWithNibName:@"TimeEntryEditViewController" bundle:nil];
		[self.timerEditViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self.timeEntryEditViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

		self.viewitems = [[NSArray<TimeEntryViewItem *> alloc] init];

		self.nibTimeEntryCell = [[NSNib alloc] initWithNibNamed:@"TimeEntryCell"
														 bundle:nil];
		self.nibTimeEntryEditViewController = [[NSNib alloc] initWithNibNamed:@"TimeEntryEditViewController"
																	   bundle:nil];
		self.nibLoadMoreCell = [[NSNib alloc] initWithNibNamed:@"LoadMoreCell"
														bundle:nil];
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self initCommon];
	[self initCollectionView];
	[self setupEmptyLabel];
	[self initNotifications];
}

- (void)viewDidAppear
{
	[super viewDidAppear];
	[self.collectionView reloadData];
}

- (void)initCommon {
	[self.headerView addSubview:self.timerEditViewController.view];
	[self.timerEditViewController.view setFrame:self.headerView.bounds];

	[self.timeEntryPopupEditView addSubview:self.timeEntryEditViewController.view];
	[self.timeEntryEditViewController.view setFrame:self.timeEntryPopupEditView.bounds];
	self.defaultPopupHeight = self.timeEntryPopupEditView.bounds.size.height;
	self.addedHeight = 0;
	self.minimumEditFormWidth = self.timeEntryPopupEditView.bounds.size.width;
	self.runningEdit = NO;
}

- (void)initNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayTimeEntryList:)
												 name:kDisplayTimeEntryList
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayTimeEntryEditor:)
												 name:kDisplayTimeEntryEditor
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayLogin:)
												 name:kDisplayLogin
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(closeEditPopup:)
												 name:kForceCloseEditPopover
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resizeEditPopupHeight:)
												 name:kResizeEditForm
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resizeEditPopupWidth:)
												 name:kResizeEditFormWidth
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resetEditPopover:)
												 name:NSPopoverDidCloseNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(closeEditPopup:)
												 name:kCommandStop
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resetEditPopoverSize:)
												 name:kResetEditPopoverSize
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(focusListing:)
												 name:kFocusListing
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(escapeListing:)
												 name:kEscapeListing
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(effectiveAppearanceChangedNotification)
												 name:NSNotification.EffectiveAppearanceChanged
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowSizeDidChange)
												 name:NSWindowDidResizeNotification
											   object:nil];
}

- (void)initCollectionView
{
	self.dataSource = [[TimeEntryDatasource alloc] initWithCollectionView:self.collectionView];

	// Drag and drop
	[self.collectionView setDraggingSourceOperationMask:NSDragOperationLink forLocal:NO];
	[self.collectionView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
	[self.collectionView registerForDraggedTypes:[NSArray arrayWithObject:NSStringPboardType]];
}

- (void)setupEmptyLabel
{
	NSMutableParagraphStyle *paragrapStyle = NSMutableParagraphStyle.new;

	paragrapStyle.alignment = kCTTextAlignmentCenter;

	NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:@" reports"];

	[string setAttributes:
	 @{
		 NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
		 NSForegroundColorAttributeName:[NSColor alternateSelectedControlColor]
	 }
					range:NSMakeRange(0, [string length])];
	NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Welcome back! Your previous entries are available in the web under" attributes:
									   @{ NSParagraphStyleAttributeName:paragrapStyle }];
	[text appendAttributedString:string];
	[self.emptyLabel setAttributedStringValue:text];
	[self.emptyLabel setAlignment:NSCenterTextAlignment];
}

- (void)startDisplayTimeEntryList:(NSNotification *)notification
{
	[self displayTimeEntryList:notification.object];
}

- (void)displayTimeEntryList:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	NSLog(@"TimeEntryListViewController displayTimeEntryList, thread %@", [NSThread currentThread]);

	NSArray<TimeEntryViewItem *> *newTimeEntries = [cmd.timeEntries copy];

    // reload
	[self.dataSource process:newTimeEntries showLoadMore:cmd.show_load_more];

    // Handle Popover
	if (cmd.open)
	{
		if (self.timeEntrypopover.shown)
		{
			[self.timeEntrypopover close];
			[self setDefaultPopupSize];
		}
        // when timer not focused
		if ([self.timerEditViewController.autoCompleteInput currentEditor] == nil)
		{
			[self focusListing:nil];
		}
	}

    // Show Empty view if need
	BOOL noItems = newTimeEntries.count == 0;
	[self.emptyLabel setEnabled:noItems];
	[self.timeEntryListScrollView setHidden:noItems];
}

- (void)resetEditPopover:(NSNotification *)notification
{
	if (notification.object == self.timeEntrypopover)
	{
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kResetEditPopover
																	object:nil];
	}
}

- (void)popoverWillClose:(NSNotification *)notification
{
	NSLog(@"%@", notification.userInfo);
}

- (void)displayTimeEntryEditor:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	NSLog(@"TimeEntryListViewController displayTimeEntryEditor, thread %@", [NSThread currentThread]);

    // Get selected index
	NSIndexPath *selectedIndexpath = [self.collectionView.selectionIndexPaths.allObjects firstObject];
	if (selectedIndexpath == nil)
	{
		return;
	}

	if (cmd.open)
	{
		self.timeEntrypopover.contentViewController = self.timeEntrypopoverViewController;
		self.runningEdit = (cmd.timeEntry.duration_in_seconds < 0);

		NSView *ofView = self.view;
		CGRect positionRect = [self positionRectOfSelectedRowAtIndexPath:selectedIndexpath];

		if (self.runningEdit)
		{
			ofView = self.headerView;
			positionRect = [ofView bounds];
			self.lastSelectedGUID = nil;
		}
		else if (self.selectedEntryCell && [self.selectedEntryCell isKindOfClass:[TimeEntryCell class]])
		{
			self.lastSelectedGUID = ((TimeEntryCell *)self.selectedEntryCell).GUID;
			ofView = self.collectionView;
		}

        // Show popover
		[self.timeEntrypopover showRelativeToRect:positionRect
										   ofView:ofView
									preferredEdge:NSMaxXEdge];

		BOOL onLeft = (self.view.window.frame.origin.x > self.timeEntryPopupEditView.window.frame.origin.x);
		[self.timeEntryEditViewController setDragHandle:onLeft];
	}
}

- (CGRect)positionRectOfSelectedRowAtIndexPath:(NSIndexPath *)indexPath {
	TimeEntryCell *selectedCell = [self getSelectedEntryCellWithIndexPath:indexPath];
	NSRect positionRect = self.view.bounds;

	if (selectedCell)
	{
		positionRect = [self.collectionView convertRect:selectedCell.view.bounds
											   fromView:selectedCell.view];
	}
	return positionRect;
}

- (void)startDisplayTimeEntryEditor:(NSNotification *)notification
{
	[self displayTimeEntryEditor:notification.object];
}

- (BOOL)  tableView:(NSTableView *)aTableView
	shouldSelectRow:(NSInteger)rowIndex
{
	[self clearLastSelectedEntry];
	return YES;
}

- (TimeEntryCell *)getSelectedEntryCellWithIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section < 0 ||  indexPath.section >= self.collectionView.numberOfSections)
	{
		return nil;
	}

	self.selectedEntryCell = nil;

	id item = [self.collectionView itemAtIndexPath:indexPath];
	if ([item isKindOfClass:[TimeEntryCell class]])
	{
		self.selectedEntryCell = (TimeEntryCell *)item;
		return self.selectedEntryCell;
	}
	return nil;
}

- (void)clearLastSelectedEntry
{
	[self.selectedEntryCell setupGroupMode];
}

- (void)resetEditPopoverSize:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kResetEditPopover
																object:nil];
	[self setDefaultPopupSize];
}

- (void)resizing:(NSSize)n
{
	[self.timeEntrypopover setContentSize:n];
	NSRect f = [self.timeEntryEditViewController.view frame];
	NSRect r = NSMakeRect(f.origin.x,
						  f.origin.y,
						  n.width,
						  n.height);

	[self.timeEntryPopupEditView setBounds:r];
	[self.timeEntryEditViewController.view setFrame:self.timeEntryPopupEditView.bounds];
}

- (void)resizeEditPopupHeight:(NSNotification *)notification
{
	if (!self.timeEntrypopover.shown)
	{
		return;
	}
	NSInteger addHeight = [[[notification userInfo] valueForKey:@"height"] intValue];
	if (addHeight == self.addedHeight)
	{
		return;
	}
	self.addedHeight = addHeight;
	float newHeight = self.timeEntrypopover.contentSize.height + self.addedHeight;
	NSSize n = NSMakeSize(self.timeEntrypopover.contentSize.width, newHeight);

	[self resizing:n];
}

- (void)resizeEditPopupWidth:(NSNotification *)notification
{
	if (!self.timeEntrypopover.shown)
	{
		return;
	}
	int i = [[[notification userInfo] valueForKey:@"width"] intValue];
	float newWidth = self.timeEntrypopover.contentSize.width + i;

	if (newWidth < self.minimumEditFormWidth)
	{
		return;
	}
	NSSize n = NSMakeSize(newWidth, self.timeEntrypopover.contentSize.height);

	[self resizing:n];
}

- (void)closeEditPopup:(NSNotification *)notification
{
	if (self.timeEntrypopover.shown)
	{
		if ([self.timeEntryEditViewController autcompleteFocused])
		{
			return;
		}
		if (self.runningEdit)
		{
			[self.timeEntryEditViewController closeEdit];
			self.runningEdit = false;
		}
		else
		{
			[self.selectedEntryCell openEdit];
		}

		[self setDefaultPopupSize];
	}
}

- (void)setDefaultPopupSize
{
	if (self.addedHeight != 0)
	{
		NSSize n = NSMakeSize(self.timeEntrypopover.contentSize.width, self.defaultPopupHeight);

		[self resizing:n];
		self.addedHeight = 0;
	}
}

- (void)startDisplayLogin:(NSNotification *)notification
{
	[self displayLogin:notification.object];
}

- (void)displayLogin:(DisplayCommand *)cmd
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");
	if (cmd.open && self.timeEntrypopover.shown)
	{
		[self.timeEntrypopover close];
		[self setDefaultPopupSize];
	}
}

- (void)textFieldClicked:(id)sender
{
	if (sender == self.emptyLabel && [self.emptyLabel isEnabled])
	{
		toggl_open_in_browser(ctx);
	}
}

- (void)focusListing:(NSNotification *)notification
{
	if (self.collectionView.numberOfSections == 0)
	{
		return;
	}

	NSIndexPath *selectedIndexpath = [self.collectionView.selectionIndexPaths.allObjects firstObject];
    // If list is focused with keyboard shortcut
	if (notification != nil && !self.timeEntrypopover.shown)
	{
		[self clearLastSelectedEntry];
		selectedIndexpath = [NSIndexPath indexPathForItem:0 inSection:0];
	}

	if (selectedIndexpath == nil)
	{
		return;
	}

	[[self.collectionView window] makeFirstResponder:self.collectionView];
	[self.collectionView selectItemsAtIndexPaths:[NSSet setWithObject:selectedIndexpath] scrollPosition:NSCollectionViewScrollPositionTop];

	TimeEntryCell *cell = [self getSelectedEntryCellWithIndexPath:selectedIndexpath];
	if (cell != nil)
	{
		[self clearLastSelectedEntry];
		[cell setFocused];
	}
}

- (void)escapeListing:(NSNotification *)notification
{
	if (self.timeEntrypopover.shown)
	{
		[self closeEditPopup:nil];
		return;
	}
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:kFocusTimer
																object:nil];
	[self clearLastSelectedEntry];
	[self.collectionView deselectAll:nil];
	self.selectedEntryCell = nil;
}

#pragma mark Drag & Drop Delegates



- (void)effectiveAppearanceChangedNotification {
    // Re-draw hard-code color sheme for all cells in tableview
	[self.collectionView reloadData];
}

- (void)windowSizeDidChange {
    // We have to reload entire collection rather than calling [self.collectionView.collectionViewLayout invalidateLayout];
    // Because it's difficult to re-draw the mask for highlight state of TimeEntryCell
    // -invalidateLayout is more better in term of performance
    // User is rarely to resize the app, so I believe it's reasonable.
	[self.collectionView reloadData];
}

@end
