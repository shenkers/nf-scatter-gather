include {mapper_wf} from './'
include {scattergather_pairs} from './'

x = channel.of(
    [ [id:'x'], file('test.fq.gz')],
    [ [id:'y'], file('test.fq.gz'), file('test2.fq.gz') ],
    [ [id:'1'], file('test.fq.gz')]
)

workflow {
    scattergather_pairs( x, 5, mapper_wf, [:] )
}
