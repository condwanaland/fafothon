# FAFOthon
*A consequences-oriented programming language*

> **Disclaimer:** All code changes are AI written. All prose is human written.

I'm not a trained software engineer. My knowledge of programming started with a second year statistics course that used R and I just continued to evolve my understanding from there. I hacked things together and occasionally they'd work. 

So long before AI was a thing, my approach to programming has always been fairly rough. Smash some code together, click run, hope it works. 

FAFOthon is a Python fork that fully embraces that lax approach to programming. It contains a change to the `try...except` keywords that more accurately depict how the average programmer uses them. Instead of writing

```
deployment = {
    "environment": "production",
    "backups": [],
}

try:
    latest_backup = deployment["backups"][-1]
    print(f"Restoring from {latest_backup}")

except IndexError as consequences:
    print("No backup")
```

you can instead write

```
fuck_around:
    latest_backup = deployment["backups"][-1]
    print(f"Restoring from {latest_backup}")

find_out IndexError as consequences:
    print("Found out: we never made a backup.")
```

## Benefits

Mostly honesty

## Enterprise Support

I offer competitively priced training contracts for enterprises looking for help training their engineers on this radical new style of programming. 

Priced per seat. Minimum 100 people. 

## Production Use

Please don't

## Installation instructions

You're gonna have to build it from source


## Copyright and License Information

FAFOthon is an unofficial fork of CPython, distributed under the Python Software Foundation License Version 2 and other applicable component licenses.

Copyright © 2001 Python Software Foundation.
All rights reserved.

See [LICENSE](LICENSE) for the complete license terms, copyright notices, and disclaimers.

Changes from CPython: added `fuck_around` and `find_out` as alternative exception-handling syntax.
