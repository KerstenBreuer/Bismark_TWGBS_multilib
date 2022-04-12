cwlVersion: v1.0
class: Workflow

requirements:
  ScatterFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  SubworkflowFeatureRequirement: {}
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  read1:
    type:
      type: array # array of libraries
      items: 
        type: array # array of lanes sequenced as part of one library
        items: File
  read2:
    type:
      type: array # array of libraries
      items: 
        type: array # array of lanes sequenced as part of one library
        items: File
  adapter1:
    type: string?
  adapter2:
    type: string?
  genome: 
    type: Directory
  threads:
    type: int
    default: 16
  trim_galore_quality:
    type: int
    default: 20
  trim_galore_rrbs:
    type: boolean
    default: false
  trim_galore_clip_r1:
    type: int?
  trim_galore_clip_r2:
    type: int?
  trim_galore_three_prime_clip_r1:
    type: int?
  trim_galore_three_prime_clip_r2:
    type: int?
  bismark_pbat:
    type: boolean
    default: false
  bismark_ignore:
    type: int
    default: 9
  bismark_ignore_r2:
    type: int
    default: 12
  bismark_ignore_3prime:
    type: int
    default: 9
  bismark_ignore_3prime_r2:
    type: int
    default: 2
  bismark_no_overlap:
    type: boolean
    default: true
  bismark_local:
    type: boolean
  non_directional:
    type: boolean
  dovetail:
    type: boolean


steps:
  proccess_library:
    run: "../workflow_modules/trim_map_merge_dedup.cwl"
    scatter: [read1, read2]
    scatterMethod: 'dotproduct'
    in:
      read1: read1
      read2: read2
      adapter1: adapter1
      adapter2: adapter2
      genome: genome
      threads: threads
      trim_galore_quality: trim_galore_quality
      trim_galore_rrbs: trim_galore_rrbs
      trim_galore_clip_r1: trim_galore_clip_r1
      trim_galore_clip_r2: trim_galore_clip_r2
      trim_galore_three_prime_clip_r1: trim_galore_three_prime_clip_r1
      trim_galore_three_prime_clip_r2: trim_galore_three_prime_clip_r2
      bismark_pbat: bismark_pbat
      bismark_local: bismark_local
      non_directional: non_directional
      dovetail: dovetail
    out:
      - qc_pretrim_fastqc_zip
      - qc_pretrim_fastqc_html
      - trim_log
      - read1_trimmed
      - read2_trimmed
      - qc_posttrim_fastqc_zip
      - qc_posttrim_fastqc_html
      - align_log
      - flagstats_post_mapping
      - merged_bam
      - dedup_reads
      - dedup_log
    
  merge_libraries:
    doc: merge and sort deduplicated reads of all libraries
    run: "../tools/samtools_merge_and_sort.cwl"
    in:
      bams:
        source: proccess_library/dedup_reads
      name_sort:
        valueFrom: $(true)
      threads: threads
    out:
       - bam_merged

  extract_methylation:
    run: "../tools/bismark_methylation_extractor.cwl"
    in:
      aligned_reads: merge_libraries/bam_merged
      no_overlap: bismark_no_overlap
      ignore: bismark_ignore
      ignore_r2: bismark_ignore_r2
      ignore_3prime: bismark_ignore_3prime
      ignore_3prime_r2: bismark_ignore_3prime_r2
      threads: threads
      genome: genome
    out:
      - methylation_calls_bedgraph
      - methylation_calls_bismark
      - mbias_report
      - splitting_report
      - genome_wide_methylation_report
      - context_specific_methylation_reports

outputs:
  qc_pretrim_fastqc_zip:
    type:
      type: array
      items:
        type: array
        items:
          type: array
          items: File
    outputSource: proccess_library/qc_pretrim_fastqc_zip
  qc_pretrim_fastqc_html:
    type:
      type: array
      items:
        type: array
        items:
          type: array
          items: File
    outputSource: proccess_library/qc_pretrim_fastqc_html
  trim_log:
    type:
      type: array
      items:
        type: array
        items:
          type: array
          items: File
    outputSource: proccess_library/trim_log
  read1_trimmed:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: proccess_library/read1_trimmed
  read2_trimmed:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: proccess_library/read2_trimmed
  qc_posttrim_fastqc_zip:
    type:
      type: array
      items:
        type: array
        items:
          type: array
          items: File
    outputSource: proccess_library/qc_posttrim_fastqc_zip
  qc_posttrim_fastqc_html:
    type:
      type: array
      items:
        type: array
        items:
          type: array
          items: File
    outputSource: proccess_library/qc_posttrim_fastqc_html
  align_log:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: proccess_library/align_log
  flagstats_post_mapping:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: proccess_library/flagstats_post_mapping
  dedup_log:
    type: File[]
    outputSource: proccess_library/dedup_log
  merged_bam:
    type: File
    outputSource: merge_libraries/bam_merged
  methylation_calls_bedgraph:
    type: File
    outputSource: extract_methylation/methylation_calls_bedgraph
  methylation_calls_bismark:
    type: File
    outputSource: extract_methylation/methylation_calls_bismark
  mbias_report:
    type: File
    outputSource: extract_methylation/mbias_report
  splitting_report:
    type: File
    outputSource: extract_methylation/splitting_report
  genome_wide_methylation_report:
    type: File
    outputSource: extract_methylation/genome_wide_methylation_report
  context_specific_methylation_reports:
    type: File[]
    outputSource: extract_methylation/context_specific_methylation_reports