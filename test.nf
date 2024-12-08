include {scatter} from './'
include {mapper_wf} from './'
//include {gather_fastqs as gather} from './'
include {gather} from './'
include {scattergather} from './'

x = channel.of([ [id:'x'], file('test.fq.gz')])

workflow {

    scattergather( x, 5, mapper_wf )
    /*
    scatter( x, 3, mapper_wf )

    scatter.out.view()
    gather( scatter.out, 3 )
    //combiner( scatter.out, 3, gather )
    gather.out.view()
    */
    scattergather.out.view()
}
