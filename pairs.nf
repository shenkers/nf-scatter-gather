include {scatter as scatter_r1; scatter as scatter_r2} from './'
include {gather as gather_r1; gather as gather_r2} from './'
include {gather_fastqs} from './'

// TODO create a top-level scatter gather that routes to single/pairs depending on cardinality
workflow scattergather_pairs {
    take:
        x
        n
        mapper
        options // map[ keyFun : ( meta -> id ), partIdKey : 'uuid', readIdKey: 'read_id' ]

    main:

        by_read = x
            .multiMap{ meta, r1, r2 ->
                r1: [ meta, r1 ]
                r2: [ meta, r2 ]
            }

        def partIdKey = options.partIdKey ?: 'uuid'
        def readIdKey = options.readIdKey ?: 'read_id'
        def keyFun = options.keyFun ?: { meta -> meta.id }

        r1_parts = scatter_r1( by_read.r1, n, options.scatterer )
            .flatMap{ meta, parts ->
                parts.withIndex().collect{ part, idx -> [ meta + [ (partIdKey): idx ], part ] }
            }

        r2_parts = scatter_r2( by_read.r2, n, options.scatterer )
            .flatMap{ meta, parts ->
                parts.withIndex().collect{ part, idx -> [ meta + [ (partIdKey): idx ], part ] }
            }

        // TODO make map uuid -> meta so can reconstruct the whole metamap at the end

        to_map = r1_parts.map{ meta, fq -> [ [ keyFun.&call(meta), meta[partIdKey] ], meta, fq ] }.combine(
            r2_parts.map{ meta, fq -> [ [ keyFun.&call(meta), meta[partIdKey] ], fq ] },
            by: 0
        ).map{ k, meta, r1, r2 -> [ meta, r1, r2 ] }

        mapper_out = mapper.&run( to_map ).multiMap{ meta, r1, r2 ->
            read1: [ meta + [ (readIdKey): 1 ], r1 ]
            read2: [ meta + [ (readIdKey): 2 ], r2 ]
        }

        keyCounts = x.map{ meta, r1, r2 -> keyFun.&call(meta) }
            .reduce([:],{ acc, v ->
                acc[v] = ( acc[v] ?: 0 ) + 1
                acc
            })
        keyToMeta = x.map{ meta, r1, r2 -> [ keyFun.&call(meta), meta ] }

        gather_r1( mapper_out.read1, n, keyFun, options.gatherer, keyCounts, partIdKey )
        gather_r2( mapper_out.read2, n, keyFun, options.gatherer, keyCounts, partIdKey )

        gathered = gather_r1.out.map{ id, fq -> [ id, fq ] }.combine(
            gather_r2.out.map{ id, fq -> [ id, fq ] },
            by: 0
        )
        .combine(keyToMeta,by:0)
        .map{ id, r1, r2, meta -> [ meta, r1, r2 ] }

    emit:
        //channel.empty() // gathered
        gathered
}

workflow mapper_wf_pairs {
    take:
        x

    main:
        mapper_process_pairs(x)

    emit:
        mapper_process_pairs.out
}

process mapper_process_pairs {
    input:
        tuple val(id), path(part1,stageAs:'r1'), path(part2,stageAs:'r2')

    output:
        tuple val(id), path(part1), path(part2)

    script:
    "echo hi"
}
