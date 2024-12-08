include {mapper_wf} from './'
include {scattergather} from './'

x = channel.of([ [id:'x'], file('test.fq.gz')])

workflow {
    scattergather( x, 5, mapper_wf, [:] )
}
