//
//  $Id$
//
//  TablesList.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "TablesList.h"
#import "TableDocument.h"
#import "TableSource.h"
#import "TableContent.h"
#import "SPTableData.h"
#import "TableDump.h"
#import "ImageAndTextCell.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"

@implementation TablesList

#pragma mark IBAction methods

/**
 * Loads all table names in array tables and reload the tableView
 */
- (IBAction)updateTables:(id)sender
{
	CMMCPResult *theResult;
	NSArray *resultRow;
	int i;
	BOOL containsViews = NO;
	NSString *selectedTable = nil;
	NSInteger selectedRowIndex;
	
	selectedRowIndex = [tablesListView selectedRow];
	
	if(selectedRowIndex > 0 && [tables count] && selectedRowIndex < [tables count]){
		selectedTable = [NSString stringWithString:[tables objectAtIndex:selectedRowIndex]];
	}
	
	[tablesListView deselectAll:self];
	[tables removeAllObjects];
	[tableTypes removeAllObjects];
	[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];

	if ([tableDocumentInstance database]) {

		// Notify listeners that a query has started
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

		// Select the table list for the current database.  On MySQL versions after 5 this will include
		// views; on MySQL versions >= 5.0.02 select the "full" list to also select the table type column.
		theResult = [mySQLConnection queryString:@"SHOW /*!50002 FULL*/ TABLES"];
		if ([theResult numOfRows]) [theResult dataSeek:0];
		if ([theResult numOfFields] == 1) {
			for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
				[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:0]];
				[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
			}		
		} else {
			for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
				resultRow = [theResult fetchRowAsArray];
				[tables addObject:[resultRow objectAtIndex:0]];
				if ([[resultRow objectAtIndex:1] isEqualToString:@"VIEW"]) {
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_VIEW]];
					containsViews = YES;
				} else {
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
				}
			}		
		}

		/* grab the procedures and functions
		 *
		 * using information_schema gives us more info (for information window perhaps?) but breaks
		 * backward compatibility with pre 4 I believe. I left the other methods below, in case.
		 */
		NSString *pQuery = [NSString stringWithFormat:@"SELECT * FROM information_schema.routines WHERE routine_schema = '%@' ORDER BY routine_name",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			// add the header row
			[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:NSArrayObjectAtIndex([theResult fetchRowAsArray],3)];
					if( [NSArrayObjectAtIndex([theResult fetchRowAsArray], 4) isEqualToString:@"PROCEDURE"]) {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
					} else {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
					}
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:NSArrayObjectAtIndex(resultRow, 3)];
					if( [NSArrayObjectAtIndex(resultRow, 4) isEqualToString:@"PROCEDURE"] ) {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
					} else {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
					}
				}	
			}
		}
		
		/*
		BOOL addedPFHeader = FALSE;
		NSString *pQuery = [NSString stringWithFormat:@"SHOW PROCEDURE STATUS WHERE db = '%@'",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			// add the header row
			[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			addedPFHeader = TRUE;
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:[resultRow objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
				}	
			}
		}
		
		pQuery = [NSString stringWithFormat:@"SHOW FUNCTION STATUS WHERE db = '%@'",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			if( !addedPFHeader ) {
				// add the header row			
				[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
				[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			}
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:[resultRow objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
				}	
			}
		}
		*/		
		// Notify listeners that the query has finished
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	}

	if (containsViews) {
		[tables insertObject:NSLocalizedString(@"TABLES & VIEWS",@"header for table & views list") atIndex:0];
	} else {
		[tables insertObject:NSLocalizedString(@"TABLES",@"header for table list") atIndex:0];
	}

	[tablesListView reloadData];
	
	// if the previous selected table still exists, select it
	if( selectedTable != nil && [tables indexOfObject:selectedTable] < [tables count]) {
		[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tables indexOfObject:selectedTable]] byExtendingSelection:NO];
	}
}

/**
 * Adds a new table to the tables-array (no changes in mysql-db)
 */
