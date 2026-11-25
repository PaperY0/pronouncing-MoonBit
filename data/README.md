# Data

## cmudict-0.7b

`data/upstream/cmudict-0.7b` is the CMU Pronouncing Dictionary, version 0.7b,
maintained by the Speech Group in the School of Computer Science at Carnegie
Mellon University.

- Official source: <https://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict/cmudict-0.7b>
- Mirror: <https://github.com/cmusphinx/cmudict>
- Copyright (C) 1993-2015 Carnegie Mellon University. All rights reserved.

License (from the file header):

> Redistribution and use in source and binary forms, with or without
> modification, are permitted provided that the following conditions
> are met:
>
> 1. Redistributions of source code must retain the above copyright
>    notice, this list of conditions and the following disclaimer.
> 2. Redistributions in binary form must reproduce the above copyright
>    notice, this list of conditions and the following disclaimer in
>    the documentation and/or other materials provided with the
>    distribution.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
> "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.

Use of this dictionary for any research or commercial purpose is completely
unrestricted. If you make use of or redistribute this material we request
that you acknowledge its origin in your descriptions.

The companion files `cmudict-0.7b.symbols` (the 39 ARPABET phonemes plus
stress variants) and `cmudict-0.7b.phones` (phoneme manner-of-articulation
classes) are from the same source and license.

## Regeneration

`cmudict_data.mbt` (the embedded MoonBit data module) is generated from
`cmudict-0.7b` by:

```bash
node tools/gen_cmudict.mjs
moon fmt   # the generator does not guarantee fmt-clean output
```

Do not edit `cmudict_data.mbt` by hand.