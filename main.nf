splitter_jar = file("${moduleDir}/StreamSplitter/build/StreamSplitter.jar")

workflow scatter {
    take:

    data // meta, fastq
    n // number of splits
    scatterer // an optional splitting process

    main:

    if(scatterer)
        scattered = scatterer.&run( data, n )
    else
        scattered = split_fastq( data, n, splitter_jar )

    emit:

    scattered
}

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
        gatherer // gather_fastqs
        keyCounts // map id -> count
        partIdKey // 'uuid'

    main:
        grouped = x.map{ k, partIdx, fq -> [ k, partIdx, fq ] }
            .combine( keyCounts )
            .map{ k, partIdx, fq, count -> [ groupKey( k, count[k] ), partIdx, fq ] }
            .groupTuple()
            .map{ k, indices, fqs ->
                ordered_fqs = [ indices, fqs ].transpose()
                    .sort{ a_idx_fq, b_idx_fq -> a_idx_fq[0] <=> b_idx_fq[0] }
                    .collect{ idx, fq -> fq }
                [ k, ordered_fqs ]
            }

        if( gatherer )
            combined = gatherer.&run(grouped)
        else
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
        def partIdKey = options.partIdKey ?: 'uuid'
        keyCounts = x.map{ meta, fq -> keyFun.&call(meta) }
            .reduce([:],{ acc, v ->
                acc[v] = ( acc[v] ?: 0 ) + n
                acc
            })
        keyToMeta = x.map{ meta, fq -> [ keyFun.&call(meta), meta ] }
        scatter( x, n, options.scatterer )
        to_map = scatter.out
            .flatMap{ meta, parts ->
                parts.withIndex().collect{ part, idx -> [ meta + [ (partIdKey): idx ], part ] }
            }
        mapper_out = mapper.&run( to_map )
        gather( mapper_out.map{ meta, fq -> [ keyFun.&call(meta), meta[partIdKey], fq ] }, options.gatherer, keyCounts, partIdKey )
        gathered = gather.out
            .combine( keyToMeta, by: 0 )
            .map{ id, fq, meta -> [ meta, fq ] }

    emit:
        gathered
}
