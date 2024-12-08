splitter_jar = file("${moduleDir}/StreamSplitter/build/StreamSplitter.jar")

workflow scatter {
    take:

    data // meta, fastq
    n // number of splits
    mapper // function to apply to the shards, should take [meta,fq]

    main:

    split_fastq( data, n, splitter_jar )

    to_map = split_fastq.out
        .flatMap{ meta, parts -> parts.collect{ [ meta, it ] } }

    mapper_out = mapper.&run( to_map )

    emit:

    out = mapper_out
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
        tuple val(id), path(part)

    output:
        tuple val(id), path(part)

    script:
    "echo hi"
}

workflow gather_wf {
    take:
        x // [ id, [piece1,...]

    main:
        x.dump(tag:'here')
        gather_fastqs( x )

    emit:
        out = gather_fastqs.out
}

process gather_fastqs {
    input:
        tuple val(id), path("part*")

    output:
        tuple val(id), path("out")

    script:
    "cat part* > out"
}

workflow gather {
    take:
        x
        n
        //combiner

    main:
        grouped = x.map{ meta, fq -> [ meta.id, fq ] }
            .dump(tag:'togroup')
            .groupTuple(by:0, size:n)
            .dump(tag:'grouped')
            println('n:'+n)
        combined = gather_fastqs(grouped)
        //combined = combiner.&run(grouped)

    emit:
        out = combined
}


/*
workflow scatter_gather {

    take:

    data // meta, fastq
    n // number of splits
    // apply
    // combine
    // combine-key-fun: a function to apply to meta to use as an index for grouping prior to combining.

    main:


    emit:

}
*/

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

process combine_fastq {

        cpus 1

        input:
                tuple( val(id), file('split1*'), file('split2*') )
        output:
                tuple( val(id), file('read1.fq.gz'), file('read2.fq.gz'), emit: umi_fastq )

        script:
        """
        cat split1* > read1.fq.gz
        cat split2* > read2.fq.gz
        """

}

workflow scattergather {
    take:
        x
        n
        mapper

    main:

        scatter( x, n, mapper_wf )
        gather( scatter.out, n )

    emit:
        gather.out
}
