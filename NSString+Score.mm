//
//  NSString+Score.m
//
//  Created by Nicholas Bruning on 5/12/11.
//  Copyright (c) 2011 Involved Pty Ltd. All rights reserved.
//

//score reference: http://jsfiddle.net/JrLVD/

@interface RFFuzzySearchObject : NSObject

@property (nonatomic, assign) CGFloat charScore;
@property (nonatomic, assign) NSUInteger position;


@end

@implementation RFFuzzySearchObject


@end

#import "NSString+Score.h"

static NSCharacterSet *s_separatorsCharacterSet = nil;

@implementation NSString (Score)

- (CGFloat) scoreAgainst:(NSString *)otherString{
    return [self scoreAgainst:otherString fuzziness:nil];
}

- (CGFloat) scoreAgainst:(NSString *)otherString fuzziness:(NSNumber *)fuzziness{
    return [self scoreAgainst:otherString fuzziness:fuzziness options:NSStringScoreOptionNone];
}

- (CGFloat) scoreAgainst:(NSString *)anotherString fuzziness:(NSNumber *)fuzziness options:(NSStringScoreOption)options{

	if (s_separatorsCharacterSet == nil) {
		NSMutableCharacterSet *separatorsCharacterSet = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
		[separatorsCharacterSet formUnionWithCharacterSet:[NSMutableCharacterSet punctuationCharacterSet]];
		s_separatorsCharacterSet = separatorsCharacterSet;
	}

	
    NSString *string = [self decomposedStringWithCanonicalMapping];
    NSString *otherString = [anotherString decomposedStringWithCanonicalMapping];

    // If the string is equal to the abbreviation, perfect match.
    if([string isEqualToString:otherString]) return (CGFloat) 1.0f;
	
    //if it's not a perfect match and is empty return 0
    if([otherString length] == 0) return (CGFloat) 0.0f;
	
	CGFloat totalCharacterScore = 0;
	NSUInteger otherStringLength = [otherString length];
	NSUInteger stringLength = [string length];
	BOOL startOfStringBonus = NO;
	CGFloat otherStringScore;
	CGFloat fuzzies = 1;
	CGFloat finalScore;
	
	// Walk through abbreviation and add up scores.
	for(uint index = 0; index < otherStringLength; index++){
		CGFloat characterScore = 0.1;
		NSInteger indexInString = NSNotFound;
		unichar chr = [otherString characterAtIndex:index];
		NSRange rangeChrLowercase = [string rangeOfString:[[otherString substringWithRange:NSMakeRange(index, 1)] lowercaseString]];
		NSRange rangeChrUppercase = [string rangeOfString:[[otherString substringWithRange:NSMakeRange(index, 1)] uppercaseString]];
		
		if(rangeChrLowercase.location == NSNotFound && rangeChrUppercase.location == NSNotFound){
			if(fuzziness){
				fuzzies += 1 - [fuzziness floatValue];
			} else {
				return 0; // this is an error!
			}
		} else if (rangeChrLowercase.location != NSNotFound && rangeChrUppercase.location != NSNotFound){
			indexInString = MIN(rangeChrLowercase.location, rangeChrUppercase.location);
		} else if(rangeChrLowercase.location != NSNotFound || rangeChrUppercase.location != NSNotFound){
			indexInString = rangeChrLowercase.location != NSNotFound ? rangeChrLowercase.location : rangeChrUppercase.location;
		} else {
			indexInString = MIN(rangeChrLowercase.location, rangeChrUppercase.location);
		}
		
		// Set base score for matching chr
		
		// Same case bonus.
		if(indexInString != NSNotFound && [string characterAtIndex:indexInString] == chr){
			characterScore += 0.1;
		}
		
		// Consecutive letter & start-of-string bonus
		if(indexInString == 0){
			// Increase the score when matching first character of the remainder of the string
			characterScore += 0.6;
			if(index == 0){
				// If match is the first character of the string
				// & the first character of abbreviation, add a
				// start-of-string match bonus.
				startOfStringBonus = YES;
			}
		} else if(indexInString != NSNotFound) {
			// Acronym Bonus
			// Weighing Logic: Typing the first character of an acronym is as if you
			// preceded it with two perfect character matches.
			if ([s_separatorsCharacterSet characterIsMember:[string characterAtIndex:indexInString - 1]]) {
				characterScore += 0.8;
			}
		}
		
		// Left trim the already matched part of the string
		// (forces sequential matching).
		if(indexInString != NSNotFound){
			string = [string substringFromIndex:indexInString + 1];
		}
		
		totalCharacterScore += characterScore;
	}
	
	if(NSStringScoreOptionFavorSmallerWords == (options & NSStringScoreOptionFavorSmallerWords)){
		// Weigh smaller words higher
		return totalCharacterScore / stringLength;
	}
	
	otherStringScore = totalCharacterScore / otherStringLength;
	
	if(NSStringScoreOptionReducedLongStringPenalty == (options & NSStringScoreOptionReducedLongStringPenalty)){
		// Reduce the penalty for longer words
		CGFloat percentageOfMatchedString = otherStringLength / stringLength;
		CGFloat wordScore = otherStringScore * percentageOfMatchedString;
		finalScore = (wordScore + otherStringScore) / 2;
		
	} else {
		finalScore = ((otherStringScore * ((CGFloat)(otherStringLength) / (CGFloat)(stringLength))) + otherStringScore) / 2;
	}
	
	finalScore = finalScore / fuzzies;
	
	if(startOfStringBonus && finalScore + 0.15 < 1){
		finalScore += 0.15;
	}
	
	return finalScore;
}


