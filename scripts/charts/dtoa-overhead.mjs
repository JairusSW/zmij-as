// dtoa/ftoa overhead ratios vs the AssemblyScript stdlib, by input complexity.
// Derived from the dtoa-comp-* / ftoa-comp-* bench logs (ratios use raw nsPerOp;
// the per-pass->per-conversion factor cancels). Three ratios per bucket:
//   alloc tax        = zmij alloc / zmij no-alloc      (> 1: the String cost)
//   no-alloc speedup = stdlib no-alloc / zmij no-alloc (> 1: we win)
//   alloc speedup    = stdlib alloc / zmij alloc       (> 1: we win)
//   bun run bench -- --v8 dtoa-comp ftoa-comp

import fs from "node:fs";
import path from "node:path";
import {
    createBarChart,
    generateChart,
    withRuntime,
    subtitle,
    RUNTIME,
} from "../lib/bench-chart.mjs";

const ROOT = path.resolve(import.meta.dirname, "..", "..");
const LOGS = path.join(ROOT, "build", "logs", "as", RUNTIME);

const BUCKETS_F64 = [
    "zero-special",
    "tiny-fixed",
    "fixed-fractions",
    "long-fixed",
    "small-exponent",
    "large-exponent",
    "subnormal-boundary",
    "randomish",
];
const BUCKETS_F32 = [
    "zero-special",
    "tiny-fixed",
    "fixed-fractions",
    "small-exponent",
    "large-exponent",
    "subnormal-boundary",
    "randomish",
];

const ns = (prefix, bucket, suffix) => {
    const p = path.join(LOGS, `${prefix}-${bucket}-${suffix}.as.json`);
    return fs.existsSync(p)
        ? JSON.parse(fs.readFileSync(p, "utf8")).nsPerOp
        : null;
};

const ALLOC_TAX = "zmij alloc / no-alloc";
const NOALLOC_WIN = "stdlib / zmij (no-alloc)";
const ALLOC_WIN = "stdlib / zmij (alloc)";

function addBuckets(data, prefix, buckets, tag) {
    for (const bucket of buckets) {
        const zn = ns(prefix, bucket, "zmij-noalloc");
        const za = ns(prefix, bucket, "zmij-alloc");
        const sn = ns(prefix, bucket, "stdlib-noalloc");
        const sa = ns(prefix, bucket, "stdlib-alloc");
        if ([zn, za, sn, sa].some((v) => v == null)) continue;
        const label = `${tag} ${bucket}`;
        data[label] = {
            [ALLOC_TAX]: { ratio: za / zn },
            [NOALLOC_WIN]: { ratio: sn / zn },
            [ALLOC_WIN]: { ratio: sa / za },
        };
    }
}

const data = {};
addBuckets(data, "dtoa-comp", BUCKETS_F64, "f64");
addBuckets(data, "ftoa-comp", BUCKETS_F32, "f32");

if (Object.keys(data).length) {
    generateChart(
        createBarChart(data, {
            metric: "ratio",
            yLabel: "ratio (× - higher = bigger gap)",
            title: "dtoa/ftoa overhead ratios vs stdlib by complexity",
            subtitle: subtitle(),
            xRotation: 60,
            labelFormatter: (v) => v.toFixed(2),
        }),
        withRuntime("./charts/dtoa-overhead.png"),
        { width: 1700, height: 800 },
    );
} else {
    console.warn(
        `no dtoa-comp/ftoa-comp logs in ${LOGS} - run: bun run bench -- --${RUNTIME} dtoa-comp ftoa-comp`,
    );
}
