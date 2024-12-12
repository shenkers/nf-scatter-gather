# Scatter-Gather Module

A Nextflow module implementing the split-apply-combine pattern for parallel processing of files. While originally designed for FASTQ files, the module now supports arbitrary file types through custom scatter and gather implementations. This module handles the splitting of input files into chunks, parallel processing, and subsequent concatenation of results.

## Setup and Dependencies

### Java Setup
This module requires Java, which can easily be installed using SDKMAN! to manage Java versions:

1. Install SDKMAN! following the [official instructions](https://sdkman.io/install)
2. Install Java:
```bash
sdk install java 17-open
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

    mapped = scattergather(
        input_ch,          // Input channel
        5,                 // Split each input file into 5 chunks
        simple_mapper,     // Your mapping process or workflow to apply to each chunk
        [:]                // Options, default grouping with key meta.id
    )

    // Use the output in downstream processes
    // bwa(mapped, reference_genome)
}
```

### Implementing the Mapper

The mapper can be either a single process or a workflow combining multiple processes. It should:
- Accept input tuples of [meta, fastq]
- Return output in the same format

Example single process mapper:
```nextflow
process simple_mapper {
    input:
        tuple val(meta), path(fastq)
    output:
        tuple val(meta), path("*_processed.fq.gz")
    script:
    """
    # Your processing steps here
    """
}
```

Example multi-process workflow mapper:
```nextflow
workflow mapper_wf {
    take:
        input // [meta, fastq] tuples
    main:
        process_1(input)
        process_2(process_1.out)
    emit:
        process_2.out
}
```

### Configuration Options

The module accepts several options to customize its behavior:

```nextflow
[
    keyFun: { meta -> meta.sample_name },  // Function to generate grouping key from meta (default: meta.id)
    partIdKey: 'chunk_id',                 // Key used in meta to track chunk IDs (default: 'uuid')
    readIdKey: 'read_num',                 // Key used in meta to track read pairs (default: 'read_id')
    scatterer: custom_scatter_process,      // Custom process to split input files (default: split_fastq)
    gatherer: custom_gather_process         // Custom process to combine output files (default: gather_fastqs)
]
```

### Single-end vs Paired-end Reads

The module automatically handles both single-end and paired-end reads through separate workflows:

#### Single-end Usage
```nextflow
include { scattergather } from '/path/to/module'

workflow {
    input_ch = channel.of(
        [ [id:'sample1'], file('sample1.fq.gz') ]
    )
    
    scattergather(
        input_ch,
        5,
        mapper_wf_single,
        [:]
    )
}
```

#### Paired-end Usage
```nextflow
include { scattergather_pairs } from '/path/to/module'

workflow {
    input_ch = channel.of(
        [ [id:'sample1'], file('R1.fq.gz'), file('R2.fq.gz') ]
    )
    
    scattergather_pairs(
        input_ch,
        5,
        mapper_wf_pairs,
        [:]
    )
}
```

### Custom Scatter/Gather Operations

While the module provides default implementations for FASTQ files, you can provide custom scatter and gather processes for other file types:

```nextflow
// Custom scatter process example
process custom_scatter {
    input:
        tuple val(meta), path(input)
        val(n_chunks)
    output:
        tuple val(meta), path('chunk*')
    script:
    """
    # Your custom splitting logic here
    split -n $n_chunks $input chunk
    """
}

// Custom gather process example
process custom_gather {
    input:
        tuple val(id), path('chunk*')
    output:
        tuple val(id), path('combined')
    script:
    """
    # Your custom combining logic here
    cat chunk* > combined
    """
}

workflow {
    scattergather(
        input_ch,
        5,
        your_mapper_wf,
        [
            scatterer: custom_scatter,
            gatherer: custom_gather
        ]
    )
}
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

This will split each input file into 10 chunks, run UMI-tools extract on each chunk in parallel, and concatenate the processed chunks back into complete files.
