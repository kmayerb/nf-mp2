# nf-mp2

[![Build Status](https://travis-ci.com/kmayerb/nf-mp2.svg?branch=master)](https://travis-ci.com/kmayerb/nf-mp2)

nf-mp2: nextflow pipeline for MetaPhlAn2 version 2.9.20


### Iterative Resource Allocation

Jobs within a batch may have different resource requirements. Thus, the user may wish to specify resources (e.g., Memory) based on the typical file size within a batch but worry that a few exceptionally large files may fail due to insufficient memory. 

This scenario can be accommodated with a flexible error handling, using a conditional Nextflow [errorStrategy](https://www.nextflow.io/docs/latest/process.html), where either 'retry' or 'finish' is implemented based on the number of times a given task is attempted up to some maximum number of retries .  That is, it is possible to 'retry' failed jobs with more memory requested on each subsequent attempt. **Make sure to limit the number retries ('maxRetries'), so the job will eventually fail before trying to run on the largest available EC2 instance.**

For example, consider a portion of a Nextflow configuration file shown below. When process1 is initially run, Nextflow requests 2 CPUs and only 4 GB of memory, an allocation the user-determined was sufficient for most of the files in a batch. When an exceptionally large input file causes a job failure due to insufficient allocated memory, the config tells Nextflow to try again. In this case, when the task.attempt is less than or equal to 3 (the specified maximum number of retries), the errorStrategy will 'retry' the task with stepwise larger memory allocations. After one job failure, 8GB (4*2 attempts) will be requested for the second attempt. If that attempt fails, the third attempt with 12GB will be made. Crucially, after three failed attempts, the errorStrategy will be switched from 'retry' to 'finish' (initiating an orderly pipeline shutdown when an error condition is raised, waiting for the completion of other submitted jobs). 


```
process {
    withName: 'process1' {
        cpus = 2
        maxRetries = 3
        errorStrategy = {task.attempt <= 3 ? 'retry' : 'finish'}
        memory = {4.GB * task.attempt}
        time = {4.h * task.attempt}
    }
    withName: 'process2' {
        cpus = 1
        memory = 2.GB
        errorStrategy = 'finish'
    }
}
```






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
        -r 0.0.2\
        --batchfile $BATCHFILE \
        --output_folder $OUTPUT_FOLDER \
        --cpus_metaphlan2 2 \
        -with-report $PROJECT.html \
        -work-dir $WORK_DIR \
        -with-tower

```


