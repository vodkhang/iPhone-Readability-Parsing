//
//  NSReadability.m
//  Caffeinated
//
//  Created by Curtis Hard on 19/08/2011.
//  Copyright 2011 GeekyGoodness. All rights reserved.
//

#import "GGReadability.h"

// scorer just holds the element and the score
@implementation GGReadabilityScorer

@synthesize score, element;

- (void)dealloc
{}

@end

// private
@interface GGReadability (private)

// returns the handler for a given url, if specified
- (GGReadabilityURLHandler)URLHandlerForURL:(NSURL *)aURL;

// handles the error given by nsurlconnection
- (void)handleURLError;

// sets the contents
- (void)returnContents;

// uniques an array
- (NSArray *)uniqueArray:(NSArray *)array;

// cleans any attribtes of element
- (void)cleanAttributesForElement:(CXMLElement *)element;

// matches the element to the hint
- (BOOL)hintMatchesElement:(CXMLElement *)element;

// parses the string, if word count is specified it will try and find the biggest string value within all elements
- (void)parseTryUsingWordCount:(BOOL)flag
                     forString:(NSString *)str;

// runs all of the funky stuff to parse the elements
- (void)parseString:(NSString *)string
               type:(NSUInteger)type
       useWordCount:(BOOL)flag;

// fixes relative urls to absolute
- (void)fixRelativeURLForElement:(CXMLElement *)element
                       attribute:(NSString *)attribute;

// cleans up the given element
- (void)cleanElement:(CXMLElement *)element;

// removes styles from an element, and children is specified
- (void)removeStylesForElement:(CXMLElement *)element
                     recursive:(BOOL)flag;

// matches a string against another string
- (BOOL)matchString:(NSString *)input
            against:(NSString *)string;

// replaces elements with another
- (void)replaceElementsForXPath:(NSString *)path
                    withElement:(CXMLElement *)element
                     forElement:(CXMLElement *)parent;

// removes elements
- (void)removeElementsForXPath:(NSString *)path
                    forElement:(CXMLElement *)element;

// counts characters in a string against the char set
- (NSInteger)countForCharacterSet:(NSCharacterSet *)set
                       forElement:(CXMLElement *)element
                       multiplier:(NSInteger)multiplier;

// scores an element against its attributes
- (void)scoreElementAttributes:(NSArray *)atts
                    forElement:(CXMLElement *)element
                         score:(NSInteger *)count;

// counts child elements of the given element with a name
- (NSInteger)countForChildWithName:(NSString *)name
                        forElement:(CXMLElement *)element
                        multiplier:(NSInteger)multiplier;

// counts child elements of given element with xpath
- (NSInteger)countForChildWithXPath:(NSString *)path
                         forElement:(CXMLElement *)element
                         multiplier:(NSInteger)multiplier;

@end

@implementation GGReadability

// negative will be negativly scored if found
#define NEGATIVE @"comment|meta|footer|footnote|foot|follow|author|reset|password|thread|dialog|blurb"

// possitive will plus the score if found
#define POSSITIVE @"post|hentry|entry|content|text|body|article|story|blog"

