include {mapper_wf} from './'
include {scattergather_pairs} from './pairs'
params.out_dir = 'out_pairs'
include {publish} from '../publish/publish'

x = channel.of(
    [ [id:'x'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'z'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'r'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'w'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'y'], file('test.fq.gz'), file('test2.fq.gz') ]
)

workflow {
    out = scattergather_pairs( x, 5, mapper_wf, [:] )
    out[0].dump(tag:'result')
    publish(
        channel.empty().mix(out.map{ meta, r1, r2 -> [ '', "${meta.id}_1.fq.gz", r1 ] },
        out.map{ meta, r1, r2 -> [ '', "${meta.id}_2.fq.gz", r2 ] } )
    )
}
