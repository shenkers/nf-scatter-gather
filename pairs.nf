include {scatter} from './'
include {gather} from './'
include {gather_fastqs} from './'

// TODO create a top-level scatter gather that routes to single/pairs depending on cardinality
workflow scattergather_pairs {
    take:
        x
        n
        mapper
        options // map[ keyFun : ( meta -> id ), partIdKey : 'uuid', readIdKey: 'read_id' ]

    main:

        def partIdKey = options.partIdKey ?: 'uuid'
        def readIdKey = options.readIdKey ?: 'read_id'
        def keyFun = options.keyFun ?: { meta -> meta.id }

        by_read = x
            .flatMap{ meta, r1, r2 ->
                [
                    [ meta + [ (readIdKey): 1 ], r1 ],
                    [ meta + [ (readIdKey): 2 ], r2 ]
                ]
            }

        parts = scatter( by_read, n, options.scatterer )
            .flatMap{ meta, parts ->
                parts.withIndex().collect{ part, idx -> [ meta + [ (partIdKey): idx ], part ] }
            }

        r1_parts = parts.filter{ meta, fq -> meta[readIdKey] == 1 }
        r2_parts = parts.filter{ meta, fq -> meta[readIdKey] == 2 }

        // TODO make map uuid -> meta so can reconstruct the whole metamap at the end

        to_map = r1_parts.map{ meta, fq -> [ [ keyFun.&call(meta), meta[partIdKey] ], meta, fq ] }.combine(
            r2_parts.map{ meta, fq -> [ [ keyFun.&call(meta), meta[partIdKey] ], fq ] },
            by: 0
        ).map{ k, meta, r1, r2 -> [ meta, r1, r2 ] }

        mapper_out = mapper.&run( to_map )
            .flatMap{ meta, r1, r2 ->
                [
                    [ meta + [ (readIdKey): 1 ], r1 ],
                    [ meta + [ (readIdKey): 2 ], r2 ]
                ]
            }

        keyCounts = x.map{ meta, r1, r2 -> keyFun.&call(meta) }
            .reduce([:],{ acc, v ->
                acc[ [v,1] ] = ( acc[ [v,1] ] ?: 0 ) + n
                acc[ [v,2] ] = ( acc[ [v,2] ] ?: 0 ) + n
                acc
            })

        keyToMeta = x.map{ meta, r1, r2 -> [ keyFun.&call(meta), meta ] }

        gather( mapper_out.map{ meta, fq -> [ [ keyFun.&call(meta), meta[readIdKey] ], meta[partIdKey], fq ] }, options.gatherer, keyCounts, partIdKey )

        gather_r1 = gather.out
            .filter{ id_idx, fq -> id_idx[1] == 1 }
            .map{ id_idx, fq -> [ id_idx[0], fq ] }
        gather_r2 = gather.out
            .filter{ id_idx, fq -> id_idx[1] == 2 }
            .map{ id_idx, fq -> [ id_idx[0], fq ] }

        gathered = gather_r1.map{ id, fq -> [ id, fq ] }.combine(
            gather_r2.map{ id, fq -> [ id, fq ] },
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
