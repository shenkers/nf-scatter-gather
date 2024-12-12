splitter_jar = file("${moduleDir}/StreamSplitter/build/StreamSplitter.jar")

process assign_uuid {

    input:
        tuple val(meta), val(reads)

    output:
        tuple val(meta_with_uuid), val(reads)

    exec:

    meta_with_uuid = meta + [ uuid: UUID.randomUUID() ]
}

workflow scatter {
    take:

    data // meta, fastq
    n // number of splits

    main:

    split_fastq( data, n, splitter_jar )

    to_map = split_fastq.out

    emit:

    to_map
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
        tuple val(id), path(part1,stageAs:'r1'), path(part2,stageAs:'r2')

    output:
        tuple val(id), path(part1), path(part2)

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

def groupPartsById( ch, keyFun, keyCounts, n, partIdKey ) {
    ch.map{ meta, fq -> [ keyFun(meta), meta[partIdKey], fq ] }
        .combine( keyCounts )
        .map{ k, partIdx, fq, count -> [ groupKey( k, count[k] * n ), partIdx, fq ] }
        .groupTuple()
        .map{ k, indices, fqs -> [ k, fqs ] }
}

workflow gather {
    take:
        x
        n
        keyFun // fun meta -> grouping id
        keyCounts // map id -> count
        partIdKey // 'uuid'

    main:
        grouped = groupPartsById(x, keyFun, keyCounts, n, partIdKey)
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
