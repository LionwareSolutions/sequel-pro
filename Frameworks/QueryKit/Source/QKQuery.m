//
//  $Id: QKQuery.m 3432 2011-09-27 00:21:35Z stuart02 $
//
//  QKQuery.h
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "QKQuery.h"

static NSString *QKNoQueryTypeException = @"QKNoQueryType";
static NSString *QKNoQueryTableException = @"QKNoQueryTable";

@interface QKQuery ()

- (void)_validateRequiements;

- (NSString *)_buildQuery;
- (NSString *)_buildFieldList;
- (NSString *)_buildConstraints;
- (NSString *)_buildGroupByClause;
- (NSString *)_buildOrderByClause;
- (NSString *)_buildUpdateClause;
- (NSString *)_buildSelectOptions;

- (BOOL)_addString:(NSString *)string toArray:(NSMutableArray *)array;

@end

@implementation QKQuery

@synthesize _database;
@synthesize _table;
@synthesize _parameters;
@synthesize _queryType;
@synthesize _fields;
@synthesize _updateParameters;
@synthesize _quoteFields;

#pragma mark -
#pragma mark Initialization

+ (QKQuery *)queryTable:(NSString *)table
{
	return [[[QKQuery alloc] initWithTable:table] autorelease];
}

+ (QKQuery *)selectQueryFromTable:(NSString *)table
{
	QKQuery *query = [[[QKQuery alloc] initWithTable:table] autorelease];
	
	[query setQueryType:QKSelectQuery];
	
	return query;
}