// xml document types
//enum {
//	NSXMLDocumentXMLKind = 0,
//	NSXMLDocumentXHTMLKind,
//	NSXMLDocumentHTMLKind,
//	NSXMLDocumentTextKind
//};
//
//enum {
//    NSXMLNodeOptionsNone = 0,
//    
//    // Init
//    NSXMLNodeIsCDATA = 1UL << 0,
//    NSXMLNodeExpandEmptyElement = 1UL << 1, // <a></a>
//    NSXMLNodeCompactEmptyElement =  1UL << 2, // <a/>
//    NSXMLNodeUseSingleQuotes = 1UL << 3,
//    NSXMLNodeUseDoubleQuotes = 1UL << 4,
//    
//    // Tidy
//    NSXMLDocumentTidyHTML = 1UL << 9,
//    NSXMLDocumentTidyXML = 1UL << 10,
//    
//    // Validate
//    NSXMLDocumentValidate = 1UL << 13,
//    
//    // Parse
//    NSXMLDocumentXInclude = 1UL << 16,
//    
//    // Output
//    NSXMLNodePrettyPrint = 1UL << 17,
//    NSXMLDocumentIncludeContentTypeDeclaration = 1UL << 18,
//    
//    // Fidelity
//    NSXMLNodePreserveNamespaceOrder = 1UL << 20,
//    NSXMLNodePreserveAttributeOrder = 1UL << 21,
//    NSXMLNodePreserveEntities = 1UL << 22,
//    NSXMLNodePreservePrefixes = 1UL << 23,
//    NSXMLNodePreserveCDATA = 1UL << 24,
//    NSXMLNodePreserveWhitespace = 1UL << 25,
//    NSXMLNodePreserveDTD = 1UL << 26,
//    NSXMLNodePreserveCharacterReferences = 1UL << 27,    
//    NSXMLNodePreserveEmptyElements = 
//    (NSXMLNodeExpandEmptyElement | NSXMLNodeCompactEmptyElement),
//    NSXMLNodePreserveQuotes = 
//    (NSXMLNodeUseSingleQuotes | NSXMLNodeUseDoubleQuotes),	
//    NSXMLNodePreserveAll = (
//                            NSXMLNodePreserveNamespaceOrder | 
//                            NSXMLNodePreserveAttributeOrder | 
//                            NSXMLNodePreserveEntities | 
//                            NSXMLNodePreservePrefixes | 
//                            NSXMLNodePreserveCDATA | 
//                            NSXMLNodePreserveEmptyElements | 
//                            NSXMLNodePreserveQuotes | 
//                            NSXMLNodePreserveWhitespace |
//                            NSXMLNodePreserveDTD |
//                            NSXMLNodePreserveCharacterReferences |
//                            0xFFF00000) // high 12 bits
//};


#define DOC_FORMAT_XML CXMLDocumentTidyXML
#define DOC_FORMAT_HTML CXMLDocumentTidyHTML
#define DOC_FORMAT_XHTML CXMLDocumentTidyHTML
#define DOC_FORMAT_NONE 0

// url delimnator
#define URL_DELIMINATOR @"/"

// error domain
#define ERROR_DOMAIN [NSString stringWithFormat:@"com.geekygoodness.",[self class]]
#define ERROR_CODE 1

@synthesize URL, delegate, hint, useBlocks;
@synthesize isRendering, contents, loadProgress;

static NSMutableDictionary * handlers = nil;

- (void)dealloc
{
}

#pragma mark -
#pragma mark Interface
+ (void)addURLHandler:(GGReadabilityURLHandler)handler
               forURL:(NSURL *)aURL
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handlers = [[NSMutableDictionary alloc] init];
    });
    [handlers setObject:[handler copy]
                 forKey:[aURL host]];
}

+ (void)removeHandlerForURL:(NSURL *)aURL
{
    if( [[handlers allKeys] count] == 0 )
    {
        return;
    }
    if( [[handlers allKeys] containsObject:[aURL host]] )
    {
        [handlers removeObjectForKey:[aURL host]];
    }
}

- (id)initWithURL:(NSURL *)aURL
         delegate:(id<GGReadabilityDelegate>)anObject
{
    if( ( self = [super init] ) != nil )
    {
        [self setURL:aURL];
        [self setDelegate:anObject];
        [self setLoadProgress:0];
        responseData = [[NSMutableData alloc] init];
    }
    return self;
}

- (id)initWithURL:(NSURL *)aURL
completionHandler:(GGReadabilityCompletionHandler)cHandler
     errorHandler:(GGReadabilityErrorHandler)eHandler
{
    if( ( self = [self initWithURL:aURL
                          delegate:nil] ) != nil )
    {
        [self setUseBlocks:YES];
        completionBlock = [cHandler copy];
        errorBlock = [eHandler copy];
    }
    return self;
}

- (void)setHint:(NSString *)str
{
    if( [self hint] )
    {
    }
    hint = [str copy];
    
    NSArray *words = [hint componentsSeparatedByString:@" "];
    hintWords = [self uniqueArray:words];
}

