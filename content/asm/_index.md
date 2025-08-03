---
title: "Assembly tricks"
date: 2025-08-03
draft: false

showDate : true
showDateUpdated : false
showHeadingAnchors : false
showPagination : true
showTableOfContents : true
showTaxonomies : true 
showWordCount : true
showSummary : true
sharingLinks : false

---

In my work, I spend a lot of time looking at ARM64 assembly code without having access to the original (C) source code and doing the decompilation in my mind.

Usually, it is simple to follow the compiler's logic, but in some cases, mostly for performance reasons, the compiler gets very clever and employs super smart tricks that make the original C and the final assembly look completely different.

With time, I have grown a taste for finding and understanding those clever tricks.

This section contains short articles compiling the best of these.

They are based on gcc's behavior and on code that I wrote myself.

