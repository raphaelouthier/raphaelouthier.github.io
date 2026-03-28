---
title: "ScratchOS : introduction"
summary: "Bringup game, masochist mode."
series: [ScratchOS]
series_order: 0
categories: [ScratchOS]
tags: ["ScratchOS"]
#externalUrl: ""
showSummary: true
date: 2026-03-20
showTableOfContents : true
draft: false
---

## Feature first

When someone first gets into programming, everything looks new. Everything looks different. Everything is to be discovered.

After some time, things start to feel the same. Whether in the kernel or in userspace.

One has a feature in mind, and writes it, whether it be a driver, a library or an executable.

It's the same "Operating on top of a (conceptual or not) API, deciding on an API to provide, and implementing the block in between, in my case using C" game.

Either in personal projects or at work, a line of C has little conceptual value, the paths are clearly paved and one rarely goes astray.

Interest is not the point in both cases. The aim is the implementation of a feature. Fun or interest is at most coincidental.

## Guardrails

Both in the industry and in the hobbyist sectors, there are guardrails.

Those guardrails are here to allow people to go faster.

But they also condition us to think alongside them.

Let's take an example.

## From scratch ?

Let's think for a moment about how we would typically write code for a rpi2040.
- download arm-none-eabi-gcc.
- download the SDK.
- write C(++?) code that uses the SDK.
- build the project using (C?)make.
- connect the board via usb.
- wait for the board to appear as a storage device (wtf lol).
- open a file explorer.
- drag and drop the executable in the board's mass storage folder.
- code gets run on the rpi.

Now let's think about the amount of code required to power all the abstraction layers. It is gigantic.

Even our part, step 3, was made using an extensively abstracted environment. At best we used vi which at least relies on our OS's terminal and screen management. That's millions of lines.

It takes days to enumerate all the abstraction layers involved, and it takes years if not decades to understand how they operate.

## Conditioning

All those abstractions are primordial to build anything meaningful today. That is a fact.

Though, sometimes, the end result is not always the end goal.

A normal human being spends at least 15 years in school before being able to produce something meaningful.

Can this time be just called "useless" ? Probably some of it (geography classes...). But not all of it.

Some of this learning time is a necessary cost to develop the conditioning required to produce something.

## ScratchOS

ScratchOS is a game that you play alone and against yourself.

You start with any set of devboards you want, each being pre-flashed with a very basic firmware, which lets you :
- inject raw data via GPIO, which is then copied to executable memory.
- execute the start of the copied location.
And that's it.

And then you see how far you can go using :
- no computer, except
- any combination of your devboards, alongside
- any passive hardware you want.

The rules are simple. You start with nothing and you build on top of it.

## This series

This series of articles will describe my game of ScratchOS.

I'll use a set of rpi2040s.

I'll use high level tools to write the initial firmware, JLink and gcc my beloved to debug it, and high level tools to flash it.

Then I'll disconnect the debugger once and for all and build from there.

Stay tuned.