- (NSArray *)uniqueArray:(NSArray *)array
{
    NSMutableArray * toAdd = [[NSMutableArray alloc] init];
    for( id object in array )
    {
        if( ! [toAdd containsObject:object] )
        {
            [toAdd addObject:object];
        }
    }
    return [toAdd copy];
}

- (void)render
{
    
    // if already rendering, just return
    
    if( [self isRendering] )
    {
        return;
    }
    [self setIsRendering:YES];
    
    // use old school url connection as we want a download progress bar
    
    [self setLoadProgress:0.1];
    
    connection = [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:[self URL]]
                                                                        delegate:self];
    [connection start];
}

- (void)stop
{
    if( connection )
    {
        [connection cancel];
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    if( [self useBlocks] )
    {
        errorBlock( error );
        return;
    }
    if( [[self delegate] respondsToSelector:@selector(readability:didReceiveError:)] )
    {
        [[self delegate] readability:self
                     didReceiveError:error];
    }
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
    
    // sets the percent progress, can bind to this    
    [responseData appendData:data];
    float prog = ( fabsf( ( (float)[responseData length] / (float)length ) ) / 100000 ) + 0.1;
    if( prog >= .85 )
    {
        prog = .85;
    }
    [self setLoadProgress:prog];
}

- (GGReadabilityURLHandler)URLHandlerForURL:(NSURL *)aURL
{
    NSString * base = [aURL host];
    if( [[handlers allKeys] containsObject:base] )
    {
        return [handlers objectForKey:base];
    }
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    dispatch_queue_t queue = dispatch_queue_create( "com.geekygoodness.ggreadability", NULL );
    dispatch_async( queue, ^(void){
            
        NSString * str = [[NSString alloc] initWithData:responseData
                                               encoding:NSUTF8StringEncoding];
        
        if( str == NULL || str == nil )
        {
            // try mac roman
            str = [[NSString alloc] initWithData:responseData
                                        encoding:NSMacOSRomanStringEncoding];
        }
        
        // is there a handler?
        
        GGReadabilityURLHandler handler = nil;
        if( ( handler = [self URLHandlerForURL:[response URL]] ) != nil )
        {
            // call the handler and set the contents

            NSError * error = nil;
            NSString * tempStr = [handler( str, &error ) copy];
            
            // if error, just use standard parsed string
            
            if( error != nil )
            {
//                [tempStr release];
            } else {
//                [str release], str = nil;
                str = tempStr;
            }
        }
        
        // due to the html might not be valid, we try just standard XML to begin with
        [self parseTryUsingWordCount:NO
                           forString:str];
        // if length is 0 or still null try using word count instead
        
        if( [self contents] == NULL || [[self contents] length] == 0 )
        {
            [self parseTryUsingWordCount:YES
                               forString:str];
        }
        // if nothing still, we tried our best, sorry!
        
//        [str release];
        dispatch_async( dispatch_get_main_queue(), ^(void){
            [self returnContents];
        });
    });
}

- (void)parseTryUsingWordCount:(BOOL)flag
                     forString:(NSString *)str
{
    
//    // first try standard xml
    if([self contents] == nil || [self contents] == NULL || [[self contents] length] == 0 )
    {
        
        // then if the xml is null we try standard html
        
        [self parseString:str
                     type:DOC_FORMAT_HTML
             useWordCount:flag];
        if([self contents] == nil || [self contents] == NULL || [[self contents] length] == 0 )
        {
            
            // and if the html is null we try xhtml
            
            [self parseString:str
                         type:DOC_FORMAT_XHTML
                 useWordCount:flag];
        }
    }
}

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)aResponse
{
//    response = [aResponse retain];
    length = [aResponse expectedContentLength];
}

- (void)handleURLError
{
    if( [[self delegate] respondsToSelector:@selector(readability:didReceiveError:)] )
    {
        NSError * error = [NSError errorWithDomain:ERROR_DOMAIN
                                              code:ERROR_CODE
                                          userInfo:nil];
        [[self delegate] readability:self
                     didReceiveError:error];
    }        
}