- (IBAction)addTable:(id)sender
{
	if ((![tableSourceInstance saveRowOnDeselect]) || (![tableContentInstance saveRowOnDeselect]) || (![tableDocumentInstance database])) {
		return;
	}

	[tableWindow endEditingFor:nil];
	
	// Populate the table type (engine) popup button
	[tableTypeButton removeAllItems];
	
	NSArray *engines = [databaseDataInstance getDatabaseStorageEngines];
		
	// Add default menu item
	[tableTypeButton addItemWithTitle:@"Default"];
	[[tableTypeButton menu] addItem:[NSMenuItem separatorItem]];
	
	for (NSDictionary *engine in engines)
	{
		[tableTypeButton addItemWithTitle:[engine objectForKey:@"Engine"]];
	}
	
	[NSApp beginSheet:tableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	NSInteger returnCode = [NSApp runModalForWindow:tableSheet];
	
	[NSApp endSheet:tableSheet];
	[tableSheet orderOut:nil];
	
	if (!returnCode) {
		// Clear table name
		[tableNameField setStringValue:@""];
		
		return;
	}
		
	NSString *tableName = [tableNameField stringValue];
	NSString *createStatement = [NSString stringWithFormat:@"CREATE TABLE %@ (id INT)", [tableName backtickQuotedString]];
	
	// If there is an encoding selected other than the default we must specify it in CREATE TABLE statement
	if ([tableEncodingButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ DEFAULT CHARACTER SET %@", createStatement, [[tableDocumentInstance mysqlEncodingFromDisplayEncoding:[tableEncodingButton title]] backtickQuotedString]];
	}
	
	// If there is a type selected other than the default we must specify it in CREATE TABLE statement
	if ([tableTypeButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ ENGINE = %@", createStatement, [[tableTypeButton title] backtickQuotedString]];
	}
	
	// Create the table
	[mySQLConnection queryString:createStatement];
	
	if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		// Table creation was successful
		[tables insertObject:tableName atIndex:1];
		[tableTypes insertObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE] atIndex:1];
		[tablesListView reloadData];
		[tablesListView selectRow:1 byExtendingSelection:NO];
		
		NSInteger selectedIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
		
		if (selectedIndex == 0) {
			[tableSourceInstance loadTable:tableName];
			structureLoaded = YES;
			contentLoaded = NO;
			statusLoaded = NO;
		} 
		else if (selectedIndex == 1) {
			[tableContentInstance loadTable:tableName];
			structureLoaded = NO;
			contentLoaded = YES;
			statusLoaded = NO;
		} 
		else if (selectedIndex == 3) {
			[extendedTableInfoInstance loadTable:tableName];
			structureLoaded = NO;
			contentLoaded = NO; 			
			statusLoaded = YES;
		} 
		else {
			statusLoaded = NO;
			structureLoaded = NO;
			contentLoaded = NO;
		}
		
		// Set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
							  [tableDocumentInstance name], [tableDocumentInstance database], tableName]];
	} 
	else {
		// Error while creating new table
		alertSheetOpened = YES;
		
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't add table %@.\nMySQL said: %@", @"message of panel when table cannot be created with the given name"),
						  tableName, [mySQLConnection getLastErrorMessage]]);
		
		[tableTypes removeObjectAtIndex:([tableTypes count] - 1)];
		[tables removeObjectAtIndex:([tables count] - 1)];
		[tablesListView reloadData];
	}
	
	// Clear table name
	[tableNameField setStringValue:@""];
}

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * Invoked when user hits the remove button alert sheet to ask user if he really wants to delete the table.
 */
- (IBAction)removeTable:(id)sender
{
	if (![tablesListView numberOfSelectedRows])
		return;
	
	[tableWindow endEditingFor:nil];
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"" defaultButton:NSLocalizedString(@"Cancel", @"cancel button") alternateButton:NSLocalizedString(@"Delete", @"delete button") otherButton:nil informativeTextWithFormat:@""];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSIndexSet *indexes = [tablesListView selectedRowIndexes];

	NSString *tblTypes;
	unsigned currentIndex = [indexes lastIndex];
	
	if ([tablesListView numberOfSelectedRows] == 1) {
		if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW)
			tblTypes = NSLocalizedString(@"view", @"view");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE)
			tblTypes = NSLocalizedString(@"table", @"table");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC)
			tblTypes = NSLocalizedString(@"procedure", @"procedure");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC)
			tblTypes = NSLocalizedString(@"function", @"function");
		
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@'?", @"delete table/view message"), tblTypes, [tables objectAtIndex:[tablesListView selectedRow]]]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the %@ '%@'. This operation cannot be undone.", @"delete table/view informative message"), tblTypes, [tables objectAtIndex:[tablesListView selectedRow]]]];
	} 
	else {

		BOOL areTableTypeEqual = YES;
		int lastType = [[tableTypes objectAtIndex:currentIndex] intValue];
		while (currentIndex != NSNotFound)
		{
			if([[tableTypes objectAtIndex:currentIndex] intValue]!=lastType)
			{
				areTableTypeEqual = NO;
				break;
			}
			currentIndex = [indexes indexLessThanIndex:currentIndex];
		}
		if(areTableTypeEqual)
		{
			switch(lastType) {
				case SP_TABLETYPE_TABLE:
				tblTypes = NSLocalizedString(@"tables", @"tables");
				break;
				case SP_TABLETYPE_VIEW:
				tblTypes = NSLocalizedString(@"views", @"views");
				break;
				case SP_TABLETYPE_PROC:
				tblTypes = NSLocalizedString(@"procedures", @"procedures");
				break;
				case SP_TABLETYPE_FUNC:
				tblTypes = NSLocalizedString(@"functions", @"functions");
				break;
			}
			
		} else
			tblTypes = NSLocalizedString(@"items", @"items");

		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete selected %@?", @"delete tables/views message"), tblTypes]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %@. This operation cannot be undone.", @"delete tables/views informative message"), tblTypes]];
	}
		
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeRow"];
}

/**
 * Copies a table/view/proc/func, if desired with content
 */
