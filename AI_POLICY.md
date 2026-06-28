Invidious is and has always been made by human first and foremost. However, things have changed recently with the rise of AI.

This document is going to explain everything that you need to know if you ever contribute in any way to Invidious using any kind of AI.

This document has been fully written, from scratch, by a Human.


# Motivation

Invidious is written in an obscure language: Crystal.

Because it is obscure the number of people knowing it is really low.

Invideos is the biggest Crystal project that exists, bigger than Crystal itself [(yes, seriously)](https://shards.info/).

The problem of being the biggest software in an obscure language is that you're often effectively the first project to encounter a problem and because it's an obscure language, not a lot of libraries exist to make it easier for you, meaning, you usually have to make everything you need yourself.

This makes it so working on Invidious far harder than working on most open source projects because you are effectively not benefiting and not using any external libraries for the vast majority of things. Almost any time you need anything, you have to make it yourself, which overcomplicates everything.

# Policy

**Any one using AI to report bugs or submit code MUST properly disclose it, this includes mentioning the name of the EXACT model used and the tools used to interact with it.**

Now that LLM exists and have become *reasonably good*, we will tolerate people using them with reasons and knowledge, with those rules:

- The Human using AI MUST properly check the output manually in addition to any automated check that may exist or may have been created, **this includes BOTH codes AND bug reports**.
- Any code submitted by a Human, written even partially by AI, is the responsibility of this Human - If it's malicious, broken, destructive or anything bad, the Human is the sole responsible. 
- Any new code touching any of the actual functions of Invidious MUST BE thoroughly tested by the Human MANUALLY.
- Team members using LLMs are strongly encouraged to wait for the review of another Human before merging anything.
- At any point [Human-in-the-loop](https://en.wikipedia.org/wiki/Human-in-the-loop) applies.