- (void)returnContents
{
    if( [self useBlocks] )
    {
        completionBlock( [self contents] );
        return;
    }
    if( [[self delegate] respondsToSelector:@selector(readability:didReceiveContents:)] )
    {
        [[self delegate] readability:self
                  didReceiveContents:[self contents]];
    }
}


#pragma mark -
#pragma mark Parse
- (void)parseString:(NSString *)string
               type:(NSUInteger)type
       useWordCount:(BOOL)flag
{
    
    @autoreleasepool {
        
        // first replace all line breaks with p tags so we have tags to work with when CMS's dont use ptags in there WYSIWYG editors
        NSArray * find = [NSArray arrayWithObjects:@"<br />",@"<br/>",@"<br>",nil];
        for( NSString * replace in find )
        {
            string =  [string stringByReplacingOccurrencesOfString:replace
                                                        withString:@"<p gg=\"rep\"></p>"];
        }
        
        // generate the tree, tidy it aswell!    
        
        if( ! string )
        {
            [self setContents:@""];
            [self setLoadProgress:0.0];
            return;
        }
        NSDictionary *mappingDictionary = [NSDictionary dictionaryWithObject:@"http://www.w3.org/1999/xhtml" forKey:@"xhtml"];

        NSError * error = nil;
        CXMLElement * DOM = [[[CXMLDocument alloc] initWithXMLString:string
                                 options:type error:&error] rootElement];
        if (!DOM) {
            [self setContents:nil];
            return;
        }
        
        DOM.shouldFreeXMLNode = YES;
        [self removeElementsForXPath:@"//xhtml:style"
                          forElement:DOM];    

        [self removeElementsForXPath:@"//xhtml:script"
                          forElement:DOM];    
        // found parent, will be used later

        GGReadabilityScorer * topParent = nil;
        
        // find all p tags
        
        NSArray * pElements = nil;

        if( ! flag )
        {
            pElements = [DOM nodesForXPath:@"xhtml:body//xhtml:p" namespaceMappings:mappingDictionary error:&error];
        } else {
            pElements = [DOM nodesForXPath:@"xhtml:body/*" namespaceMappings:mappingDictionary
                                     error:&error];
            
            NSMutableArray * tempNodeArray = [[NSMutableArray alloc] init];
            for( CXMLElement * els in pElements )
            {
                NSString * strValue = [els stringValue];
                // count the words
                NSArray *words = [strValue componentsSeparatedByString:@" "];
                NSInteger count = [words count];
                if( count > 40 )
                {
                    [tempNodeArray addObject:els];
                }
            }
            pElements = tempNodeArray;
        }
        
        
        // temp arrays to store elements in
        NSMutableArray * pTags = [[NSMutableArray alloc] init];
        NSMutableArray * tempTags = [[NSMutableArray alloc] init];
        
        for ( CXMLElement * p in pElements )
        {
            CXMLElement * parent = (CXMLElement *)[p parent];
            if( [tempTags containsObject:parent] )
            {
                continue;
            }
            
            // remove styles from p tag
            [self removeStylesForElement:(CXMLElement *)p
                               recursive:NO];
            
            [tempTags addObject:parent];
            
            // set up a scorer for the element
            
            GGReadabilityScorer * scorer = [[GGReadabilityScorer alloc] init];
            [scorer setScore:0];
            [scorer setElement:parent];
            
            // add it to the array
            
            [pTags addObject:scorer];
            
            // start scoring
            NSInteger curScore = [scorer score];
            
            // if provided a hint, mark up massivly
            if( [self hint] )
            {
                if( [self hintMatchesElement:parent] )
                {
                    curScore += 1500;
                }
            }
            
            // score it against class and id
            
            [self scoreElementAttributes:[NSArray arrayWithObjects:@"class",@"id",nil]
                              forElement:parent
                                   score:&curScore];
            
            if( [[parent stringValue] length] > 10 )
            {
                curScore += 10;
            }
            
            // article of section ?
            
            if( [[parent name] isEqualToString:@"article"] || [[parent name] isEqualToString:@"section"] )
            {
                // mark it up rather high
                curScore += 150;
            }
            
            // get all p tags inside and + 5 for each one
            
            curScore += [self countForChildWithName:@"p"
                                         forElement:parent
                                         multiplier:5];
            
            // get the word count for the whole element

            NSArray *words = [[parent stringValue] componentsSeparatedByString:@" "];
            curScore += ( 2 * [words count] );
            
            // mark it up if it has any headers
            curScore += [self countForChildWithXPath:@"//xhtml:h2" forElement:parent multiplier:10];
            curScore += [self countForChildWithXPath:@"//xhtml:h3" forElement:parent multiplier:10];
            curScore += [self countForChildWithXPath:@"//xhtml:h4" forElement:parent multiplier:10];
            
            // mark it up for any lists
            
            curScore += [self countForChildWithXPath:@"//xhtml:ul" forElement:parent multiplier:2];
            curScore += [self countForChildWithXPath:@"//xhtml:ol" forElement:parent multiplier:2];
            
            // mark it down for forms or inputs
            curScore -= [self countForChildWithXPath:@"//xhtml:form" forElement:parent multiplier:10];
            curScore -= [self countForChildWithXPath:@"//xhtml:input" forElement:parent multiplier:10];
            
            // score up for puncation
            
            curScore += [self countForCharacterSet:[NSCharacterSet punctuationCharacterSet]
                                        forElement:parent
                                        multiplier:2];
            
            // score up for any images used
            
            curScore += [self countForChildWithName:@"img"
                                         forElement:parent
                                         multiplier:1];
            
            // score up for images that are of reasonable viewing size
            
            curScore += [self countForChildWithXPath:@"//xhtml:img[@width>=200 or @height>=150]"
                                          forElement:parent
                                          multiplier:5];
            
            // score up for massive image
            
            curScore += [self countForChildWithXPath:@"//xhtml:img[@width>=390 and @height>=290]"
                                          forElement:parent
                                          multiplier:500];
            
            // increase by iframed content from youtube
            
            curScore += [self countForChildWithXPath:@"//xhtml:iframe[contains(@src,'youtube')]"
                                          forElement:parent
                                          multiplier:100];
            
            // increase by embed objects with reasonable viewing size
            
            curScore += [self countForChildWithXPath:@"//xhtml:embed[@width>=200 or height>=150]"
                                          forElement:parent
                                          multiplier:10];
            
            // set the score against the scorer
            
            [scorer setScore:curScore];
            
        }
        
        // sort by scrore highest
        
        [pTags sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"score"
                                                                                           ascending:FALSE]]];
        
        // if nothing found then set contents to nothing and drain the pool
        if( [pTags count] == 0 )
        {
            [self setLoadProgress:0.0];
            [self setContents:nil];
            return;
        }
        
        // set the found scorer
        topParent = [pTags objectAtIndex:0];

        // clean any classes and styles from the main parent
        
        [self removeStylesForElement:(CXMLElement *)[topParent element]
                           recursive:YES];
        
        // clean the element from unwanted elements
        
        [self cleanElement:[topParent element]];
        
        // generate
        [self setContents:[[topParent element] XMLString]];
        [self setLoadProgress:1.0];    
    }
}

