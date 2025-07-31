--- 
title: "Optimization case study : JSON parsing." 
summary: "Parsing large JSON files faster and fatser."
categories: ["C","ARM64","Optimization"] 
#externalUrl: "" 
showSummary: true
date: 2025-07-30 
showTableOfContents : true 
draft: true 
---

## Context

While working on this project (TODO LINK) involving ARM64 register programming I quickly felt the need to have a small command line tool that would give me some info on a given register, to avoid constantly looking in the ARM64 spec.

Luckily for me, ARM folks did a great job (this time) and they nowadays release "machine-readable" descriptors of their ISA, in the form of gigantic JSON files describing among other things every register available.

Note
A while ago I had to implement an ARM32 emulator for my uKasan, but at that time I only had found the XML human-readable version which was a real pain to parse.
This JSON spec is MUCH better and I can't thank ARM folks enough for it.

But simplicity never lasts long : when I can, I prefer recoding my libraries myself and avoid relying on third party code, as well as programming in C.

Back then for uKasan, after looking for 2 long minutes at the  immediately defaulted to python after looking at the [XML's EBNF](https://www.liquid-technologies.com/Reference/Glossary/XML_EBNF1.1.html) I quickly decided to doubly hold my nose and to :
- rely on a third party XML parsing library.
- use python.

which kinda hurt let's be honest. 

But JSON is a whole simpler kind of beast. A glance a the [JSON EBNF](https://gist.github.com/springcomp/e72d09e3a8f06e8d711751c3d1ee160e) will show you how simple it is compared to XML.

I have already implemented a couple of JSON parsers for past use cases, but those were small JSON files, and I cared more about the functionality itself than about its performance.

This time, it is different : the ARM64 Register descriptor is 82MB wide, so the parsing time is non-neglectible.

My wish was to have my little command line database load as quickly as possible, and the more it progressed, the more it looked like it could deserve its own article.

First, we will start by some general considerations on the JSON format and its parsing.
Then, we'll discuss some algorithmic optimizations that can increase the performance.
Then, we'll go a level below and try to optimize some steps of the parsing algorithm at the assembly level to increase the performance even more.

### JSON parsing : high level considerations.

## The JSON format

Anyone interested in the exact JSON syntax spec should definitely go checkout [this dedicated website](https://www.JSON.org/JSON-en.html). It is great, and very clearly defines all the basic JSON data structures, so clearly that I was just tempted to post screenshots of it in this article. But I refrained.

Long story very short, the JSON file defines the basic value structure which can be any of :
- null : equivalent to void or none. Indicates the value of the XML format these days.
- boolean : false or true.
- number : decimal positive or negative integer or float.
- string : sequence of chars delimited by double quotes, backslashed characters have special meanings. 
- array : sequence of values separated by commas and delimited by brackets.
- object : sequence of `key (string) : value` separated by commas and delimited by brackets.

Note that the beauty of the JSON is that the array and object structures contain values and hence make this format recursive. That will matter when we'll discuss parsing.

The json spec essentially defines the low level features of our parser. It will need to recognize every entity supported by the spec and parse it correctly.

### Skipping, and why it matters.

A parser is a piece of code able to extract and process data structured in a given format.

A counter-intuitive fact is that in practice, a (linear) parser is essentially a skip engine : at any given time, it knows :
- the position in the parsed file where it is at;
- what entity is at the current position.
- how to skip the current entity, aka move to the following.

Let's see this with an example.

Note
In all this section, we will ignore whitespaces to keep the explanation simple.

Let's suppose that our parser is at the start of an object, and that it wants to extract some information contained in this object.
The parser needs to skip the object start. The json format defines '{' as single-character array start, so the parser can simply move to the next character. 
The parser is now at a string start. As per the json format, the current char should be '"'. After checking this fact, the parser can move to the next character.
The parser is now at a string body. The json format defines that the string will end with a '"' not preceded by a '/'. It can move to the next character until it detects it. If the string should be stored somewhere, it can copy it directly.
The parser is now at a string end '"'. It can move to the next character.
The parser is now at a key-value separator. After checking that the current character is ':', it can move to the next character.
The parser is now at a value start. It can now call the generic value parser which will : 
- detect the value's first character; and
- call the relevant substructure parser based on it; and
- return the location at which parsing should resume (i.e : the location of the first character after the value.
The parser is now at either :
- an array end '}', in which case the parsing is done and the parser returns the location of the character after the '}'; or
- a key:value separator ',', in which case the parser reiterates the key-value parsing routine.

So far, you can see that our parser is just a character skip engine with benefits : sometimes it may copy those characters or process them (for integer parsing), but what really matters is that it know how to skip the current entity, in order to move to the next.

But you should also realize that skipping an entity is non-trivial.
In order for our object to be fully parsed (skipped), we will have needed to skip _ every single entity that composed it _.

This fact alone gives us the first golden rule of json parsing :

Alert
DO NOT PARSE THE SAME VALUE TWICE.

We previously sawy that the json spec itself defines almost entirely the low level aspect of our parser. But there is one question that is still pending : how are we going to use those low level features ? How are we going to parse our json's components ? 

So before elaborating on the implications of the first rule, we need to define the high level features of our parser.

### Parsing a data exchange format.

A JSON file is essentially a data container. But are we always interested in all the information that it contains ?

In our case, the answer is no. The ARM64 json spec describes _everything_ about the registers and instruction, but there are many things that we are not interested in (like "Accessors" ?!).

The job of our parser will be to extract _targetted_ information.

For example, in our case, the ARM64 register spec is a gigantic array of register descriptors, where each register descriptor has a lot more info that we care about.

Note
In the following section, [.] means "all entries of the array", and ["xxx"] means the value of the current object indexed by "xxx".
 
What we care, and the way to access it in the json is :
- root : array : register descriptor.
  - [.] : object : register descriptor.
    - ["name"] : str : register name.
    - ["purpose"] : str : register purpose (null 99% of the time).
    - ["title"] : str : register title (null 99% of the time).
    - ["fieldets"] : array : layouts for this register (bad naming).
      - [.] : object : layout descriptor.
        - ["width"] : int : layout size in bits.
        - ["values"] : array : bitfield descriptor (any suggestion for a more confusing name ?).
          - [.] : object : bitfield descriptor.
            - ["name"] : str : bitfield name.
            - ["rangeset"] : array : of bit range descriptors.
                - [.] : object : bitfield descriptor.
                  - ["start"] : int : bitfield start.
                  - ["width"] : int : bitfield size.

Our parser's high level features hence sound pretty simple :
- iterate over every element of an array and parse each element with a dedicated function.
- iterate over _a_ _certain_ _set_ of object elements indexed by specific keys and parse them with a dedicated function.

Our previously etablished golden rule will have a consequence on the second feature : since we must avoid parsing anything twice, we can't afford to lookup an object once for each key that we are looking for. We will need to parse the object once and extract all elements in the order in which they appear.
    
### Sample headers, macros and parsing code.

### Base performance metrics.

TODO update the code to parse an element twice.


## 