- (IBAction)copyTable:(id)sender
{
	CMMCPResult *queryResult;
	int code;
	NSString *tableType;
	int tblType;

	if ( [tablesListView numberOfSelectedRows] != 1 ) {
		return;
	}
	
	if ( ![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect] ) {
		return;
	}
	
	[tableWindow endEditingFor:nil];

	// Detect table type: table or view
	tblType = [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	
	switch (tblType){
		case SP_TABLETYPE_TABLE:
			tableType = NSLocalizedString(@"table",@"table");
			[copyTableContentSwitch setEnabled:YES];
			break;
		case SP_TABLETYPE_VIEW:
			tableType = NSLocalizedString(@"view",@"view");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_PROC:
			tableType = NSLocalizedString(@"procedure",@"procedure");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_FUNC:
			tableType = NSLocalizedString(@"function",@"function");
			[copyTableContentSwitch setEnabled:NO];
			break;
	}
		
	[copyTableMessageField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Duplicate %@ '%@' to:", @"duplicate object message"), tableType, [self tableName]]];

	//open copyTableSheet
	[copyTableNameField setStringValue:[NSString stringWithFormat:@"%@_copy", [tables objectAtIndex:[tablesListView selectedRow]]]];
	[copyTableContentSwitch setState:NSOffState];
	
	[NSApp beginSheet:copyTableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	code = [NSApp runModalForWindow:copyTableSheet];
	
	[NSApp endSheet:copyTableSheet];
	[copyTableSheet orderOut:nil];

	if ( !code )
		return;
	if ( [[copyTableNameField stringValue] isEqualToString:@""] ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
		return;
	}

	//get table/view structure
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE %@ %@",
					[tableType uppercaseString],
					[[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]
					]];
	
	if ( ![queryResult numOfRows] ) {
		//error while getting table structure
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't get create syntax.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection getLastErrorMessage]]);

    } else {
		//insert new table name in create syntax and create new table
		NSScanner *scanner = [NSScanner alloc];
		NSString *scanString;

		if(tblType == SP_TABLETYPE_VIEW){
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create View"]];
			[scanner scanUpToString:@"AS" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE VIEW %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		} 
		else if(tblType == SP_TABLETYPE_TABLE){
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"]];
			[scanner scanUpToString:@"(" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		}
		else if(tblType == SP_TABLETYPE_FUNC || tblType == SP_TABLETYPE_PROC)
		{
			// get the create syntax
			CMMCPResult *theResult;
			if([self tableType] == SP_TABLETYPE_PROC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]]];
			else if([self tableType] == SP_TABLETYPE_FUNC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]]];
			else
				return;

			// Check for errors, only displaying if the connection hasn't been terminated
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						[NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving the create syntax for '%@'.\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), [tables objectAtIndex:[tablesListView selectedRow]], [mySQLConnection getLastErrorMessage]]);
				}
				return;
			}

			id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];

			if ([tableSyntax isKindOfClass:[NSData class]])
				tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];

			// replace the old name by the new one and drop the old one
			[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", [tableType uppercaseString]] withString:[[copyTableNameField stringValue] backtickQuotedString]]];
			[tableSyntax release];
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"Couldn't duplicate '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"), [copyTableNameField stringValue], [mySQLConnection getLastErrorMessage]]);
			}

		}
		[scanner release];

        if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			//error while creating new table
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"Couldn't create '%@'.\nMySQL said: %@", @"message of panel when table cannot be created"), [copyTableNameField stringValue], [mySQLConnection getLastErrorMessage]]);
        } else {
			
            if ( [copyTableContentSwitch state] == NSOnState ) {
				//copy table content
                [mySQLConnection queryString:[NSString stringWithFormat:
											  @"INSERT INTO %@ SELECT * FROM %@",
											  [[copyTableNameField stringValue] backtickQuotedString],
											  [[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]
				 ]];
				
                if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
                    NSBeginAlertSheet(
									  NSLocalizedString(@"Warning", @"warning"),
									  NSLocalizedString(@"OK", @"OK button"),
									  nil,
									  nil,
									  tableWindow,
									  self,
									  nil,
									  nil,
									  nil,
									  NSLocalizedString(@"There have been errors while copying table content. Please control the new table.", @"message of panel when table content cannot be copied")
					);
                }
            }
			
			[tables insertObject:[copyTableNameField stringValue] atIndex:[tablesListView selectedRow]+1];
			[tableTypes insertObject:[NSNumber numberWithInt:tblType] atIndex:[tablesListView selectedRow]+1];
			[tablesListView selectRow:[tablesListView selectedRow]+1 byExtendingSelection:NO];
			[self updateTables:self];
			[tablesListView scrollRowToVisible:[tablesListView selectedRow]];

		}
	}
}

/**
 * Renames the currently selected table.
 */
