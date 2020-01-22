# nf-mp2

[![Build Status](https://travis-ci.com/kmayerb/nf-mp2.svg?branch=master)](https://travis-ci.com/kmayerb/nf-mp2)

nf-mp2: nextflow pipeline for MetaPhlAn2 version 2.9.20


### Config File

```
TOWERTOKEN=[USER-SUPPLIED]
IAMTOKEN=[USER-SUPPLIED]
ROLETOKEN=[USER-SUPPLIED]
```

#### nextflow-aws-econ-optimal.config
```
process.executor = 'awsbatch'
// // Run the analysis on the specified queue in AWS Batch

process.queue = 'optimal'
// // Run in the correct AWS region


// // Mount the host folder /docker_scratch to /tmp within the running job
// // Use /tmp for scratch space to provide a larger working directory
// // Replace with the Job Role ARN for your account
aws {
    region = 'us-west-2'
    batch {
        cliPath = '/home/ec2-user/miniconda/bin/aws'
        jobRole = 'arn:aws:iam::IAMTOKEN:role/ROLETOKEN'
        volumes = ['/docker_scratch:/tmp:rw']
    }
}

tower {
  accessToken = TOWERTOKEN
  enabled = true
}

process {
    withName: 'metaphlan2' {
        errorStrategy = {task.attempt <= 3 ? 'retry' : 'finish'}
        memory = {4.GB * task.attempt}
        maxRetries = 3
        cpus = 2
        time = {4.h * task.attempt}
    }
    withName: 'merge_metaphlan_tables' {
        cpus = 1
        memory = 8.GB
        errorStrategy = 'finish'
    }
}
```


### Execution Script

#### run.sh

```
#! bin/bash
ml nextflow

# Reference database
BATCHFILE=[USER-SUPPLIED]
NFCONFIG=nextflow-aws-econ-optimal.config
PROJECT=nf-mp2-test

OUTPUT_FOLDER=[USER-SUPPLIED]
WORK_DIR=[USER-SUPPLIED]

NXF_VER=19.10.0 nextflow \
    -c $NFCONFIG \
    run \
    kmayerb/nf-mp2 \
        -r 0.0.1\
        --batchfile $BATCHFILE \
        --output_folder $OUTPUT_FOLDER \
	    --cpus_metaphlan2 4 \
        -with-report $PROJECT.html \
        -work-dir $WORK_DIR \
        -with-tower 
```


