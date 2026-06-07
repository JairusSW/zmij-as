<h1 align="center"><pre>╔══╗ ╔╗╔╗ ╦  ╦    ╔═╗ ╔═╗
 ╔╝  ║╚╝║ ║  ║ ══ ╠═╣ ╚═╗
╚══╝ ╩  ╩ ╩ ╚╝    ╩ ╩ ╚═╝</pre></h1>

<p align="center">
The fastest <strong>ECMAScript-<code>Number.toString</code>-compatible</strong>
<code>f64</code>/<code>f32</code> → string for
<a href="https://www.assemblyscript.org/">AssemblyScript</a>, built on the
<strong><a href="https://github.com/vitaut/zmij" >Żmij</a></strong> (<a href="https://fmt.dev/papers/Schubfach4.pdf">Schubfach</a> + <a href="https://github.com/xjb714/xjb/blob/81af30358003c98eda6429fbff0d826e0c259302/xjb.pdf">xjb</a>) core.
</p>

<details>
<summary>Table of Contents</summary>

- [Installation](#installation)
- [Usage](#usage)
- [API](#api)
- [Performance](#performance)
- [Verification](#verification)
- [Benchmarks](#benchmarks)
- [Architecture](#architecture)
- [Credits](#credits)
- [License](#license)
- [Contact](#contact)

</details>

## Installation

```bash
npm install zmij-as
```

`zmij-as` is plain exported functions - no compiler transform required. The digit
kernel uses [SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data) when available
and falls back to scalar [SWAR](https://en.wikipedia.org/wiki/SWAR) otherwise.

To enable SIMD, add to your `asc` command:

```bash
--enable simd
```

Or in your `asconfig.json`:

```json
{
  "options": {
    "enable": ["simd"]
  }
}
```

## Usage

```typescript
import { dtoa, dtoa_buffered, ftoa, ftoa_buffered } from "zmij-as";

dtoa(3.14159);     // "3.14159"
dtoa(1e21);        // "1e+21"
dtoa(-0.0);        // "0"
ftoa(0.1);         // "0.1"
```

Writing a serializer with its own buffer? Skip the `String` allocation and write
UTF-16 straight into your buffer:

```typescript
// UTF-16 written directly into your buffer (>= 64 bytes); no allocation.
const codeUnits = dtoa_buffered(buffer, value);
```

`dtoa(x)` matches V8 `x.toString()` / `JSON.stringify(x)` byte-for-byte -
including `Infinity`, `-Infinity`, `NaN`, `-0 → "0"`, `1e21 → "1e+21"`,
`1e-7 → "1e-7"`, the fixed-vs-exponential thresholds, and the minimal-width
signed exponent per [ECMAScript Specification](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring).

## API

```typescript
dtoa(value: f64): string                 // shortest round-trip, ECMAScript-formatted
dtoa_buffered(buffer, value: f64): u32   // write UTF-16 into buffer, return code-unit count
ftoa(value: f32): string                 // shortest round-trip, ECMAScript-formatted
ftoa_buffered(buffer, value: f32): u32   // write UTF-16 into buffer, return code-unit count
```

**Buffer contract.** `dtoa_buffered` / `ftoa_buffered` write the shortest decimal
as UTF-16 *directly* into `buffer` (no intermediate ASCII pass or widening);
`buffer` needs ≥ 64 bytes. The returned code-unit count is exact - the extra
headroom covers the in-register digit-block stores, which can overshoot the
logical end by up to one 8-char block.

## Performance

<p align="center">
<img src="https://raw.githubusercontent.com/JairusSW/zmij-as/refs/heads/docs/charts/v0.0.0/04-e4c0203/dtoa-comp-f64-wavm.png" alt="dtoa (f64) latency vs the AssemblyScript stdlib, by input complexity">
</p>
<p align="center">
<img src="https://raw.githubusercontent.com/JairusSW/zmij-as/refs/heads/docs/charts/v0.0.0/04-e4c0203/dtoa-comp-f32-wavm.png" alt="ftoa (f32) latency vs the AssemblyScript stdlib, by input complexity">
</p>
<p align="center">
<img src="https://raw.githubusercontent.com/JairusSW/zmij-as/refs/heads/docs/charts/v0.0.0/04-e4c0203/dtoa-stages-f64-wavm.png" alt="dtoa (f64) per-stage latency breakdown">
</p>

Charts are published per release to the `docs` branch via `npm run charts:publish`
(`scripts/publish-charts.sh`) and pinned here by version.

## Verification

`dtoa`/`ftoa` are checked against V8 ground truth (`Number::toString` for f64; the
exact BigInt shortest-round-trip for f32) - 0 failures across every power of two
(±1/±0xF ulp), every power of ten, tens of millions of random values, and a
generated assertion suite with 100% line/branch coverage.

```bash
# generate the as-test spec from the V8 oracle, then run the suite
npm run gen-spec
npm test

# build the verify wasm + check against V8 (fixed edge + 2M random; pass a count)
npm run verify
node scripts/dtoa/verify.mjs 3000

# open-ended differential fuzz vs V8 (seeded, repro-friendly; --runs/--time/--seed)
npm run fuzz
```

## Benchmarks

```bash
npm run bench -- --v8 --wavm
npm run charts:build -- --v8 --wavm
npm run charts:serve
```

## Architecture

The shortest-decimal core is a port of [**Żmij**](https://github.com/vitaut/zmij)
(Schubfach + xjb single-power-of-ten multiply); the formatter lays out digits per
the [ECMA-262 `Number::toString` decision tree](https://tc39.es/ecma262/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring) and stores UTF-16 directly.

## Credits

The shortest-decimal **digits** are identical to Ryū/Dragonbox (shortest,
round-to-nearest-even) - exactly what ECMA-262 mandates; only the surface
formatting differs. The core is a port of [**Żmij**](https://github.com/vitaut/zmij) by Victor Zverovich (MIT).

## License

[MIT](./LICENSE)

## Contact

Please send all issues to [GitHub Issues](https://github.com/JairusSW/zmij-as/issues) and to converse, please send me an email at [me@jairus.dev](mailto:me@jairus.dev)

- **Email:** Send me inquiries, questions, or requests at [me@jairus.dev](mailto:me@jairus.dev)
- **GitHub:** Visit the official GitHub repository [Here](https://github.com/JairusSW/zmij-as)
- **Website:** Visit my official website at [jairus.dev](https://jairus.dev/)
- **Discord:** Contact me at [My Discord](https://discord.com/users/600700584038760448) or on the [AssemblyScript Discord Server](https://discord.gg/assemblyscript/)