- (IBAction)renameTable:(id)sender
{
	if ((![tableSourceInstance saveRowOnDeselect]) || (![tableContentInstance saveRowOnDeselect]) || (![tableDocumentInstance database])) {
		return;
	}
	
	[tableWindow endEditingFor:nil];
	[tableRenameField setStringValue:[self tableName]];
	[renameTableButton setEnabled:NO];
	NSString *tableType;
	switch([self tableType]){
		case SP_TABLETYPE_TABLE:
		tableType = NSLocalizedString(@"table",@"table");
		break;
		case SP_TABLETYPE_VIEW:
		tableType = NSLocalizedString(@"view",@"view");
		break;
		case SP_TABLETYPE_PROC:
		tableType = NSLocalizedString(@"procedure",@"procedure");
		break;
		case SP_TABLETYPE_FUNC:
		tableType = NSLocalizedString(@"function",@"function");
		break;
	}
	
	[tableRenameText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Rename %@ '%@' to:",@"rename item name to:"), tableType, [self tableName]]];
	
	[NSApp beginSheet:tableRenameSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	NSInteger returnCode = [NSApp runModalForWindow:tableRenameSheet];
	
	[NSApp endSheet:tableRenameSheet];
	[tableRenameSheet orderOut:nil];
	
	if (!returnCode) {
		// Clear table name
		[tableRenameField setStringValue:@""];
		
		return;
	}
	
	if([self tableType] == SP_TABLETYPE_VIEW || [self tableType] == SP_TABLETYPE_TABLE) {
		[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE %@ TO %@", [[self tableName] backtickQuotedString], [[tableRenameField stringValue] backtickQuotedString]]];
	
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
							  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occured while renaming table '%@'.\n\nMySQL said: %@", @"rename table error informative message"), [self tableName], [mySQLConnection getLastErrorMessage]]);
		}
		else {
			// If there was no error, rename the table in our list and reload the table view's data
			[tables replaceObjectAtIndex:[tablesListView selectedRow] withObject:[tableRenameField stringValue]];
		
			[tablesListView reloadData];
		}
	} else {
		// procedures and functions can only be renamed if one creates the new one and delete the old one
		// get the create syntax
		CMMCPResult *theResult;
		if([self tableType] == SP_TABLETYPE_PROC)
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[self tableName] backtickQuotedString]]];
		else if([self tableType] == SP_TABLETYPE_FUNC)
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[self tableName] backtickQuotedString]]];
		else
			return;

		// Check for errors, only displaying if the connection hasn't been terminated
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			if ([mySQLConnection isConnected]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
								  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving create syntax for '%@'.\n\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), [self tableName], [mySQLConnection getLastErrorMessage]]);
			}
			return;
		}

		id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];

		if ([tableSyntax isKindOfClass:[NSData class]])
			tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];

		// replace the old name by the new one and drop the old one
		[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", [tableType uppercaseString]] withString:[[tableRenameField stringValue] backtickQuotedString]]];
		[tableSyntax release];
		if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			if ([mySQLConnection isConnected]) {
				[mySQLConnection queryString: [NSString stringWithFormat: @"DROP %@ %@", tableType, [[self tableName] backtickQuotedString]]];
			}
		}
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"), [self tableName], [mySQLConnection getLastErrorMessage]]);
		} else {
			[tables replaceObjectAtIndex:[tablesListView selectedRow] withObject:[tableRenameField stringValue]];
			[tablesListView reloadData];
		}
	}
	// set window title
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
						  [tableDocumentInstance name], [tableDocumentInstance database], [tableRenameField stringValue]]];
}

/**
 * Truncates the currently selected table(s).
 */
- (IBAction)truncateTable:(id)sender
{
	if (![tablesListView numberOfSelectedRows])
		return;
	
	[tableWindow endEditingFor:nil];
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"" defaultButton:NSLocalizedString(@"Cancel", @"cancel button") alternateButton:NSLocalizedString(@"Truncate", @"truncate button") otherButton:nil informativeTextWithFormat:@""];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	if ([tablesListView numberOfSelectedRows] == 1) {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Truncate table '%@'?", @"truncate table message"), [tables objectAtIndex:[tablesListView selectedRow]]]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete ALL records in the table '%@'. This operation cannot be undone.", @"truncate table informative message"), [tables objectAtIndex:[tablesListView selectedRow]]]];
	} 
	else {
		[alert setMessageText:NSLocalizedString(@"Truncate selected tables?", @"truncate tables message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete ALL records in the selected tables. This operation cannot be undone.", @"truncate tables informative message")];
	}
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"truncateTable"];
}

#pragma mark Alert sheet methods

/**
 * Method for alert sheets. Invoked when user wants to delete a table.
 */
- (void)sheetDidEnd:(NSAlert *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"addRow"]) {
		alertSheetOpened = NO;
	} 
	else if ([contextInfo isEqualToString:@"removeRow"]) {
		[[sheet window] orderOut:nil];
		
		if (returnCode == NSAlertAlternateReturn) {
			[self removeTable];
		}
	}
	else if ([contextInfo isEqualToString:@"truncateTable"]) {
		[[sheet window] orderOut:nil];
		
		if (returnCode == NSAlertAlternateReturn) {
			[self truncateTable];
		}
	}
}

/**
 * Closes copyTableSheet and stops modal session
 */
- (IBAction)closeCopyTableSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

#pragma mark Additional methods

/**
 * Removes the selected table(s) or view(s) from mysql-db and tableView
 */
- (void)removeTable
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	NSString *errorText;
	BOOL error = FALSE;
	
	// get last index
	unsigned currentIndex = [indexes lastIndex];
	while (currentIndex != NSNotFound)
	{

		if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP VIEW %@",
											[[tables objectAtIndex:currentIndex] backtickQuotedString]
											]];
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP TABLE %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP PROCEDURE %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP FUNCTION %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} 
	
		if ( [[mySQLConnection getLastErrorMessage] isEqualTo:@""] ) {
			//dropped table with success
			[tables removeObjectAtIndex:currentIndex];
			[tableTypes removeObjectAtIndex:currentIndex];
		} else {
			//couldn't drop table
			error = TRUE;
			errorText = [mySQLConnection getLastErrorMessage];
		}
		
		// get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}
	
	[tablesListView reloadData];
	
	// set window title
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", [tableDocumentInstance mySQLVersion],
								[tableDocumentInstance name], [tableDocumentInstance database]]];
	
	if ( error ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't remove '%@'.\nMySQL said: %@", @"message of panel when an item cannot be removed"), [tables objectAtIndex:currentIndex], errorText]);
	}
	
	[tablesListView deselectAll:self];
}

/**
 * Trucates the selected table(s).
 */
