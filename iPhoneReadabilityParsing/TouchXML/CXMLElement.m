//
//  CXMLElement.m
//  TouchCode
//
//  Created by Jonathan Wight on 03/07/08.
//  Copyright 2011 toxicsoftware.com. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//     1. Redistributions of source code must retain the above copyright notice, this list of
//        conditions and the following disclaimer.
//
//     2. Redistributions in binary form must reproduce the above copyright notice, this list
//        of conditions and the following disclaimer in the documentation and/or other materials
//        provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY TOXICSOFTWARE.COM ``AS IS'' AND ANY EXPRESS OR IMPLIED
//  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL TOXICSOFTWARE.COM OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The views and conclusions contained in the software and documentation are those of the
//  authors and should not be interpreted as representing official policies, either expressed
//  or implied, of toxicsoftware.com.

#import "CXMLElement.h"

#import "CXMLNode_PrivateExtensions.h"
#import "CXMLNode_CreationExtensions.h"
#import "CXMLNamespaceNode.h"

@implementation CXMLElement

- (NSArray *)elementsForName:(NSString *)name
    {
    NSMutableArray *theElements = [NSMutableArray array];

    // TODO -- native xml api?
    const xmlChar *theName = (const xmlChar *)[name UTF8String];

    xmlNodePtr theCurrentNode = _node->children;
    while (theCurrentNode != NULL)
        {
        if (theCurrentNode->type == XML_ELEMENT_NODE && xmlStrcmp(theName, theCurrentNode->name) == 0)
            {
            CXMLNode *theNode = [CXMLNode nodeWithLibXMLNode:(xmlNodePtr)theCurrentNode freeOnDealloc:NO];
            [theElements addObject:theNode];
            }
        theCurrentNode = theCurrentNode->next;
        }
    return(theElements);
    }

- (NSArray *)elementsForLocalName:(NSString *)localName URI:(NSString *)URI
    {
	if (URI == nil || [URI length] == 0)
        {
		return [self elementsForName:localName];
        }
	
	NSMutableArray *theElements = [NSMutableArray array];
	const xmlChar *theLocalName = (const xmlChar *)[localName UTF8String];
	const xmlChar *theNamespaceName = (const xmlChar *)[URI UTF8String];
	
	xmlNodePtr theCurrentNode = _node->children;
	while (theCurrentNode != NULL)
        {
		if (theCurrentNode->type == XML_ELEMENT_NODE 
			&& xmlStrcmp(theLocalName, theCurrentNode->name) == 0
			&& theCurrentNode->ns
			&& xmlStrcmp(theNamespaceName, theCurrentNode->ns->href) == 0)
            {
			CXMLNode *theNode = [CXMLNode nodeWithLibXMLNode:(xmlNodePtr)theCurrentNode freeOnDealloc:NO];
			[theElements addObject:theNode];
            }
		theCurrentNode = theCurrentNode->next;
        }	
	
	return theElements;
    }

- (NSArray *)attributes
    {
    NSMutableArray *theAttributes = [NSMutableArray array];
    xmlAttrPtr theCurrentNode = _node->properties;
    while (theCurrentNode != NULL)
        {
        CXMLNode *theAttribute = [CXMLNode nodeWithLibXMLNode:(xmlNodePtr)theCurrentNode freeOnDealloc:NO];
        [theAttributes addObject:theAttribute];
        theCurrentNode = theCurrentNode->next;
        }
    return(theAttributes);
    }

- (CXMLNode *)attributeForName:(NSString *)name
    {
	// TODO -- look for native libxml2 function for finding a named attribute (like xmlGetProp)
	
	NSRange split = [name rangeOfString:@":"];
	
	xmlChar *theLocalName = NULL;
	xmlChar *thePrefix = NULL;
	
	if (split.length > 0)
        {
		theLocalName = (xmlChar *)[[name substringFromIndex:split.location + 1] UTF8String];
		thePrefix = (xmlChar *)[[name substringToIndex:split.location] UTF8String];
        } 
	else 
        {
		theLocalName = (xmlChar *)[name UTF8String];
        }
	
	xmlAttrPtr theCurrentNode = _node->properties;
	while (theCurrentNode != NULL)
        {
		if (xmlStrcmp(theLocalName, theCurrentNode->name) == 0)
            {
			if (thePrefix == NULL || (theCurrentNode->ns 
                && theCurrentNode->ns->prefix 
                && xmlStrcmp(thePrefix, theCurrentNode->ns->prefix) == 0))
                {
				CXMLNode *theAttribute = [CXMLNode nodeWithLibXMLNode:(xmlNodePtr)theCurrentNode freeOnDealloc:NO];
				return(theAttribute);
                }
            }
		theCurrentNode = theCurrentNode->next;
        }
	return(NULL);
    }