- (id)initWithTable:(NSString *)table
{
	if ((self = [super init])) {
		[self setTable:table];
		[self setFields:[[NSMutableArray alloc] init]];
		[self setUpdateParameters:[[NSMutableArray alloc] init]];
		[self setParameters:[[NSMutableArray alloc] init]];
		[self setQueryType:(QKQueryType)-1];
		[self setQuoteFields:NO];
		
		_orderDescending = NO;
		
		_groupByFields = [[NSMutableArray alloc] init];
		_orderByFields = [[NSMutableArray alloc] init];
		
		_query = [[NSMutableString alloc] init];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Requests that the query be built.
 *
 * @return The generated query.
 */
- (NSString *)query
{
	return _query ? [self _buildQuery] : @""; 
}

/**
 * Clears anything this instance should know about the query it's building.
 */
- (void)clear
{
	[self setTable:nil];
	[self setDatabase:nil];
	[self setQueryType:(QKQueryType)-1];
	
	[_fields removeAllObjects];
	[_parameters removeAllObjects];
	[_updateParameters removeAllObjects];
	[_groupByFields removeAllObjects];
	[_orderByFields removeAllObjects];
}

#pragma mark -
#pragma mark Fields

/**
 * Shortcut for adding a new field to this query.
 */
- (void)addField:(NSString *)field
{
	[self _addString:field toArray:_fields];
}

/**
 * Convenience method for adding more than one field.
 *
 * @param The array (of strings) of fields to add.
 */
- (void)addFields:(NSArray *)fields
{
	for (NSString *field in fields)
	{
		[self addField:field];
	}
}

#pragma mark -
#pragma mark Parameters

/**
 * Adds the supplied parameter.
 *
 * @param parameter The parameter to add.
 */
- (void)addParameter:(QKQueryParameter *)parameter
{
	if ([parameter field] && ([[parameter field] length] > 0) && ((NSInteger)[parameter operator] > -1) && [parameter value]) {
		[_parameters addObject:parameter];
	} 
}

/**
 * Convenience method for adding a new parameter.
 */
- (void)addParameter:(NSString *)field operator:(QKQueryOperator)operator value:(id)value
{	
	[self addParameter:[QKQueryParameter queryParamWithField:field operator:operator value:value]];
}

#pragma mark -
#pragma mark Update Parameters

/**
 * Adds the supplied update parameter.
 *
 * @param parameter The parameter to add.
 */
- (void)addFieldToUpdate:(QKQueryUpdateParameter *)parameter
{
	if ([parameter field] && ([[parameter field] length] > 0) && [parameter value]) {
		[_updateParameters addObject:parameter];
	}
}

/**
 * Convenience method for adding a new update parameter.
 */
- (void)addFieldToUpdate:(NSString *)field toValue:(id)value
{
	[self addFieldToUpdate:[QKQueryUpdateParameter queryUpdateParamWithField:field value:value]];
}

#pragma mark -
#pragma mark Grouping

/**
 * Adds the supplied field to the query's GROUP BY clause.
 */
- (void)groupByField:(NSString *)field
{
	[self _addString:field toArray:_groupByFields];
}

/**
 * Convenience method for adding more than one field to the query's GROUP BY clause.
 */
- (void)groupByFields:(NSArray *)fields
{
	for (NSString *field in fields)
	{
		[self groupByField:field];
	}
}

#pragma mark -
#pragma mark Ordering

/**
 * Adds the supplied field to the query's ORDER BY clause.
 */
- (void)orderByField:(NSString *)field descending:(BOOL)descending
{
	_orderDescending = descending;
	
	[self _addString:field toArray:_orderByFields];
}

/**
 * Convenience method for adding more than one field to the query's ORDER BY clause.
 */
- (void)orderByFields:(NSArray *)fields descending:(BOOL)descending
{
	for (NSString *field in fields)
	{
		[self orderByField:field descending:descending];
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Validates that everything necessary to build the query has been set.
 */
- (void)_validateRequiements
{
	if (_queryType == -1) {
		[NSException raise:QKNoQueryTypeException format:@"Attempt to build query with no query type specified."];
	}
	
	if (!_table || [_table length] == 0) {
		[NSException raise:QKNoQueryTableException format:@"Attempt to build query with no query table specified."];
	}
}

/**
 * Builds the actual query.
 */
- (NSString *)_buildQuery
{
	[self _validateRequiements];
	
	BOOL isSelect = _queryType == QKSelectQuery;
	BOOL isInsert = _queryType == QKInsertQuery;
	BOOL isUpdate = _queryType == QKUpdateQuery;
	BOOL isDelete = _queryType == QKDeleteQuery;
	
	NSString *fields = [self _buildFieldList];
	
	if (isSelect) {
		[_query appendFormat:@"SELECT %@ FROM ", fields];
	}
	else if (isInsert) {
		[_query appendString:@"INSERT INTO "];
	}
	else if (isUpdate) {
		[_query appendString:@"UPDATE "];
	}
	else if (isDelete) {
		[_query appendString:@"DELETE FROM "];
	}
	
	if (_database && [_database length] > 0) {
		[_query appendFormat:@"%@.", _database];
	}
	
	[_query appendString:_table];
	
	if (isUpdate) {
		[_query appendFormat:@" %@", [self _buildUpdateClause]];
	}
	
	if ([_parameters count] > 0) {
		[_query appendFormat:@" WHERE %@", [self _buildConstraints]];
	}
	
	if (isSelect) {
		[_query appendString:[self _buildSelectOptions]];
	}
	
	return _query;
}

/**
 * Builds the string representation of the query's field list.
 */
- (NSString *)_buildFieldList
{
	NSMutableString *fields = [NSMutableString string];
	
	if ([_fields count] == 0) {
		[fields appendString:@"*"];
		
		return fields;
	}
	
	for (NSString *field in _fields)
	{		
		field = [field stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([field length] == 0) continue;
		
		if (_quoteFields) {
			[fields appendString:@"`"];
		}
		
		[fields appendString:field];
		
		if (_quoteFields) {
			[fields appendString:@"`"];
		}
		
		[fields appendString:@", "];
	}
	
	if ([fields hasSuffix:@", "]) {
		[fields setString:[fields substringToIndex:([fields length] - 2)]];
	}
	
	return fields;
}

/**
 * Builds the string representation of the query's constraints.
 */
- (NSString *)_buildConstraints
{
	NSMutableString *constraints = [NSMutableString string];
	
	if ([_parameters count] == 0) return constraints;
	
	for (QKQueryParameter *param in _parameters)
	{
		[constraints appendFormat:@"%@", param];
		
		[constraints appendString:@" AND "];
	}
	
	if ([constraints hasSuffix:@" AND "]) {
		[constraints setString:[constraints substringToIndex:([constraints length] - 5)]];
	}
	
	return constraints;
}
								  
/**
 * Builds the string representation of the query's GROUP BY clause.
 *
 * @return The GROUP BY clause
 */
- (NSString *)_buildGroupByClause
{
	NSMutableString *groupBy = [NSMutableString string];
	
	if ([_groupByFields count] == 0) return groupBy;
	
	[groupBy appendString:@"GROUP BY "];
	
	for (NSString *field in _groupByFields)
	{
		[groupBy appendString:field];
		[groupBy appendString:@", "];
	}
	
	if ([groupBy hasSuffix:@", "]) {
		[groupBy setString:[groupBy substringToIndex:([groupBy length] - 2)]];
	}
	
	return groupBy;
}

/**
 * Builds the string representation of the query's ORDER BY clause.
 *
 * @return The ORDER BY clause
 */
- (NSString *)_buildOrderByClause
{
	NSMutableString *orderBy = [NSMutableString string];
	
	if ([_orderByFields count] == 0) return orderBy;
	
	[orderBy appendString:@"ORDER BY "];
	
	for (NSString *field in _orderByFields)
	{
		[orderBy appendString:field];
		[orderBy appendString:@", "];
	}
	
	if ([orderBy hasSuffix:@", "]) {
		[orderBy setString:[orderBy substringToIndex:([orderBy length] - 2)]];
	}
	
	[orderBy appendString:_orderDescending ? @" DESC" : @" ASC"];
	
	return orderBy;
}

/**
 * Builds the string representation of the query's UPDATE parameters.
 *
 * @return The fields to be updated
 */
- (NSString *)_buildUpdateClause
{
	NSMutableString *update = [NSMutableString string];
	
	if ([_updateParameters count] == 0) return update;
	
	[update appendString:@"SET "];
	
	for (QKQueryUpdateParameter *param in _updateParameters)
	{
		[update appendFormat:@"%@, ", param];
	}
	
	if ([update hasSuffix:@", "]) {
		[update setString:[update substringToIndex:([update length] - 2)]];
	}
	
	return update;
}

/**
 * Builds any SELECT specific query constraints, namely ORDER BY or GROUP BY clauses.
 *
 * @return The query clauses (if any).
 */
- (NSString *)_buildSelectOptions
{
	NSMutableString *string = [NSMutableString string];
	
	NSString *groupBy = [self _buildGroupByClause];
	NSString *orderBy = [self _buildOrderByClause];
	
	if ([groupBy length] > 0) {
		[string appendFormat:@" %@", groupBy];
	}
	
	if ([orderBy length] > 0) {
		[string appendFormat:@" %@", orderBy];
	}
	
	return string;
}

/**
 * Adds the supplied string to the supplied array, but only if the length is greater than zero.
 *
 * @param string The string to add to the array
 * @param array  The array to add the string to
 *
 * @return A BOOL indicating whether or not the string was added.
 */
- (BOOL)_addString:(NSString *)string toArray:(NSMutableArray *)array
{
	BOOL result = NO;
	
	if (!string || !array) return result;
	
	string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([string length] > 0) {
		[array addObject:string];
		
		result = YES;
	}
	
	return result;
}

#pragma mark -

/**
 * Same as calling -query.
 */
- (NSString *)description
{
	return [self query];
}

#pragma mark -

- (void)dealloc
{
	if (_table) [_table release], _table = nil;
	if (_database) [_database release], _database = nil;
	if (_query) [_query release], _query = nil;
	if (_parameters) [_parameters release], _parameters = nil;
	if (_fields) [_fields release], _fields = nil;
	if (_updateParameters) [_updateParameters release], _updateParameters = nil;
	if (_groupByFields) [_groupByFields release], _groupByFields = nil;
	if (_orderByFields) [_orderByFields release], _orderByFields = nil;
	
	[super dealloc];
}

@end