- (void)cleanElement:(CXMLElement *)element
{
    
    // remove any empty p tags we have added
    
    [self replaceElementsForXPath:@"//xhtml:p[@gg='rep']"
                      withElement:[CXMLNode elementWithName:@"br"]
                       forElement:element];
    
    // remove added br's that are next to each other
    [self removeElementsForXPath:@"//xhtml:br[preceding-sibling::br[1]]" forElement:element];
    
    // remove any really small images
    [self removeElementsForXPath:@"//xhtml:img[@width<=50 or @height<=50]" forElement:element];
    // remove any forms
    [self removeElementsForXPath:@"//xhtml:input" forElement:element];
    [self removeElementsForXPath:@"//xhtml:form" forElement:element];

    
    // remove any h1
    [self removeElementsForXPath:@"//xhtml:h1"
                      forElement:element];
    
    // remove any dates
    [self removeElementsForXPath:@"//*[contains(@class,'date') or contains(@class,'calendar') or contains(@id,'date') or contains(@id,'calendar')]"
                      forElement:element];
    
    // remove any "wrapper"
    
    [self removeElementsForXPath:@"//*[contains(@class,'wrapper') or contains(@id,'wrapper')]"
                      forElement:element];
    
    // remove any authors
    [self removeElementsForXPath:@"//*[contains(@class,'author') or contains(@id,'author')]"
                      forElement:element];
    
    // remove info
    [self removeElementsForXPath:@"//*[contains(@class,'info') or contains(@id,'info')]"
                      forElement:element];
    
    // remove iframes
    [self removeElementsForXPath:@"//xhtml:iframe[not(contains(@src,'youtube'))]"
                      forElement:element];
    
    // remove any divs, but they may contain useful things, so lets check first
    
    NSError * error = nil;
    NSArray * divs = [element nodesForXPath:@"//div"
                                      error:&error];
    
    // if the div contains pre's, a's or code tags or p tags then dont remove them
    
    for( CXMLElement * div in divs )
    {
        NSInteger codeTags, pTags, preTags, aTags;
        codeTags = [self countForChildWithName:@"code"
                                    forElement:div
                                    multiplier:1];
        if( codeTags != 0 )
        {
            continue;
        }
        pTags = [self countForChildWithName:@"p"
                                 forElement:div
                                 multiplier:1];
        if( pTags != 0 )
        {
            continue;
        }
        aTags = [self countForChildWithName:@"a"
                                 forElement:div
                                 multiplier:1];
        if( aTags != 0 )
        {
            continue;
        }
        preTags = [self countForChildWithName:@"pre"
                                   forElement:div
                                   multiplier:1];
        if( preTags != 0 )
        {
            continue;
        }
        [element removeChild:div];
    }    
    
    // sort out image tags url's
    NSArray * images = [element nodesForXPath:@"//img[not(contains(@src,'http'))]"
                                        error:&error];
    for( CXMLElement * img in images ) 
    {
        [self fixRelativeURLForElement:img
                             attribute:@"src"];
    }
    
    // sort out link urls
    NSArray * links = [element nodesForXPath:@"//a[not(contains(@href,'http'))]"
                                       error:&error];
    for( CXMLElement * link in links )
    {
        [self fixRelativeURLForElement:link
                             attribute:@"href"];
    }
    
}

