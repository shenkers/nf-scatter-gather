splitter_jar = file("${moduleDir}/StreamSplitter/build/StreamSplitter.jar")

workflow scatter {
    take:

    data // meta, fastq
    n // number of splits
    mapper // function to apply to the shards, should take [meta,fq]

    main:

    split_fastq( data, n, splitter_jar )

    to_map = split_fastq.out
        .flatMap{ meta, parts -> parts.collect{ [ meta, it ] } }

    mapper_out = mapper.&run( to_map )

    emit:

    out = mapper_out
}

workflow mapper_wf {
    take:
        x

    main:
        mapper_process(x)

    emit:
        mapper_process.out
}

process mapper_process {
    input:
        tuple val(id), path(part)

    output:
        tuple val(id), path(part)

    script:
    "echo hi"
}

process gather_fastqs {
    input:
        tuple val(id), path("part*")

    output:
        tuple val(id), path("out")

    script:
    "cat part* > out"
}

workflow gather {
    take:
        x
        n

    main:
        grouped = x.map{ meta, fq -> [ meta.id, fq ] }
            .groupTuple(by:0, size:n)
        combined = gather_fastqs(grouped)

    emit:
        out = combined
}

    // apply
    // combine
    // combine-key-fun: a function to apply to meta to use as an index for grouping prior to combining.

process split_fastq {

    cpus 8

    input:
        tuple val(meta), path('in.fq.gz')
        val(n_split)
        path('StreamSplitter.jar')
    output:
        tuple( val(meta), path('split*'), emit: split )

    script:
    """
    java -jar StreamSplitter.jar --lines-per-record 4 --num-split ${n_split} --basename split --gunzip-input --gzip-output in.fq.gz
    """

}

workflow scattergather {
    take:
        x
        n
        mapper

    main:

        scatter( x, n, mapper )
        gather( scatter.out, n )

    emit:
        gather.out
}