// ported from https://github.com/zalexej/StringScore_Swift.git
- (CGFloat) scoreWithString:(NSString *)otherString fuzziness:(NSNumber *)fuzziness positionArray:(NSArray<NSNumber*>**)positionsArray
{
	// If the string is equal to the word, perfect match.
	if ([self isEqualToString:otherString]) {
		return 1;
	}
	
	//if it's not a perfect match and is empty return 0
	if (otherString.length == 0 || self.length == 0) {
		return 0;
	}
	
	if (s_separatorsCharacterSet == nil) {
		NSMutableCharacterSet *separatorsCharacterSet = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
		[separatorsCharacterSet formUnionWithCharacterSet:[NSMutableCharacterSet punctuationCharacterSet]];
		s_separatorsCharacterSet = separatorsCharacterSet;
	}
	
	CGFloat runningScore(0), charScore (0), finalScore(0);
	
	NSString *string = self;
	NSString *lString = [string lowercaseString];
	NSUInteger strLength = string.length;
	
	NSString *lWord = [otherString lowercaseString];
	NSUInteger wordLength = otherString.length;

	NSUInteger idxOf(NSNotFound);
	
	CGFloat fuzzies(1), fuzzyFactor(0);
	
	// Cache fuzzyFactor for speed increase
	if (fuzziness) {
		fuzzyFactor = 1 - [fuzziness doubleValue];
	}
	
	NSMutableArray <NSArray<RFFuzzySearchObject*>*>* searchResults = [NSMutableArray new];
	
	for (NSUInteger i = 0; i < wordLength; i++) {
		NSMutableArray <RFFuzzySearchObject*>* searchObjects = [NSMutableArray new];
		
		NSString* searchAlpha = [lWord substringWithRange:NSMakeRange(i, 1)];
		
		NSRange searchRange = NSMakeRange(0,string.length);
		NSRange foundRange;
		while (searchRange.location < string.length) {
			searchRange.length = string.length - searchRange.location;
			foundRange = [lString rangeOfString:searchAlpha options:NSCaseInsensitiveSearch range:searchRange];
			if (foundRange.location != NSNotFound) {
				// found an occurrence of the substring! do stuff here
				searchRange.location = foundRange.location + 1;
				RFFuzzySearchObject *searchObject = [RFFuzzySearchObject new];
				searchObject.position = foundRange.location;
				[searchObjects addObject:searchObject];
					// start index of word's i-th character in string.
				
				
				idxOf = foundRange.location;

				charScore = 0.1;
				
				// Acronym Bonus
				// Weighing Logic: Typing the first character of an acronym is as if you
				// preceded it with two perfect character matches.
				if (idxOf == 0 || [s_separatorsCharacterSet characterIsMember:[string characterAtIndex:idxOf - 1]]) {
					charScore += 0.8;
				}
				
				// Same case bonus.
				if ([string characterAtIndex:idxOf] == [otherString characterAtIndex:i]) {
					charScore += 0.1;
				}
				
				searchObject.charScore = charScore;
				
			} else {
				if(searchObjects.count == 0){
					// Character not found
					fuzzies += fuzzyFactor;
				}
				break;
			}
		}
		
		if(searchObjects.count){
			[searchResults addObject:searchObjects];
		}
	}
	
	NSArray<NSNumber*> *scorePositionsArray = [NSArray new];
	
	//calculate score
	if(searchResults.count){
		runningScore = 0;
		NSArray <RFFuzzySearchObject*>* topSearchObjects = searchResults[0];
		NSUInteger startAt;
		NSArray <RFFuzzySearchObject*>* searchObjects;
		CGFloat result;
		for(int i = 0; i < topSearchObjects.count;i++){
			NSMutableArray<NSNumber*> *localScorePositionsArray = [NSMutableArray new];
			RFFuzzySearchObject* topSearchObject = topSearchObjects[i];
			startAt = topSearchObject.position + 1;
			result = topSearchObject.charScore;
			if (startAt == topSearchObject.position) {
				result += 0.7;
			}
			[localScorePositionsArray addObject:@(topSearchObject.position)];
			for(int j = 1; j < searchResults.count; j++){
				searchObjects = searchResults[j];
				for(int k = 0; k < searchObjects.count; k++){
					RFFuzzySearchObject* searchObject = searchObjects[k];
					if(searchObject.position >= startAt){
						result += searchObject.charScore;
						if (startAt == searchObject.position) {
							result += 0.7;
						}
						startAt = searchObject.position + 1;
						[localScorePositionsArray addObject:@(searchObject.position)];
						break;
					}
				}
			}
			if(runningScore < result){
				scorePositionsArray = localScorePositionsArray;
				runningScore = result;
			}
		}
	}
	
	(*positionsArray) = scorePositionsArray;
	
	// Reduce penalty for longer strings.
	finalScore = 0.5 * (runningScore / strLength + runningScore / wordLength) / fuzzies;
	
	if (([lWord characterAtIndex:0] == [lString characterAtIndex:0]) && (finalScore < 0.85)) {
		finalScore += 0.15;
	}
	
	return finalScore;
}

@end
