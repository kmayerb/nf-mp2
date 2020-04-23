params.output_folder  = "./nextflow-publishDir"
params.cpus_metaphlan2 = 1 
params.read_type = 'PE'

// PRIMARY INPUT CHANNEL IS DEFINED BY A BATCHFILE
// THIS WORKFLOW IS DESIGNED FOR Paired-End .gz fastq file pairs

Channel.from(file(params.batchfile))
         .splitCsv(header: true, sep: ",")
         .map { sample ->
         [sample.name, file(sample.fastq1), file(sample.fastq2)]}
         .set{ input_channel}


process metaphlan2 {

	tag "PE .fq -> MetaPhlAn v.2.9.20 -> rel_ab_w_read_stats"

	// This process only is designed for that are Paired-End .gz fastq file pairs.
	
	// INPUTS:

	// sample_name
	// fastq1
	// fastq2

	// OUTPUTS:
	
	// set "${sample_name}.rel_ab_w_read_stats_ingore_unknown.txt") -->  metaphlan2_9_20_tabular_outputs_ignore_unknowns
	// set "${sample_name}.rel_ab_w_read_stats_use_unknown.txt")    -->  into metaphlan2_9_20_tabular_outputs_use_unknowns
	// set "${sample_name}.bowtie2.bz2")                            -->  metaphlan2_9_20_bowtie_outputs
	// set "${sample_name}.metaphlan2.log.txt") into logs           -->  logs

	// NOTES:
	// We explicitly keep the intermediate bowtie outputs as well as results tables. 
	// Once generated we can comeback and use these for marker level analysis

	
	// local version for testing only
	// MetaPhlAn version 2.9.20 (14 Aug 2019)
	// container "metaphlan2db:0.0.1"


	// For testing on Amazon Batch:
		// quay.io version for AWS Batch (it's 4.3 GB but 
		// it contains the Database pre-compiled and bowtie indexed to save time)
		// MetaPhlAn version 2.9.20 (14 Aug 2019)
	
	when: params.read_type == "PE" 	
	
	container "quay.io/kmayerb/nf-mp2-test:0.0.1"

	input:
	set sample_name, file(fastq1), file(fastq2) from input_channel

	output:
	
	// e.g., CC40GACXX_8_TAGGCATG_CTCTCTAT.bowtie2.bz2 
	file("metaphlan_results/${sample_name}.rel_ab_w_read_stats_ignore_unknown.txt") into metaphlan2_9_20_tabular_outputs_ignore_unknowns
	file("metaphlan_results/${sample_name}.rel_ab_w_read_stats_use_unknown.txt") into metaphlan2_9_20_tabular_outputs_use_unknowns
	file("bowtie_outputs/${sample_name}.bowtie2.bz2") into metaphlan2_9_20_bowtie_outputs
	file("metaphlan2_logs/${sample_name}.metaphlan2.log.txt") into logs
	
	publishDir params.output_folder
	
	script:
	"""
	mkdir metaphlan2_logs
	mkdir metaphlan_results

	uname > metaphlan2_logs/${sample_name}.metaphlan2.log.txt
	metaphlan2.py -v >> metaphlan2_logs/${sample_name}.metaphlan2.log.txt
	
	gunzip -c ${fastq1} > ${sample_name}.R1.fq
	gunzip -c ${fastq2} > ${sample_name}.R2.fq

	mkdir bowtie_outputs

	metaphlan2.py ${sample_name}.R1.fq,${sample_name}.R2.fq --input_type fastq --bowtie2out bowtie_outputs/${sample_name}.bowtie2.bz2 --nproc ${params.cpus_metaphlan2}
	
	metaphlan2.py -t rel_ab_w_read_stats bowtie_outputs/${sample_name}.bowtie2.bz2 --input_type bowtie2out -o metaphlan_results/${sample_name}.rel_ab_w_read_stats_ignore_unknown.txt --unknown_estimation
	metaphlan2.py -t rel_ab_w_read_stats bowtie_outputs/${sample_name}.bowtie2.bz2 --input_type bowtie2out -o metaphlan_results/${sample_name}.rel_ab_w_read_stats_use_unknown.txt 
	"""
	}

