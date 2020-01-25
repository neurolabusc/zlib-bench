# zlib-bench


## Introduction

This is a simple script by [Juho Snellman](https://github.com/jsnell/zlib-bench) to benchmark different zlib compression libraries.  Here, I have adapted the script to evaluate .gz compression of [NIfTI](https://nifti.nimh.nih.gov/) format brain images. It is common for tools like [AFNI](https://afni.nimh.nih.gov/) and [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki) to save NIfTI images using gzip compression (.nii.gz files).  Modern MRI methods such as multi-band yield huge datasets, so considerable [time](https://github.com/rordenlab/niimath) spent compressing these images.  Parallel compression (using [pigz](https://github.com/madler/pigz)) and accelerated zlib compression libraries like [ClodFlare zlib and zlib-ng can have a dramatic benefit.


| Image        |    Baseline   |  CloudFlare   |   zlib-ng     |
|--------------|--------------:|--------------:|--------------:|
| asl16.nii    | 13.8s (100%)  |  6.5s (47%)   |  7.4s (53%)   |
| asl32.nii    | 7.5 (100%)    |  **3.5s (48%)**   |  5.7s (77%)   |

It is worth noting that [zlib-ng](https://github.com/zlib-ng/zlib-ng/issues/326) is currently focusing on a robust solution that can replace the classic baseline zlib. On the other hand, the CloudFlare zlib aggressively optimizes performance on modern x86-64 computers. However, this dataset does provide a clear example of how these tools perform differently.

## Running the benchmark

Run the benchmark with a command like the following:

```
perl bench.pl --output-format=json --output-file=results.json
```

This will store the results in a json file for later analysis.


## Pretty-print the results

To pretty-print the results of an earlier run stored in a json file, use the --read-json flag.

```
perl bench.pl --read-json=results.json
```

## Changing which versions are tested against

To change the versions which are tested against, you need to edit the `@versions` variable in the source code (either the git repository urls or the version hashes). Note that if you change the definition of existing entries under versions (or if you e.g. upgrade the compiler), you’ll probably want to run with the `--recompile` flag the next time.

##Adding new input files to the benchmark

Any files starting with a small letter in the corpus/ directory will be used as inputs, each one creating a new benchmark family (decompression, compression at each specified compression level). The name of the file is used as the benchmark id in reports.

## Full options

```
--help                 Print a help message
--compress-iters=...   Number of times each file is compressed in one
                       benchmark run
--compress-levels=...  Comma-separated list of compression levels to use
--decompress-iters=... Number of times each file is compressed in one
                       benchmark run
--output-file=...      File (- for stdout) where results are printed to
--output-format=...    Format to output results in (pretty, json)
--read-json=...        Don't run benchmarks, but read results from this file
--recompile            If passed, recompile all zlib versions before test
--runs=...             Number of runs for each benchmark
--quiet                Don't print progress reports to STDERR
```

