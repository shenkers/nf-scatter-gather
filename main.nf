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

//keep
workflow mapper_wf_single {
    take:
        x

    main:
        mapper_process_single(x)

    emit:
        mapper_process_single.out
}

process mapper_process_single {
    input:
        tuple val(id), path(part)

    output:
        tuple val(id), path(part)

    script:
    "echo hi"
}
//keep

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
        keyFun // fun meta -> grouping id
        keyCounts // map id -> count

    main:
        grouped = x.map{ meta, fq -> [ keyFun.&call(meta), fq ] }
            .combine( keyCounts )
            .map{ k, fq, count -> [ groupKey( k, count[k] * n ), fq ] }
            .groupTuple()
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
        options // map[ keyFun : ( meta -> id ) ]

    main:

        keyFun = options.keyFun ?: { meta -> meta.id }
        keyCounts = x.map{ meta, fq -> keyFun.&call(meta) }
            .reduce([:],{ acc, v ->
                acc[v] = ( acc[v] ?: 0 ) + 1
                acc
            })
        keyToMeta = x.map{ meta, fq -> [ keyFun.&call(meta), meta ] }
        scatter( x, n, mapper )
        gather( scatter.out, n, keyFun, keyCounts )
        gatheredWithMeta = gather.out.combine( keyToMeta, by: 0 )
            .map{ id, fq, meta -> [ meta, fq ] }

    emit:
        gatheredWithMeta
}