- (void)fixRelativeURLForElement:(CXMLElement *)element
                       attribute:(NSString *)attribute
{
    NSString * src = [[element attributeForName:attribute] stringValue];
    NSString * newSRC = nil;
    if( [src length] == 0 )
    {
        return;
    }
    if( [[src substringToIndex:1] isEqualToString:URL_DELIMINATOR] )
    {
        // prepend with host
        newSRC = [NSString stringWithFormat:@"%@:%@%@%@%@",[[response URL] scheme],URL_DELIMINATOR,URL_DELIMINATOR,[[response URL] host],src];
    } else {
        // prepend with the page your on
        NSString * appendURL = [[response URL] absoluteString];
        BOOL appendSlash = [[appendURL substringWithRange:NSMakeRange( [appendURL length] - 1, 1)] isEqualToString:URL_DELIMINATOR];
        newSRC = [NSString stringWithFormat:@"%@%@%@",[[response URL] absoluteString],( appendSlash ? URL_DELIMINATOR : @"" ),src];
    }
    [[element attributeForName:attribute] setStringValue:newSRC];
}

- (void)replaceElementsForXPath:(NSString *)path
                    withElement:(CXMLElement *)element
                     forElement:(CXMLElement *)parent
{
    NSDictionary *mappingDictionary = [NSDictionary dictionaryWithObject:@"http://www.w3.org/1999/xhtml" forKey:@"xhtml"];

    NSError * error = nil;
    NSArray * els = [parent nodesForXPath:path namespaceMappings:mappingDictionary error:&error];
    for( CXMLElement * el in els )
    {
        CXMLElement * clone = (CXMLElement *) [element copy];
        CXMLElement *parent = (CXMLElement *) [el parent];
        [parent replaceChild:element withNewChild:clone];
    }
}