- (void)truncateTable
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	
	// Get last index
	unsigned currentIndex = [indexes lastIndex];
	
	while (currentIndex != NSNotFound)
	{
		[mySQLConnection queryString:[NSString stringWithFormat: @"TRUNCATE TABLE %@", [[tables objectAtIndex:currentIndex] backtickQuotedString]]]; 
		
		// Couldn't truncate table
		if (![[mySQLConnection getLastErrorMessage] isEqualTo:@""]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error truncating table", @"error truncating table message"), 
								  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to truncate the table '%@'.\n\nMySQL said: %@", @"error truncating table informative message"), [tables objectAtIndex:currentIndex], [mySQLConnection getLastErrorMessage]]);
		}
		
		// Get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}
	[tableContentInstance reloadTable:self];
}

/**
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[self updateTables:self];
}

/**
 * Selects customQuery tab and passes query to customQueryInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[tabView selectTabViewItemAtIndex:2];
	[customQueryInstance doPerformQueryService:query];
}

/**
 * Performs interface validation for various controls.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];
	
	if (object == tableNameField) {
		[addTableButton setEnabled:([[tableNameField stringValue] length] > 0)]; 
	}
	
	if (object == copyTableNameField) {
		([copyTableButton setEnabled:([[copyTableNameField stringValue] length] > 0) && (![[self tableName] isEqualToString:[copyTableNameField stringValue]])]);
	}
	
	if (object == tableRenameField) {
		([renameTableButton setEnabled:([[tableRenameField stringValue] length] > 0) && (![[self tableName] isEqualToString:[tableRenameField stringValue]])]);
	}
}

/*
 * Controls the NSTextField's press RETURN event of Add/Rename/Duplicate sheets
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id object = [notification object];

	// Only RETURN/ENTER will be recognized for Add/Rename/Duplicate sheets to
	// activate the Add/Rename/Duplicate buttons
	if([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] != 0)
		return;

	if (object == tableRenameField) {
		[renameTableButton performClick:object];
	}
	else if (object == tableNameField) {
		[addTableButton performClick:object];
	}
	else if (object == copyTableNameField) {
		[copyTableButton performClick:object];
	}
}

#pragma mark Getter methods

/**
 * Returns the currently selected table or nil if no table or mulitple tables are selected
 */
- (NSString *)tableName
{
	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		return [tables objectAtIndex:[tablesListView selectedRow]];
	} else if ([tablesListView numberOfSelectedRows] > 1) {
		return @"";
	} else {
		return nil;
	}
}

/*
 * Returns the currently selected table type, or -1 if no table or multiple tables are selected
 */
- (int) tableType
{
	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		return [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	} else if ([tablesListView numberOfSelectedRows] > 1) {
		return -1;
	} else {
		return -1;
	}
}

/**
 * Database tables accessor
 */
- (NSArray *)tables
{
	return tables;
}

/**
 * Database table types accessor
 */
- (NSArray *)tableTypes
{
	return tableTypes;
}

/**
 * Returns YES if table source has already been loaded
 */
- (BOOL)structureLoaded
{
	return structureLoaded;
}

/**
 * Returns YES if table content has already been loaded
 */
- (BOOL)contentLoaded
{
	return contentLoaded;
}

/**
 * Returns YES if table status has already been loaded
 */
- (BOOL)statusLoaded
{
	return statusLoaded;
}

#pragma mark Setter methods

/**
 * Mark the content table for refresh when it's next switched to
 */
- (void)setContentRequiresReload:(BOOL)reload
{
	contentLoaded = !reload;
}

/**
 * Mark the exteded table info for refresh when it's next switched to
 */
- (void)setStatusRequiresReload:(BOOL)reload
{
	statusLoaded = !reload;
}

#pragma mark Datasource methods

