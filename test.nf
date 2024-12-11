include {mapper_wf} from './'
include {scattergather_pairs} from './pairs'

x = channel.of(
    [ [id:'x'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'y'], file('test.fq.gz'), file('test2.fq.gz') ]
)

workflow {
    out = scattergather_pairs( x, 5, mapper_wf, [:] )
    out[0].dump(tag:'result')
}