- (CXMLNode *)attributeForLocalName:(NSString *)localName URI:(NSString *)URI
    {
	if (URI == nil)
        {
		return [self attributeForName:localName];
        }
	
	// TODO -- look for native libxml2 function for finding a named attribute (like xmlGetProp)
	const xmlChar *theLocalName = (const xmlChar *)[localName UTF8String];
	const xmlChar *theNamespaceName = (const xmlChar *)[URI UTF8String];
	
	xmlAttrPtr theCurrentNode = _node->properties;
	while (theCurrentNode != NULL)
        {
		if (theCurrentNode->ns && theCurrentNode->ns->href &&
			xmlStrcmp(theLocalName, theCurrentNode->name) == 0 &&
			xmlStrcmp(theNamespaceName, theCurrentNode->ns->href) == 0)
            {
			CXMLNode *theAttribute = [CXMLNode nodeWithLibXMLNode:(xmlNodePtr)theCurrentNode freeOnDealloc:NO];
			return(theAttribute);
            }
		theCurrentNode = theCurrentNode->next;
        }
	return(NULL);
    }

- (NSArray *)namespaces
    {
	NSMutableArray *theNamespaces = [[[NSMutableArray alloc] init] autorelease];
	xmlNsPtr theCurrentNamespace = _node->nsDef;
	
	while (theCurrentNamespace != NULL)
        {
		NSString *thePrefix = theCurrentNamespace->prefix ? [NSString stringWithUTF8String:(const char *)theCurrentNamespace->prefix] : @"";
		NSString *theURI = [NSString stringWithUTF8String:(const char *)theCurrentNamespace->href];
		CXMLNamespaceNode *theNode = [[CXMLNamespaceNode alloc] initWithPrefix:thePrefix URI:theURI parentElement:self];
		[theNamespaces addObject:theNode];
		[theNode release];		
		
		theCurrentNamespace = theCurrentNamespace->next;
        }
	
	return theNamespaces;
    }

- (CXMLNode *)namespaceForPrefix:(NSString *)name
    {
	const xmlChar *thePrefix = (const xmlChar *)[name UTF8String];
	xmlNsPtr theCurrentNamespace = _node->nsDef;
	
	while (theCurrentNamespace != NULL)
        {
		if (xmlStrcmp(theCurrentNamespace->prefix, thePrefix) == 0)
            {
			NSString *thePrefixString = theCurrentNamespace->prefix ? [NSString stringWithUTF8String:(const char *)theCurrentNamespace->prefix] : @"";
			NSString *theURI = [NSString stringWithUTF8String:(const char *)theCurrentNamespace->href];
			return [[[CXMLNamespaceNode alloc] initWithPrefix:thePrefixString URI:theURI parentElement:self] autorelease];
            }			
		theCurrentNamespace = theCurrentNamespace->next;
        }
	return nil;
    }

- (CXMLNode *)resolveNamespaceForName:(NSString *)name
{
	NSRange split = [name rangeOfString:@":"];
	
	if (split.length > 0)
		return [self namespaceForPrefix:[name substringToIndex:split.location]];
	
	xmlNsPtr theCurrentNamespace = _node->nsDef;
	
	while (theCurrentNamespace != NULL)
	{
		if (theCurrentNamespace->prefix == 0 
			|| (theCurrentNamespace->prefix)[0] == 0)
		{
			NSString *thePrefix = theCurrentNamespace->prefix ? [NSString stringWithUTF8String:(const char *)theCurrentNamespace->prefix] : @"";
			NSString *theURI = [NSString stringWithUTF8String:(const char *)theCurrentNamespace->href];
			return [[[CXMLNamespaceNode alloc] initWithPrefix:thePrefix URI:theURI parentElement:self] autorelease];
		}			
		theCurrentNamespace = theCurrentNamespace->next;
	}
	
	return nil;
}

