splitter_jar = file("${moduleDir}/StreamSplitter/build/StreamSplitter.jar")

workflow scatter {
    take:

    data // meta, fastq
    n // number of splits

    main:

    split_fastq( data, n, splitter_jar )

    emit:

    out = split_fastq.out
}


workflow scatter_gather {

    take:

    data // meta, fastq
    n // number of splits
    // apply
    // combine

    main:


    emit:

}

process split_fastq {

    cpus 8

    input:
        tuple val(meta), path('in.fq.gz')
        val(n_split)
    output:
        tuple( val(id), path('split*'), emit: split )

    script:
    """
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