/**
 * Returns the number of tables in the current database.
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [tables count];
}

/**
 * Returns the table names to be displayed in the tables list table view.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [tables objectAtIndex:rowIndex];
}

/**
 * Renames a table (in tables-array and mysql-db).
 * Removes new table from table-array if renaming had no success
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[tables objectAtIndex:rowIndex] isEqualToString:anObject]) {
		// No changes in table name
	} 
	else if ([anObject isEqualToString:@""]) {
		// Table has no name
		alertSheetOpened = YES;
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Empty names are not allowed.", @"message of panel when no name is given for an item"));
	} 
	else {
		if([self tableType] == SP_TABLETYPE_VIEW || [self tableType] == SP_TABLETYPE_TABLE)
		{
			[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE %@ TO %@", [[tables objectAtIndex:rowIndex] backtickQuotedString], [anObject backtickQuotedString]]];
		} 
		else
		{
			// procedures and functions can only be renamed if one creates the new one and delete the old one
			// get the create syntax
			NSString *tableType;
			switch([self tableType]){
				case SP_TABLETYPE_PROC:
				tableType = @"PROCEDURE";
				break;
				case SP_TABLETYPE_FUNC:
				tableType = @"FUNCTION";
				break;
			}
			CMMCPResult *theResult;
			if([self tableType] == SP_TABLETYPE_PROC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[tables objectAtIndex:rowIndex] backtickQuotedString]]];
			else if([self tableType] == SP_TABLETYPE_FUNC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[tables objectAtIndex:rowIndex] backtickQuotedString]]];
			else
				return;

			// Check for errors, only displaying if the connection hasn't been terminated
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
									  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving create syntax for '%@'.\n\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), [self tableName], [mySQLConnection getLastErrorMessage]]);

				}
				return;
			}

			id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];

			if ([tableSyntax isKindOfClass:[NSData class]])
				tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];

			// replace the old name by the new one and drop the old one
			[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", tableType] withString:[anObject backtickQuotedString]]];
			[tableSyntax release];
			if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					[mySQLConnection queryString: [NSString stringWithFormat: @"DROP %@ %@", tableType, [[tables objectAtIndex:rowIndex] backtickQuotedString]]];
				}
			}
		}
		
		if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			// Renamed with success
			[tables replaceObjectAtIndex:rowIndex withObject:anObject];
			if([self tableType] == SP_TABLETYPE_FUNC || [self tableType] == SP_TABLETYPE_PROC)
				return;
			NSInteger selectedIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
			
			if (selectedIndex == 0) {
				[tableSourceInstance loadTable:anObject];
				structureLoaded = YES;
				contentLoaded = NO;
				statusLoaded = NO;
			} 
			else if (selectedIndex == 1) {
				[tableContentInstance loadTable:anObject];
				structureLoaded = NO;
				contentLoaded = YES;
				statusLoaded = NO;
			} 
			else if (selectedIndex == 3) {
				[extendedTableInfoInstance loadTable:anObject];
				structureLoaded = NO;
				contentLoaded = NO;
				statusLoaded = YES;
			} 
			else {
				statusLoaded = NO;
				structureLoaded = NO;
				contentLoaded = NO;
			}
			
			// Set window title
			[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
								  [tableDocumentInstance name], [tableDocumentInstance database], anObject]];
		} 
		else {
			// Error while renaming
			alertSheetOpened = YES;
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
							  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"),
							  anObject, [mySQLConnection getLastErrorMessage]]);
		}
	}
}

#pragma mark TableView delegate methods

/**
 * Traps enter and esc and edit/cancel without entering next row
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ) {
		//save current line
		[[control window] makeFirstResponder:control];
		return TRUE;
		
	} else if ( [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
		[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] ) {
		
		//abort editing
		[control abortEditing];
		
		if ( [[tables objectAtIndex:[tablesListView selectedRow]] isEqualToString:@""] ) {
			//user added new table and then pressed escape
			[tableTypes removeObjectAtIndex:[tablesListView selectedRow]];
			[tables removeObjectAtIndex:[tablesListView selectedRow]];
			[tablesListView reloadData];
		}
		
		return TRUE;
	} else{
		return FALSE;
	}
}

/**
 * Table view delegate method
 */
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
	// End editing (otherwise problems when user hits reload button)
	[tableWindow endEditingFor:nil];
	
	if ( alertSheetOpened ) {
		return NO;
	}

	// We have to be sure that TableSource and TableContent have finished editing
	if ( ![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect] ) {
		return NO;
	} else {
		return YES;
	}
}