- (NSString *)resolvePrefixForNamespaceURI:(NSString *)namespaceURI
{
	const xmlChar *theXMLURI = (const xmlChar *)[namespaceURI UTF8String];
	
	xmlNsPtr theCurrentNamespace = _node->nsDef;
	
	while (theCurrentNamespace != NULL)
	{
		if (xmlStrcmp(theCurrentNamespace->href, theXMLURI) == 0)
		{
			if(theCurrentNamespace->prefix) 
				return [NSString stringWithUTF8String:(const char *)theCurrentNamespace->prefix];
			
			return @"";
		}			
		theCurrentNamespace = theCurrentNamespace->next;
	}
	return nil;
}

//- (NSString*)_XMLStringWithOptions:(NSUInteger)options appendingToString:(NSMutableString*)str
//{
//NSString* name = [self name];
//[str appendString:[NSString stringWithFormat:@"<%@", name]];
//
//for (id attribute in [self attributes] )
//	{
//	[attribute _XMLStringWithOptions:options appendingToString:str];
//	}
//
//if ( ! _node->children )
//	{
//	bool isEmpty = NO;
//	NSArray *emptyTags = [NSArray arrayWithObjects: @"br", @"area", @"link", @"img", @"param", @"hr", @"input", @"col", @"base", @"meta", nil ];
//	for (id s in emptyTags)
//		{
//		if ( [s isEqualToString:@"base"] )
//			{
//			isEmpty = YES;
//			break;
//			}
//		}
//	if ( isEmpty )
//		{
//		[str appendString:@"/>"];
//		return str;
//		}
//	}
//
//[str appendString:@">"];
//	
//if ( _node->children )
//	{
//	for (id child in [self children])
//		[child _XMLStringWithOptions:options appendingToString:str];
//	}
//[str appendString:[NSString stringWithFormat:@"</%@>", name]];
//return str;
//}

- (NSString *)description
{
	NSAssert(_node != NULL, @"TODO");
	
	return([NSString stringWithFormat:@"<%@ %p [%p] %@ %@>", NSStringFromClass([self class]), self, self->_node, [self name], [self XMLStringWithOptions:0]]);
}


#pragma mark -
#pragma mark vodkhang



#pragma mark Namespace fixup routines

+ (void)deleteNamespacePtr:(xmlNsPtr)namespaceToDelete
               fromXMLNode:(xmlNodePtr)node {
    
    // utilty routine to remove a namespace pointer from an element's
    // namespace definition list.  This is just removing the nsPtr
    // from the singly-linked list, the node's namespace definitions.
    xmlNsPtr currNS = node->nsDef;
    xmlNsPtr prevNS = NULL;
    
    while (currNS != NULL) {
        xmlNsPtr nextNS = currNS->next;
        
        if (namespaceToDelete == currNS) {
            
            // found it; delete it from the head of the node's ns definition list
            // or from the next field of the previous namespace
            
            if (prevNS != NULL) prevNS->next = nextNS;
            else node->nsDef = nextNS;
            
            xmlFreeNs(currNS);
            return;
        }
        prevNS = currNS;
        currNS = nextNS;
    }
}

static xmlChar *SplitQNameReverse(const xmlChar *qname, xmlChar **prefix) {
    
    // search backwards for a colon
    int qnameLen = xmlStrlen(qname);
    for (int idx = qnameLen - 1; idx >= 0; idx--) {
        
        if (qname[idx] == ':') {
            
            // found the prefix; copy the prefix, if requested
            if (prefix != NULL) {
                if (idx > 0) {
                    *prefix = xmlStrsub(qname, 0, idx);
                } else {
                    *prefix = NULL;
                }
            }
            
            if (idx < qnameLen - 1) {
                // return a copy of the local name
                xmlChar *localName = xmlStrsub(qname, idx + 1, qnameLen - idx - 1);
                return localName;
            } else {
                return NULL;
            }
        }
    }
    
    // no colon found, so the qualified name is the local name
    xmlChar *qnameCopy = xmlStrdup(qname);
    return qnameCopy;
}