- (void)removeElementsForXPath:(NSString *)path
                    forElement:(CXMLElement *)element
{
    NSError * error = nil;
    NSDictionary *mappingDictionary = [NSDictionary dictionaryWithObject:@"http://www.w3.org/1999/xhtml" forKey:@"xhtml"];
    NSArray * els = [element nodesForXPath:path namespaceMappings:mappingDictionary error:&error];
    if (error) {
    }

    for( CXMLElement * child in els )
    {
        [(CXMLElement *)[child parent] removeChild:child];
    }
}

- (NSInteger)countForCharacterSet:(NSCharacterSet *)set
                       forElement:(CXMLElement *)element
                       multiplier:(NSInteger)multiplier
{
    NSString * str = [element stringValue];
    if( [str length] == 0 )
    {
        return 0;
    }
    NSRange inputRange = NSMakeRange( 0, [str length] );
    NSInteger count = 0;
    while( YES )
    {
        NSRange range = [str rangeOfCharacterFromSet:set
                                             options:NSCaseInsensitiveSearch
                                               range:inputRange];
        if( range.location == NSNotFound )
        {
            break;
        } else {
            count++;
            NSInteger pos = ( range.location + range.length );
            inputRange = NSMakeRange( pos, [str length] - pos );
        }
    }
    return ( count * multiplier );
}

- (NSInteger)countForChildWithName:(NSString *)name
                        forElement:(CXMLElement *)element
                        multiplier:(NSInteger)multiplier
{
    return [self countForChildWithXPath:[NSString stringWithFormat:@"//xhtml:%@",name]
                             forElement:element
                             multiplier:multiplier];
}

- (NSInteger)countForChildWithXPath:(NSString *)path
                         forElement:(CXMLElement *)element
                         multiplier:(NSInteger)multiplier
{
    NSError * error = nil;
    NSDictionary *mappingDictionary = [NSDictionary dictionaryWithObject:@"http://www.w3.org/1999/xhtml" forKey:@"xhtml"];

    return ( [[element nodesForXPath:path namespaceMappings:mappingDictionary error:&error] count] * multiplier );
}

- (BOOL)matchString:(NSString *)input
            against:(NSString *)string
{
    NSArray * arr = [string componentsSeparatedByString:@"|"];
    for( NSString * find in arr )
    {
        if( [input rangeOfString:find
                         options:NSCaseInsensitiveSearch].location != NSNotFound )
        {
            return YES;
        }
    }
    return NO;
}

- (void)scoreElementAttributes:(NSArray *)atts
                    forElement:(CXMLElement *)element
                         score:(NSInteger *)count
{
    for( NSString * attName in atts )
    {
        CXMLNode * att = nil;
        if( ( att = [element attributeForName:attName] ) != nil )
        {
            if( [self matchString:[att stringValue]
                          against:NEGATIVE] )
            {
                count -= 50;
            }
            if( [self matchString:[att stringValue]
                          against:POSSITIVE] )
            {
                count += 25;
            }
        }
    }
}

- (void)cleanAttributesForElement:(CXMLElement *)element
{
    for( NSString * attName in [NSArray arrayWithObjects:@"class",@"id",@"style",@"rel",nil] )
    {
        [element removeAttributeForName:attName];
    }
}

- (void)removeStylesForElement:(CXMLElement *)element
                     recursive:(BOOL)flag
{
    // remove any attributes, just as easy
    [self cleanAttributesForElement:element];
    // if recursive, remove children styles aswell
    if( flag )
    {
        NSError * error = nil;
        for( CXMLElement * child in [element nodesForXPath:@"//*"
                                                      error:&error] )
        {
            [self cleanAttributesForElement:child];
        }
    }
}

- (BOOL)hintMatchesElement:(CXMLElement *)element
{
    NSString *elementValue = [element stringValue];
    NSArray *words = [elementValue componentsSeparatedByString:@" "];
    words = [self uniqueArray:words];

    NSInteger score = 0;
    NSInteger range = ceil( [hintWords count] / 3 );
    for( NSString * word in words )
    {
        if( [hintWords containsObject:word] )
        {
            score++;
            if( score >= range )
            {
                return YES;
            }
        }
    }
    return NO;
}

@end