/**
 * Loads a table in content or source view (if tab selected)
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{	
	if ( [tablesListView numberOfSelectedRows] == 1 && [[self tableName] length] ) {
		
		// Reset the table information caches
		[tableDataInstance resetAllData];

		[separatorTableMenuItem setHidden:NO];
		[separatorTableContextMenuItem setHidden:NO];

		if( [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_VIEW ||
		   [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_TABLE) {

			// tableEncoding == nil indicates that there was an error while retrieving table data
			NSString *tableEncoding = [tableDataInstance tableEncoding];
			// If encoding is set to Autodetect, update the connection character set encoding
			// based on the newly selected table's encoding - but only if it differs from the current encoding.
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultEncoding"] isEqualToString:@"Autodetect"]) {
				if (tableEncoding != nil && ![tableEncoding isEqualToString:[tableDocumentInstance connectionEncoding]]) {
					[tableDocumentInstance setConnectionEncoding:tableEncoding reloadingViews:NO];
					[tableDataInstance resetAllData];
				}
			}
		
			if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
				[tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
				structureLoaded = YES;
				contentLoaded = NO;
				statusLoaded = NO;
			} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
				if(tableEncoding == nil) {
					[tableContentInstance loadTable:nil];
				} else {
					[tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
				}
				structureLoaded = NO;
				contentLoaded = YES;
				statusLoaded = NO;
			} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
				[extendedTableInfoInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
				structureLoaded = NO;
				contentLoaded = NO;
				statusLoaded = YES;
			} else {
				structureLoaded = NO;
				contentLoaded = NO;
				statusLoaded = NO;
			}
		} else {
			// if we are not looking at a table or view, clear these
			[tableSourceInstance loadTable:nil];
			[tableContentInstance loadTable:nil];
			[extendedTableInfoInstance loadTable:nil];
			structureLoaded = NO;
			contentLoaded = NO;
			statusLoaded = NO;
		}

		// Set gear menu items Remove/Duplicate table/view and mainMenu > Table items
		// according to the table types
		NSMenu *tableSubMenu = [[[NSApp mainMenu] itemAtIndex:5] submenu];
		
		if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_VIEW)
		{
			// Change mainMenu > Table > ... according to table type
			[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create View Syntax", @"copy create view syntax menu item")];
			[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create View Syntax", @"show create view syntax menu item")];
			[[tableSubMenu itemAtIndex:2] setHidden:NO]; // divider
			[[tableSubMenu itemAtIndex:3] setHidden:NO];
			[[tableSubMenu itemAtIndex:3] setTitle:NSLocalizedString(@"Check View", @"check view menu item")];
			[[tableSubMenu itemAtIndex:4] setHidden:YES]; // repair
			[[tableSubMenu itemAtIndex:5] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:6] setHidden:YES]; // analyse
			[[tableSubMenu itemAtIndex:7] setHidden:YES]; // optimize
			[[tableSubMenu itemAtIndex:8] setHidden:NO];
			[[tableSubMenu itemAtIndex:8] setTitle:NSLocalizedString(@"Flush View", @"flush view menu item")];
			[[tableSubMenu itemAtIndex:9] setHidden:YES]; // checksum

			[renameTableMenuItem setHidden:NO]; // we don't have to check the mysql version
			[renameTableMenuItem setTitle:NSLocalizedString(@"Rename View...", @"rename view menu title")];
			[duplicateTableMenuItem setHidden:NO];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate View...", @"duplicate view menu title")];
			[truncateTableButton setHidden:YES];
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove View", @"remove view menu title")];

			[renameTableContextMenuItem setHidden:NO]; // we don't have to check the mysql version
			[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename View...", @"rename view menu title")];
			[duplicateTableContextMenuItem setHidden:NO];
			[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate View...", @"duplicate view menu title")];
			[truncateTableContextButton setHidden:YES];
			[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove View", @"remove view menu title")];
		} 
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_TABLE) {
			[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Table Syntax", @"copy create table syntax menu item")];
			[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Table Syntax", @"show create table syntax menu item")];
			[[tableSubMenu itemAtIndex:2] setHidden:NO]; // divider
			[[tableSubMenu itemAtIndex:3] setHidden:NO];
			[[tableSubMenu itemAtIndex:3] setTitle:NSLocalizedString(@"Check Table", @"check table menu item")];
			[[tableSubMenu itemAtIndex:4] setHidden:NO];
			[[tableSubMenu itemAtIndex:5] setHidden:NO]; // divider
			[[tableSubMenu itemAtIndex:6] setHidden:NO];
			[[tableSubMenu itemAtIndex:7] setHidden:NO];
			[[tableSubMenu itemAtIndex:8] setHidden:NO];
			[[tableSubMenu itemAtIndex:8] setTitle:NSLocalizedString(@"Flush Table", @"flush table menu item")];
			[[tableSubMenu itemAtIndex:9] setHidden:NO];

			[renameTableMenuItem setHidden:NO];
			[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Table...", @"rename table menu title")];
			[duplicateTableMenuItem setHidden:NO];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Table...", @"duplicate table menu title")];
			[truncateTableButton setHidden:NO];
			[truncateTableButton setTitle:NSLocalizedString(@"Truncate Table", @"truncate table menu title")];
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Table", @"remove table menu title")];

			[renameTableContextMenuItem setHidden:NO];
			[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Table...", @"rename table menu title")];
			[duplicateTableContextMenuItem setHidden:NO];
			[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Table...", @"duplicate table menu title")];
			[truncateTableContextButton setHidden:NO];
			[truncateTableContextButton setTitle:NSLocalizedString(@"Truncate Table", @"truncate table menu title")];
			[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Table", @"remove table menu title")];

		} 
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_PROC) {
			[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Procedure Syntax", @"copy create proc syntax menu item")];
			[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Procedure Syntax", @"show create proc syntax menu item")];
			[[tableSubMenu itemAtIndex:2] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:3] setHidden:YES]; // copy columns
			[[tableSubMenu itemAtIndex:4] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:5] setHidden:YES];
			[[tableSubMenu itemAtIndex:6] setHidden:YES];
			[[tableSubMenu itemAtIndex:7] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:8] setHidden:YES];
			[[tableSubMenu itemAtIndex:9] setHidden:YES];
			
			[renameTableMenuItem setHidden:NO];
			[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Procedure...", @"rename proc menu title")];
			[duplicateTableMenuItem setHidden:NO];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Procedure...", @"duplicate proc menu title")];
			[truncateTableButton setHidden:YES];
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Procedure", @"remove proc menu title")];

			[renameTableContextMenuItem setHidden:NO];
			[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Procedure...", @"rename proc menu title")];
			[duplicateTableContextMenuItem setHidden:NO];
			[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Procedure...", @"duplicate proc menu title")];
			[truncateTableContextButton setHidden:YES];
			[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Procedure", @"remove proc menu title")];

		}
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_FUNC) {
			[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Function Syntax", @"copy create func syntax menu item")];
			[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Function Syntax", @"show create func syntax menu item")];
			[[tableSubMenu itemAtIndex:2] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:3] setHidden:YES]; // copy columns
			[[tableSubMenu itemAtIndex:4] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:5] setHidden:YES];
			[[tableSubMenu itemAtIndex:6] setHidden:YES];
			[[tableSubMenu itemAtIndex:7] setHidden:YES]; // divider
			[[tableSubMenu itemAtIndex:8] setHidden:YES];
			[[tableSubMenu itemAtIndex:9] setHidden:YES];	
			
			[renameTableMenuItem setHidden:NO];
			[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Function...", @"rename func menu title")];
			[duplicateTableMenuItem setHidden:NO];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Function...", @"duplicate func menu title")];
			[truncateTableButton setHidden:YES];
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Function", @"remove func menu title")];

			[renameTableContextMenuItem setHidden:NO];
			[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Function...", @"rename func menu title")];
			[duplicateTableContextMenuItem setHidden:NO];
			[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Function...", @"duplicate func menu title")];
			[truncateTableContextButton setHidden:YES];
			[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Function", @"remove func menu title")];

		}
		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
									[tableDocumentInstance name], [tableDocumentInstance database], [tables objectAtIndex:[tablesListView selectedRow]]]];

		// Update the "Show Create Syntax" window if it's already opened
		// according to the selected table/view/proc/func
		if([[tableDocumentInstance getCreateTableSyntaxWindow] isVisible])
			[tableDocumentInstance showCreateTableSyntax:self];

	} else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
		[extendedTableInfoInstance loadTable:nil];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;

		// Set gear menu items Remove/Duplicate table/view according to the table types
		// if at least one item is selected
		NSIndexSet *indexes = [tablesListView selectedRowIndexes];
		if([indexes count]) {
			unsigned int currentIndex = [indexes lastIndex];
			BOOL areTableTypeEqual = YES;
			int lastType = [[tableTypes objectAtIndex:currentIndex] intValue];
			while (currentIndex != NSNotFound)
			{
				if([[tableTypes objectAtIndex:currentIndex] intValue]!=lastType)
				{
					areTableTypeEqual = NO;
					break;
				}
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}
			if(areTableTypeEqual)
			{
				switch(lastType) {
					case SP_TABLETYPE_TABLE:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Tables", @"remove tables menu title")];
					[truncateTableButton setTitle:NSLocalizedString(@"Truncate Tables", @"truncate tables menu item")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Tables", @"remove tables menu title")];
					[truncateTableContextButton setTitle:NSLocalizedString(@"Truncate Tables", @"truncate tables menu item")];
					[truncateTableButton setHidden:NO];
					[truncateTableContextButton setHidden:NO];
					break;
					case SP_TABLETYPE_VIEW:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Views", @"remove views menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Views", @"remove views menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
					case SP_TABLETYPE_PROC:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Procedures", @"remove procedures menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Procedures", @"remove procedures menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
					case SP_TABLETYPE_FUNC:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Functions", @"remove functions menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Functions", @"remove functions menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
				}
			
			} else {
				[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Items", @"remove items menu title")];
				[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Items", @"remove items menu title")];
				[truncateTableButton setHidden:YES];
				[truncateTableContextButton setHidden:YES];
			}
		}
		[renameTableContextMenuItem setHidden:YES];
		[duplicateTableContextMenuItem setHidden:YES];
		[separatorTableContextMenuItem setHidden:YES];

		[renameTableMenuItem setHidden:YES];
		[duplicateTableMenuItem setHidden:YES];
		[separatorTableMenuItem setHidden:YES];
		[separatorTableContextMenuItem setHidden:YES];
		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", [tableDocumentInstance mySQLVersion],
									[tableDocumentInstance name], [tableDocumentInstance database]]];
	}
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	//return (rowIndex != 0);
	if( [tableTypes count] == 0 )
		return (rowIndex != 0 );
	return ([[tableTypes objectAtIndex:rowIndex] intValue] != SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)rowIndex
{
	//return (row == 0);	
	if( [tableTypes count] == 0 )
		return (rowIndex == 0 );
	return ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (void)tableView:(NSTableView *)aTableView  willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (rowIndex > 0 && [[aTableColumn identifier] isEqualToString:@"tables"]) {
		if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_VIEW) {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-view-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_TABLE) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_PROC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"proc-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_FUNC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"func-small"]];
		}
	
		if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE) {
			[(ImageAndTextCell*)aCell setImage:nil];
			[(ImageAndTextCell*)aCell setIndentationLevel:0];
		} else {
			[(ImageAndTextCell*)aCell setIndentationLevel:1];
			[(ImageAndTextCell*)aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];			
		}
	} else {
		[(ImageAndTextCell*)aCell setImage:nil];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
}

/**
 * Table view delegate method
 */
- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row
{
	return (row == 0) ? 25 : 17;
}

#pragma mark TabView delegate methods

/**
 * Loads structure or source if tab selected the first time
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ( [tablesListView numberOfSelectedRows] == 1  && 
		([self tableType] == SP_TABLETYPE_TABLE || [self tableType] == SP_TABLETYPE_VIEW) ) {
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) && !structureLoaded ) {
			[tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			structureLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1) && !contentLoaded ) {
			[tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			contentLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3) && !statusLoaded ) {
			[extendedTableInfoInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			statusLoaded = YES;
		}
	}
	else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
	}
}

/**
 * Menu item interface validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// popup button below table list
	if ([menuItem action] == @selector(copyTable:)) {
		return (([tablesListView numberOfSelectedRows] == 1) && [[self tableName] length] && [tablesListView numberOfSelectedRows] > 0);
	}
	
	if ([menuItem action] == @selector(removeTable:) || [menuItem action] == @selector(truncateTable:)) {
		return ([tablesListView numberOfSelectedRows] > 0);
	}

	if ([menuItem action] == @selector(renameTable:)) {
		return (([tablesListView numberOfSelectedRows] == 1) && [[self tableName] length]);
	}
	
	return [super validateMenuItem:menuItem];
}		

#pragma mark Other

/**
 * Standard init method. Performs various ivar initialisations. 
 */
- (id)init
{
	if ((self = [super init])) {
		tables = [[NSMutableArray alloc] init];
		tableTypes = [[NSMutableArray alloc] init];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		[tables addObject:NSLocalizedString(@"TABLES",@"header for table list")];
	}
	
	return self;
}

/**
 * Standard dealloc method.
 */
- (void)dealloc
{	
	[tables release], tables = nil;
	[tableTypes release], tableTypes = nil;
	
	[super dealloc];
}

@end
