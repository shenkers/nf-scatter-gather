include {mapper_wf_single} from './'
include {scattergather} from './'

x = channel.of(
    [ [id:'x'], file('test.fq.gz')],
    [ [id:'x'], file('test.fq.gz')],
    [ [id:'1'], file('test.fq.gz')]
)

workflow {
    scattergather( x, 5, mapper_wf_single, [:] )
}