+ (void)fixQualifiedNamesForNode:(xmlNodePtr)nodeToFix
              graftingToTreeNode:(xmlNodePtr)graftPointNode {
    
    // Replace prefix-in-name with proper namespace pointers
    //
    // This is an inner routine for fixUpNamespacesForNode:
    //
    // see if this node's name lacks a namespace and is qualified, and if so,
    // see if we can resolve the prefix against the parent
    //
    // The prefix may either be normal, "gd:foo", or a URI
    // "{http://blah.com/}:foo"
    
    if (nodeToFix->ns == NULL) {
        xmlNsPtr foundNS = NULL;
        
        xmlChar* prefix = NULL;
        xmlChar* localName = SplitQNameReverse(nodeToFix->name, &prefix);
        if (localName != NULL) {
            if (prefix != NULL) {
                
                // if the prefix is wrapped by { and } then it's a URI
                int prefixLen = xmlStrlen(prefix);
                if (prefixLen > 2
                    && prefix[0] == '{'
                    && prefix[prefixLen - 1] == '}') {
                    
                    // search for the namespace by URI
                    xmlChar* uri = xmlStrsub(prefix, 1, prefixLen - 2);
                    
                    if (uri != NULL) {
                        foundNS = xmlSearchNsByHref(graftPointNode->doc, graftPointNode, uri);
                        
                        xmlFree(uri);
                    }
                }
            }
            
            if (foundNS == NULL) {
                // search for the namespace by prefix, even if the prefix is nil
                // (nil prefix means to search for the default namespace)
                foundNS = xmlSearchNs(graftPointNode->doc, graftPointNode, prefix);
            }
            
            if (foundNS != NULL) {
                // we found a namespace, so fix the ns pointer and the local name
                xmlSetNs(nodeToFix, foundNS);
                xmlNodeSetName(nodeToFix, localName);
            }
            
            if (prefix != NULL) {
                xmlFree(prefix);
                prefix = NULL;
            }
            
            xmlFree(localName);
        }
    }
}

+ (void)fixDuplicateNamespacesForNode:(xmlNodePtr)nodeToFix
                   graftingToTreeNode:(xmlNodePtr)graftPointNode
             namespaceSubstitutionMap:(NSMutableDictionary *)nsMap {
    
    // Duplicate namespace removal
    //
    // This is an inner routine for fixUpNamespacesForNode:
    //
    // If any of this node's namespaces are already defined at the graft point
    // level, add that namespace to the map of namespace substitutions
    // so it will be replaced in the children below the nodeToFix, and
    // delete the namespace record
    
    if (nodeToFix->type == XML_ELEMENT_NODE) {
        
        // step through the namespaces defined on this node
        xmlNsPtr definedNS = nodeToFix->nsDef;
        while (definedNS != NULL) {
            
            // see if this namespace is already defined higher in the tree,
            // with both the same URI and the same prefix; if so, add a mapping for
            // it
            xmlNsPtr foundNS = xmlSearchNsByHref(graftPointNode->doc, graftPointNode,
                                                 definedNS->href);
            if (foundNS != NULL
                && foundNS != definedNS
                && xmlStrEqual(definedNS->prefix, foundNS->prefix)) {
                
                // store a mapping from this defined nsPtr to the one found higher
                // in the tree
                [nsMap setObject:[NSValue valueWithPointer:foundNS]
                          forKey:[NSValue valueWithPointer:definedNS]];
                
                // remove this namespace from the ns definition list of this node;
                // all child elements and attributes referencing this namespace
                // now have a dangling pointer and must be updated (that is done later
                // in this method)
                //
                // before we delete this namespace, move our pointer to the
                // next one
                xmlNsPtr nsToDelete = definedNS;
                definedNS = definedNS->next;
                
                [self deleteNamespacePtr:nsToDelete fromXMLNode:nodeToFix];
                
            } else {
                // this namespace wasn't a duplicate; move to the next
                definedNS = definedNS->next;
            }
        }
    }
    
    // if this node's namespace is one we deleted, update it to point
    // to someplace better
    if (nodeToFix->ns != NULL) {
        
        NSValue *currNS = [NSValue valueWithPointer:nodeToFix->ns];
        NSValue *replacementNS = [nsMap objectForKey:currNS];
        
        if (replacementNS != nil) {
            xmlNsPtr replaceNSPtr = (xmlNsPtr)[replacementNS pointerValue];
            
            xmlSetNs(nodeToFix, replaceNSPtr);
        }
    }
}



