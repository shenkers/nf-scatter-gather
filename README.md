# Scatter-Gather Module

A Nextflow module implementing the split-apply-combine pattern for parallel processing of FASTQ files. This module handles the splitting of input files into chunks, parallel processing, and subsequent concatenation of results.

## Setup and Dependencies

### Java Setup
This module requires Java, which can easily be installed using SDKMAN! to manage Java versions:

1. Install SDKMAN! following the [official instructions](https://sdkman.io/install)
2. Install Java:
```bash
sdk install java 21-open
```

### Initialize StreamSplitter
This module uses StreamSplitter as a git submodule. After cloning the repository:

1. Clone and initialize the submodule:

```bash
git clone --recurse-submodules git@github.com:shenkers/nf-scatter-gather.git
```

2. Build StreamSplitter:
```bash
cd StreamSplitter
./gradlew build
```

This will create the required JAR file at `StreamSplitter/build/StreamSplitter.jar` that the module uses for FASTQ splitting.

## Overview

This module provides a reusable workflow pattern that:
1. Splits input FASTQ files into chunks
2. Applies a user-defined process to each chunk in parallel
3. Recombines the processed chunks back into complete files

## Usage

The main entry point is the `scattergather` workflow which takes:
- Input channel of [meta, fastq] tuples
- Number of chunks to split into
- Mapper workflow to apply to chunks
- Optional configuration map

### Basic Usage

```nextflow
include { scattergather } from '/path/to/module'

workflow {
    input_ch = channel.of(
        [ [id:'sample1'], file('sample1.fq.gz') ],
        [ [id:'sample2'], file('sample2.fq.gz') ]
    )

    scattergather(
        input_ch,          // Input channel
        5,                 // Split into 5 chunks
        your_mapper_wf,    // Your mapping workflow
        [:]                // Default options
    )
}
```

### Implementing the Mapper

Users need to implement their own mapper workflow that will be applied to each chunk. The mapper workflow should:
- Accept input tuples of [meta, fastq]
- Return output in the same format

Example mapper workflow:
```nextflow
workflow mapper_wf {
    take:
        input // [meta, fastq] tuples

    main:
        your_process(input)

    emit:
        your_process.out
}
```

### Customizing Grouping

By default, files are grouped for recombination using the `id` field from the meta map. You can customize this by providing a closure in the options:

```nextflow
scattergather(
    input_ch,
    5,
    your_mapper_wf,
    [
        keyFun: { meta -> meta.sample_name } // Use sample_name instead of id
    ]
)
```

### Example: Parallel UMI-tools Extract

Here's how to use the module to parallelize UMI-tools extract:

```nextflow
process umi_extract {
    input:
        tuple val(meta), path(fastq)

    output:
        tuple val(meta), path("*_processed.fq.gz")

    script:
    """
    umi_tools extract \
        --stdin=${fastq} \
        --stdout=${meta.id}_processed.fq.gz \
        --extract-method=string \
        --bc-pattern=NNNNNN
    """
}

workflow umi_extract_wf {
    take:
        input
    main:
        umi_extract(input)
    emit:
        umi_extract.out
}

workflow {
    input_ch = channel.of(
        [ [id:'sample1'], file('sample1.fq.gz') ]
    )

    scattergather(
        input_ch,
        10,              // Process in 10 parallel chunks
        umi_extract_wf,
        [:]
    )
}
```

This will split each input file into 10 chunks, run UMI-tools extract on each chunk in parallel, and recombine the processed chunks back into complete files.
