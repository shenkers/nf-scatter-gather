include {scatter as scatter_r1; scatter as scatter_r2} from './'
include {gather as gather_r1; gather as gather_r2} from './'
include {assign_uuid} from './'


// TODO create a top-level scatter gather that routes to single/pairs depending on cardinality
workflow scattergather_pairs {
    take:
        x
        n
        mapper
        options // map[ keyFun : ( meta -> id ) ]

    main:

        by_read = x
            .multiMap{ meta, r1, r2 ->
                r1: [ meta, r1 ]
                r2: [ meta, r2 ]
            }

        scatter_r1( by_read.r1, n, mapper )
        scatter_r2( by_read.r2, n, mapper )

        // TODO make meta.uuid parameterizable in case user want to use that key for something else
        // TODO make map uuid -> meta so can reconstruct the whole metamap at the end

        to_map = scatter_r1.out.map{ meta, fq -> [ [ keyFun.&call(meta), meta.uuid ], meta, fq ] }.combine(
            scatter_r2.out.map{ meta, fq -> [ [ keyFun.&call(meta), meta.uuid ], fq ] },
            by: 0
        ).map{ k, meta, r1, r2 -> [ meta, r1, r2 ] }


        mapper_out = mapper.&run( to_map ).multiMap{ meta, r1, r2 ->
            r1: [ meta, r1 ]
            r2: [ meta, r2 ]
        }

        keyFun = options.keyFun ?: { meta -> meta.id }
        keyCounts = x.map{ meta, r1, r2 -> keyFun.&call(meta) }
            .reduce([:],{ acc, v ->
                acc[v] = ( acc[v] ?: 0 ) + 1
                acc
            })
        keyToMeta = x.map{ meta, r1, r2 -> [ keyFun.&call(meta), meta ] }

        gather_r1( mapper_out.r1, n, keyFun, keyCounts )
        gather_r2( mapper_out.r2, n, keyFun, keyCounts )

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
