//
//  $Id$
//
//  SPTextView.h
//  sequel-pro
//
//  Created by Carsten Blüm.
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

#import <Cocoa/Cocoa.h>

#import "NoodleLineNumberView.h"
#import "SPCopyTable.h"

#define SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING 10000

@class SPNarrowDownCompletion, SPDatabaseDocument, SPTablesList, SPCustomQuery, SPMySQLConnection;

@interface SPTextView : NSTextView
#ifdef SP_REFACTOR
<NSTextStorageDelegate>
#endif
{
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPCustomQuery *customQueryInstance;

	BOOL autoindentEnabled;
	BOOL autopairEnabled;
	BOOL autoindentIgnoresEnter;
	BOOL autouppercaseKeywordsEnabled;
	BOOL delBackwardsWasPressed;
#ifndef SP_REFACTOR
	BOOL autohelpEnabled;
#endif
	NoodleLineNumberView *lineNumberView;
	
	BOOL startListeningToBoundChanges;
	BOOL textBufferSizeIncreased;
	
#ifndef SP_REFACTOR
	NSString *showMySQLHelpFor;
#endif
	
	IBOutlet NSScrollView *scrollView;
	SPNarrowDownCompletion *completionPopup;
	
#ifndef SP_REFACTOR
	NSUserDefaults *prefs;
#endif

	SPMySQLConnection *mySQLConnection;
	NSInteger mySQLmajorVersion;

	NSInteger snippetControlArray[20][3];
	NSInteger snippetMirroredControlArray[20][3];
	NSInteger snippetControlCounter;
	NSInteger snippetControlMax;
	NSInteger currentSnippetIndex;
	NSInteger mirroredCounter;
	BOOL snippetWasJustInserted;
	BOOL isProcessingMirroredSnippets;

	BOOL completionIsOpen;
	BOOL completionWasReinvokedAutomatically;
	BOOL completionWasRefreshed;
	BOOL completionFuzzyMode;
	NSUInteger completionParseRangeLocation;

	NSColor *queryHiliteColor;
	NSColor *queryEditorBackgroundColor;
	NSColor *commentColor;
	NSColor *quoteColor;
	NSColor *keywordColor;
	NSColor *backtickColor;
	NSColor *numericColor;
	NSColor *variableColor;
	NSColor *otherTextColor;
	NSRange queryRange;
	BOOL shouldHiliteQuery;

}

@property(retain) NSColor* queryHiliteColor;
@property(retain) NSColor* queryEditorBackgroundColor;
@property(retain) NSColor* commentColor;
@property(retain) NSColor* quoteColor;
@property(retain) NSColor* keywordColor;
@property(retain) NSColor* backtickColor;
@property(retain) NSColor* numericColor;
@property(retain) NSColor* variableColor;
@property(retain) NSColor* otherTextColor;
@property(assign) NSRange queryRange;
@property(assign) BOOL shouldHiliteQuery;
@property(assign) BOOL completionIsOpen;
@property(assign) BOOL completionWasReinvokedAutomatically;

#ifdef SP_REFACTOR
@property (assign) SPDatabaseDocument *tableDocumentInstance;
@property (assign) SPTablesList *tablesListInstance;
@property (assign) SPCustomQuery *customQueryInstance;
@property (assign) SPMySQLConnection *mySQLConnection;
#endif

#ifndef SP_REFACTOR
- (IBAction)showMySQLHelpForCurrentWord:(id)sender;
#endif

- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue;
- (BOOL) areAdjacentCharsLinked;
- (BOOL) isCaretAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar;
- (BOOL) isCaretAtIndentPositionIgnoreLineStart:(BOOL)ignoreLineStart;
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix;
- (BOOL) shiftSelectionRight;
- (BOOL) shiftSelectionLeft;
- (void) setAutoindent:(BOOL)enableAutoindent;
- (BOOL) autoindent;
- (void) setAutoindentIgnoresEnter:(BOOL)enableAutoindentIgnoresEnter;
- (BOOL) autoindentIgnoresEnter;
- (void) setAutopair:(BOOL)enableAutopair;
- (BOOL) autopair;
- (void) setAutouppercaseKeywords:(BOOL)enableAutouppercaseKeywords;
- (BOOL) autouppercaseKeywords;
#ifndef SP_REFACTOR
- (void) setAutohelp:(BOOL)enableAutohelp;
- (BOOL) autohelp;
#endif
- (void) setTabStops;
- (void) selectLineNumber:(NSUInteger)lineNumber ignoreLeadingNewLines:(BOOL)ignLeadingNewLines;
- (NSUInteger) getLineNumberForCharacterIndex:(NSUInteger)anIndex;
#ifndef SP_REFACTOR
- (void) autoHelp;
#endif
- (void) doSyntaxHighlighting;
- (NSBezierPath*)roundedBezierPathAroundRange:(NSRange)aRange;
- (void) setConnection:(SPMySQLConnection *)theConnection withVersion:(NSInteger)majorVersion;
- (void) doCompletionByUsingSpellChecker:(BOOL)isDictMode fuzzyMode:(BOOL)fuzzySearch autoCompleteMode:(BOOL)autoCompleteMode;
- (void) doAutoCompletion;
- (void) refreshCompletion;
- (NSArray *)suggestionsForSQLCompletionWith:(NSString *)currentWord dictMode:(BOOL)isDictMode browseMode:(BOOL)dbBrowseMode withTableName:(NSString*)aTableName withDbName:(NSString*)aDbName;
- (void) selectCurrentQuery;
- (void) processMirroredSnippets;

- (BOOL)checkForCaretInsideSnippet;
- (void)insertAsSnippet:(NSString*)theSnippet atRange:(NSRange)targetRange;

- (void)showCompletionListFor:(NSString*)kind atRange:(NSRange)aRange fuzzySearch:(BOOL)fuzzySearchMode;

- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint;
- (void)insertFileContentOfFile:(NSString *)aPath;

- (BOOL)isSnippetMode;

- (void)boundsDidChangeNotification:(NSNotification *)notification;
- (void)dragAlertSheetDidEnd:(NSAlert *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end
