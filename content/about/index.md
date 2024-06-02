---
title: "About me"
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

I am Raphael Outhier, a french engineer working in Texas and this is my website.

I graduated in 2019 from a French engineering school, worked for ARM for a year and am now working for Apple as a platform (HW) kernel engineer.

At work, I specialize in CPU bringup and CPU tracing (coresight).


Programming is one of my passions, a passion that I invest a lot of time in.

Though, I'm legally not authorized by my employer to contribute to open source projects.

But that still leaves me the possibility to work on those projects, and to write about those.

The latter is the reason why I created this website.

In this website, you'll find articles about the various projects that I've been working on these last years.

Those articles will likely revolve around some of the following themes.


## Robotics

I originally started studying embedded systems development with the objective of understanding how robots (CNC machines, drones etc...) work.

And by understanding, I mean that I wanted to build them from scratch (as much as possible), and write the code to make them work, also from scratch.

I have currently wandered far away from this objective, mostly because of the second theme described below that took precedence these last 6 years, but still have the hope to get back to finishing my CNC control software in the future.


## Kernel development

Controlling robots is essentially done using microcontrollers.

My first robot was a quadcopter that I built myself, and that I tried to write the control software for.

Using ARM MBed at the time, I realized that there was a lot happening under the hood. Actually, I realized that the control code that I wrote was nothing in comparison to the kernel that was running on the processor, and that was handling 99% of the work.

How can one be proud of his code, when it's running in such a helped and catered environment. I was not.

That was the moment where I decided to write my own microkernel from scratch using just a C compiler and the datasheet for my microcontroller.

This has evolved into a 6 years (so far) project targeting more modern processors than my original 8 bits AVR, in which I implemented every major kernel block, including the memory system, the scheduler, the file system, the driver abstraction layer, the resource tracking system, and many more.

This is essentially thanks to this project and to the many hours that I spent refining my understanding of how kernel and processor work that I was able to get hired by Apple to do the kernel bringup for their next generation of devices.


## 3D CAD algorithms

Before I started programming, I was doing small projects on Solidworks, a CAD tool that I really like.

What I found the most interesting, and that I didn't really understand at that time, was how the core algorithms worked : how can you, from a sequence of abstract instructions, generate an actual 3d file.

Those kinds of algorithms are called CSG algorithms, for Constructive Solid Geometry, and quickly got my attention after I became fluent with C.

My dream objective was to reimplement a program "like" (i.e. with only the basic part edition features) of solidworks, that would allow me to create my robot parts myself.

I have been working on this project for around four years, and now have a pure C library that does boolean operations on 3d polyhedrons in a highly performant and robust way, using octrees and BSP trees, so as brep-based remeshing, 2d polygon boolean operations, and many other fun stuff.



That makes a lot of projects and code. As stated earlier, I am not authorized to publish any project because of my current job at Apple. But maybe that will change in some years, who knows.

In the meantime, the best I can do is to try to make good descriptive articles about those, and hope that you will find them interesting.


