//
//  $Id$
//
//  SPDatabaseStructure.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 25, 2010
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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


#import <SPMySQL/SPMySQLConnectionDelegate.h>

@class SPMySQLConnection, SPDatabaseDocument;

@interface SPDatabaseStructure : NSObject <SPMySQLConnectionDelegate> {
	SPDatabaseDocument *delegate;
	SPMySQLConnection *mySQLConnection;

	NSMutableDictionary *structure;
	NSMutableArray *allKeysofDbStructure;

	NSMutableArray *structureRetrievalThreads;

	pthread_mutex_t threadManagementLock;
	pthread_mutex_t dataLock;
	pthread_mutex_t connectionCheckLock;
}

// Setup and teardown
- (id)initWithDelegate:(SPDatabaseDocument *)theDelegate;
- (void)setConnectionToClone:(SPMySQLConnection *)aConnection;
- (void)destroy;

// Information
- (SPMySQLConnection *)connection;

// Structure retrieval from the server
- (void)queryDbStructureWithUserInfo:(NSDictionary*)userInfo;
- (BOOL)isQueryingDatabaseStructure;

// Structure information
- (NSDictionary *)structure;
- (NSArray *)allStructureKeys;

@end
