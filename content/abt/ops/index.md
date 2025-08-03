---
title: "Opensource"
date: 2023-09-27
draft: false

showDate : false
showDateUpdated : false
showHeadingAnchors : false
showPagination : false
showReadingTime : false
showTableOfContents : false
showTaxonomies : false 
showWordCount : false
showSummary : false
sharingLinks : false
showEdit: false
showViews: false
showLikes: false
showAuthor: false
layoutBackgroundHeaderSpace: false
---



This article is here to answer a question that has probably come to your mind if you read one of my articles :

{{< alert >}}
Why isn't this guy just publishing the source code ? That would be so much easier.
{{< /alert >}}

## My job.

During the day, I work as a platform kernel engineer at Apple.

My work essentially consists on two major things :
- developing drivers for Apple's next generation of chips for computers, phones, watches, TVs, and headsets.
- investigating HW bugs that occured on those chips, and finding what instructions a given CPU incorrectly executed so that the HW team can find out where the RTL bug is.

Due to this job, I am legally constrained not to contribute to any open source project.

> In practice, what this means is unclear, has blurred lines, and it is likely not compliant with the law of Texas. But in the end, everything ends up being a battle of lawyers and I don't have Apple's treasury.

If we want to use the real terms, this is the way Apple found to protect its intellectual property. It's not necessarily that Apple lawyers _want_ us not to work on open source projects, but Apple is so big that they realistically can't arbitrate the boundaries of each developer's work.

Luckily for me, my work is pretty low level, and my interests on the personal-projects side quite radically differ from what I have to do at work, as my projects are either :
- user-space programs, whereas my work at apple exclusively involves kernel-space programming.
- embedded bringup for microcontrollers, whereas my work at Apple exclusively involves working on cutting edge high-performance processors.

So it is unlikely that they would come after me, even in the event where I would publicize all my personal works.

But I do not want to tempt the devil, nor to be provocative.

Though, at the same time, I want to talk about my personal projects which I am passionate about, so a reasonable compromise is needed.

## What I can't do

What I know is that I am not authorized to write code for an existing open source project.
I should never willingly provide code for such a project, nor should I ever appear in their commit history.

## What I can do

This doesn't prevent me from working on my personal closed source projects, nor does it prevent me from talking about them, as long as they are not related to my work at Apple.


I just cannot :
- give access to the actual code.
- reveal Apple secrets.

But I can freely :
- provide excerpts of public-domain code.
- provide code which is not written by me (ex : output assembly of GCC).
- describe the principles and design choices of algorithms that I develop, as soon as they are not related to confidential topics that I have access to at my work. Good thing : they are not.

## What I probably can get away with

I believe that Apple would not come after me in the following cases :
- if I post code that only covers matters on which there are already many public implementations available. Examples of this are :
  - C preprocessor trickery, see [the macro iceberg](https://jadlevesque.github.io/PPMP-Iceberg/) for an exhaustive list.
  - my articles on json parsing. Nothing ground-breaking here, nor subject to confidentiality matters.
- if I post only the declarations (API spec) of a particular library that I wrote myself in my free time which is unrelated to my work. This is technically compiler-readable code, but in practice I only use this to convey some concise information and it cannot be directly used without implementing those APIs.

