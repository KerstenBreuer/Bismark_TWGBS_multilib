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
    doc: first reads belonging to the same library
    type:
      type: array
      items: File
  read2:
    doc: second reads belonging to the same library
    type:
      type: array
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
  bismark_local:
    type: boolean
  non_directional:
    type: boolean
  dovetail:
    type: boolean


steps:
  qc_pretrim:
    scatter: [read1, read2]
    scatterMethod: 'dotproduct'
    run: "../tools/fastqc.cwl"
    in:
      read1: read1
      read2: read2
    out:
      - fastqc_zip
      - fastqc_html

  trim:
    scatter: [read1, read2]
    scatterMethod: 'dotproduct'
    run: "../tools/trim_galore.cwl"
    in:
      read1: read1
      read2: read2
      adapter1: adapter1
      adapter2: adapter2
      quality: trim_galore_quality
      rrbs: trim_galore_rrbs
      clip_r1: trim_galore_clip_r1
      clip_r2: trim_galore_clip_r2
      three_prime_clip_r1: trim_galore_three_prime_clip_r1
      three_prime_clip_r2: trim_galore_three_prime_clip_r2
      threads: threads
    out:
      - log
      - read1_trimmed
      - read2_trimmed
  
  qc_posttrim:
    scatter: [read1, read2]
    scatterMethod: 'dotproduct'
    run: "../tools/fastqc.cwl"
    in:
      read1: trim/read1_trimmed
      read2: trim/read2_trimmed
    out:
      - fastqc_zip
      - fastqc_html
      
  align:
    scatter: [read1, read2]
    scatterMethod: 'dotproduct'
    run: "../tools/bismark_align.cwl"
    in:
      read1: trim/read1_trimmed
      read2: trim/read2_trimmed
      pbat: bismark_pbat
      bismark_local: bismark_local
      non_directional: non_directional
      dovetail: dovetail
      threads: threads
      genome: genome
    out:
      - aligned_reads
      - log

  qc_post_mapping:
    doc: |
      samtools flagstat
    run: "../tools/samtools_flagstat.cwl"
    scatter: [bam]
    scatterMethod: 'dotproduct'
    in:
      bam: align/aligned_reads
    out:
       - flagstat_output

  merge_and_sort:
    run: "../tools/samtools_merge_and_sort.cwl"
    in:
      bams:
        source: align/aligned_reads
      name_sort:
        valueFrom: $(true)
      threads: threads
    out:
       - bam_merged
       
  remove_duplicates:
    run: "../tools/bismark_deduplicate.cwl"
    in:
      aligned_reads: merge_and_sort/bam_merged
    out:
      - dedup_reads
      - log

outputs:
  qc_pretrim_fastqc_zip:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: qc_pretrim/fastqc_zip
  qc_pretrim_fastqc_html:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: qc_pretrim/fastqc_html

  trim_log:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: trim/log
  read1_trimmed:
    type: File[]
    outputSource: trim/read1_trimmed
  read2_trimmed:
    type: File[]
    outputSource: trim/read2_trimmed

  qc_posttrim_fastqc_zip:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: qc_posttrim/fastqc_zip
  qc_posttrim_fastqc_html:
    type:
      type: array
      items:
        type: array
        items: File
    outputSource: qc_posttrim/fastqc_html

  align_log:
    type: File[]
    outputSource: align/log
  flagstats_post_mapping:
    type: File[]
    outputSource: qc_post_mapping/flagstat_output

  merged_bam:
    type: File
    outputSource: merge_and_sort/bam_merged

  dedup_reads:
    type: File
    outputSource: remove_duplicates/dedup_reads
  dedup_log:
    type: File
    outputSource: remove_duplicates/log