+ (void)fixUpNamespacesForNode:(xmlNodePtr)nodeToFix
            graftingToTreeNode:(xmlNodePtr)graftPointNode
      namespaceSubstitutionMap:(NSMutableDictionary *)nsMap {
    
    // This is the inner routine for fixUpNamespacesForNode:graftingToTreeNode:
    //
    // This routine fixes two issues:
    //
    // Because we can create nodes with qualified names before adding
    // them to the tree that declares the namespace for the prefix,
    // we need to set the node namespaces after adding them to the tree.
    //
    // Because libxml adds namespaces to nodes when it copies them,
    // we want to remove redundant namespaces after adding them to
    // a tree.
    //
    // If only the Mac's libxml had xmlDOMWrapReconcileNamespaces, it could do
    // namespace cleanup for us
    
    // We only care about fixing names of elements and attributes
    if (nodeToFix->type != XML_ELEMENT_NODE
        && nodeToFix->type != XML_ATTRIBUTE_NODE) return;
    
    // Do the fixes
    [self fixQualifiedNamesForNode:nodeToFix
                graftingToTreeNode:graftPointNode];
    
    [self fixDuplicateNamespacesForNode:nodeToFix
                     graftingToTreeNode:graftPointNode
               namespaceSubstitutionMap:nsMap];
    
    if (nodeToFix->type == XML_ELEMENT_NODE) {
        
        // when fixing element nodes, recurse for each child element and
        // for each attribute
        xmlNodePtr currChild = nodeToFix->children;
        while (currChild != NULL) {
            [self fixUpNamespacesForNode:currChild
                      graftingToTreeNode:graftPointNode
                namespaceSubstitutionMap:nsMap];
            currChild = currChild->next;
        }
        
        xmlAttrPtr currProp = nodeToFix->properties;
        while (currProp != NULL) {
            [self fixUpNamespacesForNode:(xmlNodePtr)currProp
                      graftingToTreeNode:graftPointNode
                namespaceSubstitutionMap:nsMap];
            currProp = currProp->next;
        }
    }
}

+ (void)fixUpNamespacesForNode:(xmlNodePtr)nodeToFix
            graftingToTreeNode:(xmlNodePtr)graftPointNode {
    
    // allocate the namespace map that will be passed
    // down on recursive calls
    NSMutableDictionary *nsMap = [NSMutableDictionary dictionary];
    
    [self fixUpNamespacesForNode:nodeToFix
              graftingToTreeNode:graftPointNode
        namespaceSubstitutionMap:nsMap];
}


- (void)addAttribute:(CXMLNode *)attribute {
    
    if (_node != NULL) {
                
        xmlAttrPtr attrPtr = (xmlAttrPtr) [attribute XMLNode];
        if (attrPtr) {
            
            // ignore this if an attribute with the name is already present,
            // similar to NSXMLNode's addAttribute
            xmlAttrPtr oldAttr;
            
            if (attrPtr->ns == NULL) {
                oldAttr = xmlHasProp(_node, attrPtr->name);
            } else {
                oldAttr = xmlHasNsProp(_node, attrPtr->name, attrPtr->ns->href);
            }
            
            if (oldAttr == NULL) {
                
                xmlNsPtr newPropNS = NULL;
                
                // if this attribute has a namespace, search for a matching namespace
                // on the node we're adding to
                if (attrPtr->ns != NULL) {
                    
                    newPropNS = xmlSearchNsByHref(_node->doc, _node, attrPtr->ns->href);
                    if (newPropNS == NULL) {
                        // make a new namespace on the parent node, and use that for the
                        // new attribute
                        newPropNS = xmlNewNs(_node, attrPtr->ns->href, attrPtr->ns->prefix);
                    }
                }
                
                // copy the attribute onto this node
                xmlChar *value = xmlNodeGetContent((xmlNodePtr) attrPtr);
                xmlAttrPtr newProp = xmlNewNsProp(_node, newPropNS, attrPtr->name, value);
                if (newProp != NULL) {
                    // we made the property, so clean up the property's namespace
                    
                    [[self class] fixUpNamespacesForNode:(xmlNodePtr)newProp
                                      graftingToTreeNode:_node];
                }
                
                if (value != NULL) {
                    xmlFree(value);
                }
            }
        }
    }
}