process metaphlan2_single_read {

	tag "Single Read .fq -> MetaPhlAn v.2.9.20 -> rel_ab_w_read_stats"

	when: params.read_type == "SE" 	

	container "quay.io/kmayerb/nf-mp2-test:0.0.1"

	input:
	set sample_name, file(fastq1) from input_channel

	output:
	file("metaphlan_results/${sample_name}.rel_ab_w_read_stats_ignore_unknown.txt") into metaphlan2_9_20_tabular_outputs_ignore_unknowns
	file("metaphlan_results/${sample_name}.rel_ab_w_read_stats_use_unknown.txt") into metaphlan2_9_20_tabular_outputs_use_unknowns
	file("bowtie_outputs/${sample_name}.bowtie2.bz2") into metaphlan2_9_20_bowtie_outputs
	file("metaphlan2_logs/${sample_name}.metaphlan2.log.txt") into logs
	
	publishDir params.output_folder
	
	script:
	"""
	mkdir metaphlan2_logs
	mkdir metaphlan_results

	uname > metaphlan2_logs/${sample_name}.metaphlan2.log.txt
	metaphlan2.py -v >> metaphlan2_logs/${sample_name}.metaphlan2.log.txt
	
	gunzip -c ${fastq1} > ${sample_name}.R1.fq

	mkdir bowtie_outputs

	metaphlan2.py ${sample_name}.R1.fq --input_type fastq --bowtie2out bowtie_outputs/${sample_name}.bowtie2.bz2 --nproc ${params.cpus_metaphlan2}
	
	metaphlan2.py -t rel_ab_w_read_stats bowtie_outputs/${sample_name}.bowtie2.bz2 --input_type bowtie2out -o metaphlan_results/${sample_name}.rel_ab_w_read_stats_ignore_unknown.txt --unknown_estimation
	metaphlan2.py -t rel_ab_w_read_stats bowtie_outputs/${sample_name}.bowtie2.bz2 --input_type bowtie2out -o metaphlan_results/${sample_name}.rel_ab_w_read_stats_use_unknown.txt 
	"""
}


process merge_metaphlan_tables {

	tag "Merge Table From: MetaPhlAn v.2.9.20"

	container "quay.io/kmayerb/aws-batch-conda-py3:0.0.1"

	input:
	file ign_file_list from metaphlan2_9_20_tabular_outputs_ignore_unknowns.collect()
    file use_file_list from metaphlan2_9_20_tabular_outputs_use_unknowns.collect()

	//file('*use_unknown.txt') from metaphlan2_9_20_tabular_outputs_use_unknowns.collect()

	output:
	file("ignore_unknowns/merged_readcounts_table_ignore_unknown.txt") into final_outputs
	file("use_unknowns/merged_readcounts_table_use_unknown.txt") into final_outputs2
	file("ignore_unknowns/merged_rabundances_table_ignore_unknown.txt") into final_outputs3
	file("use_unknowns/merged_rabundances_table_use_unknown.txt") into final_outputs4
	file("ignore_unknowns/merged_coverage_table_ignore_unknown.txt") into final_output5
	file("use_unknowns/merged_coverage_table_use_unknown.txt") into final_output6

	publishDir params.output_folder
	
	// here we can pull a specific script. I had to do this because there was a bug in 2.9.20 version of MetaPhlAn and I wanted 
	// to add custom functionality (--key estimated_number_of_reads_from_the_clade) rather than relative abundance
	/// specific commit https://github.com/kmayerb/aws-batch-conda-py3/blob/ca57485adc0b60c7136b3cd7a702c1a7c7e16113/utilities/my_merge_metaphlan_tables.py
	
	// originally we pulled a wget in the script https://raw.githubusercontent.com/kmayerb/aws-batch-conda-py3/master/utilities/my_merge_metaphlan_tables.py
	// however, this would be subject to change. This latest file was included in the docker container 
	// so behavior is pinned to a specific container tag.
	script:
	"""
	mkdir ignore_unknowns
	mkdir use_unknowns

	python /my_merge_metaphlan_tables.py --key estimated_number_of_reads_from_the_clade ${ign_file_list} > ignore_unknowns/merged_readcounts_table_ignore_unknown.txt
	python /my_merge_metaphlan_tables.py --key estimated_number_of_reads_from_the_clade ${use_file_list} > use_unknowns/merged_readcounts_table_use_unknown.txt
	
	python /my_merge_metaphlan_tables.py --key relative_abundance ${ign_file_list} > ignore_unknowns/merged_rabundances_table_ignore_unknown.txt
	python /my_merge_metaphlan_tables.py --key relative_abundance ${ign_file_list} > use_unknowns/merged_rabundances_table_use_unknown.txt
	
	python /my_merge_metaphlan_tables.py --key coverage ${ign_file_list} > ignore_unknowns/merged_coverage_table_ignore_unknown.txt
	python /my_merge_metaphlan_tables.py --key coverage ${ign_file_list} > use_unknowns/merged_coverage_table_use_unknown.txt
	"""
}