- (void)addChild:(CXMLNode *)child {
    if ([child kind] == CXMLAttributeKind) {
        [self addAttribute:child];
        return;
    }
    
    if (_node != NULL) {
        
        xmlNodePtr childNodeCopy = [child XMLNodeCopy];
        if (childNodeCopy) {
            
            xmlNodePtr resultNode = xmlAddChild(_node, childNodeCopy);
            if (resultNode == NULL) {
                
                // failed to add
                xmlFreeNode(childNodeCopy);
                
            } else {
                // added this child subtree successfully; see if it has
                // previously-unresolved namespace prefixes that can now be fixed up
                [[self class] fixUpNamespacesForNode:childNodeCopy
                                  graftingToTreeNode:_node];
            }
        }
    }
}

- (void)removeChild:(CXMLNode *)child {
    // this is safe for attributes too
    if (_node != NULL) {
        xmlNodePtr node = [child XMLNode];
        
        xmlUnlinkNode(node);
        
        // if the child node was borrowing its xmlNodePtr, then we need to
        // explicitly free it, since there is probably no owning object that will
        // free it on dealloc
//        if (!child.shouldFreeXMLNode) {
//            xmlFreeNode(node);
//        }
    }
}

- (void)replaceChild:(CXMLElement *)oldChild withNewChild:(CXMLElement *)newChild {
    if (_node != NULL) {
                
        xmlNodePtr oldChildNodeCopy = [oldChild XMLNodeCopy];
        xmlNodePtr newChildNodeCopy = [newChild XMLNodeCopy];
        if (oldChildNodeCopy && newChildNodeCopy) {
            
            xmlNodePtr resultNode = xmlReplaceNode(oldChildNodeCopy, newChildNodeCopy);
            if (resultNode == NULL) {
                
                // failed to add
                xmlFreeNode(oldChildNodeCopy);
                xmlFreeNode(newChildNodeCopy);                
            } else {
                // added this child subtree successfully; see if it has
                // previously-unresolved namespace prefixes that can now be fixed up
                [[self class] fixUpNamespacesForNode:newChildNodeCopy
                                  graftingToTreeNode:_node];
            }
        }
    }
}

static xmlChar* GDataGetXMLString(NSString *str) {
    xmlChar* result = (xmlChar *)[str UTF8String];
    return result;
}


- (void)removeAttributeForName:(NSString *)name {
    if (_node != NULL) {
        
        xmlAttrPtr attrPtr = xmlHasProp(_node, GDataGetXMLString(name));
        if (attrPtr == NULL) {
            // can we guarantee that xmlAttrPtrs always have the ns ptr and never
            // a namespace as part of the actual attribute name?
            
            // split the name and its prefix, if any
            xmlNsPtr ns = NULL;
            NSString *prefix = [[self class] prefixForName:name];
            if (prefix) {
                
                // find the namespace for this prefix, and search on its URI to find
                // the xmlNsPtr
                name = [[self class] localNameForName:name];
                ns = xmlSearchNs(_node->doc, _node, GDataGetXMLString(prefix));
            }
            
            const xmlChar* nsURI = ((ns != NULL) ? ns->href : NULL);
            attrPtr = xmlHasNsProp(_node, GDataGetXMLString(name), nsURI);
        }
        
        if (attrPtr) {
            xmlRemoveProp(attrPtr);
        }
    }
}


- (id)initBorrowingXMLNode:(xmlNodePtr)theXMLNode {
    self = [super init];
    if (self) {
        _node = theXMLNode;
        self.shouldFreeXMLNode = NO;
    }
    return self;
}

+ (id)nodeBorrowingXMLNode:(xmlNodePtr)theXMLNode {
    Class theClass;
    if (theXMLNode->type == XML_ELEMENT_NODE) {
        theClass = [CXMLElement class];
    } else {
        theClass = [CXMLNode class];
    }
    
    return [[theClass alloc] initBorrowingXMLNode:theXMLNode];
}


- (CXMLElement *)parent {
    if (_node != NULL) {
        xmlNodePtr parent = _node -> parent;
        CXMLElement *parentNode = [CXMLElement nodeBorrowingXMLNode:parent];
        return parentNode;
    }
    return nil;
}

@end
