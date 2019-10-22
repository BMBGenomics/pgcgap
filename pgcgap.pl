#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Getopt::Std;
use Bio::SeqIO;
use Data::Dumper;
use File::Tee qw(tee);
use Cwd;

my %options;

=head1 NAME

PGCGAP

=head1 DESCRIPTION

The prokaryotic genomics and comparative genomics analysis pipeline

=head1 AUTHOR

Hualin Liu

=head1 CONTACT

liaochenlanruo@webmail.hzau.edu.cn

=head1 USAGE

  $ pgcgap [Fuctions] [Options]

  The main usage is as follows, visit the official website for step by step examples: https://liaochenlanruo.github.io/pgcgap/

  Example 1: Perform all functions for pair-end reads. For the sake of flexibility, the "VAR" function needs to be added separately

             pgcgap --All --platform illumina --ReadsPath <PATH> --reads1 <reads1 suffix> --reads2 <reads2 suffix> --suffix_len <INT> --kmmer <INT> --genus <STRING> --species <STRING> --codon <INT> --strain_num <INT> --threads <INT> --VAR --refgbk <full path> --qualtype <STRING>

  Example 2: Conduct pair-end reads assembly

             pgcgap --Assemble --platform illumina --ReadsPath <PATH> --reads1 <reads1 suffix> --reads2 <reads2 suffix> --suffix_len <INT> --kmmer <INT> --threads <INT>

  Example 3: Conduct PacBio/Oxford reads assembly

             pgcgap --Assemble --platform [pacbio|oxford] --ReadsPath <PATH> --reads1 <reads suffix> --suffix_len <INT> --genomeSize <Float> --threads <INT>

  Example 4: Conduct gene prediction and annotation

             pgcgap --Annotate --scafPath <PATH> --Scaf_suffix <STRING> --genus <STRING> --species <STRING> --codon <INT> --threads <INT>

  Example 5: Constructing the phylogenetic trees of single-copy core proteins and core SNPs

             pgcgap --CoreTree --CDsPath <PATH> --AAsPath <PATH> --codon <INT> --strain_num <INT> --threads <INT>

  Example 6: Constructing single-copy core protein tree only.

             pgcgap --CoreTree --CDsPath NO --AAsPath <PATH> --codon <INT> --strain_num <INT> --threads <INT>

  Example 7: Conduct pan-genome analysis

             pgcgap --Pan --codon <INT> --strain_num <INT> --threads <INT> --GffPath <PATH>

  Example 8: Inference of orthologous gene groups

             pgcgap --OrthoF --threads <INT> --AAsPath <PATH>

  Example 9: Compute whole-genome Average Nucleotide Identity (ANI)

             pgcgap --ANI --threads <INT> --queryL <FILE> --refL <FILE> --ANIO <STRING> --Scaf_suffix <STRING>

  Example 10: Genome and metagenome similarity estimation using MinHash

             pgcgap --MASH --scafPath <PATH> --Scaf_suffix <STRING>

  Example 11: Run COG annotation for each strain

              pgcgap --pCOG --strain_num <INT> --threads <INT> --AAsPath <PATH>

  Example 12: Variants calling and phylogenetic tree construction based on reference genome

             pgcgap --VAR --threads <INT> --refgbk <FILE with full path> --ReadsPath <PATH> --reads1 <STRING> --reads2 <STRING> --suffix_len <INT> --strain_num <INT> --qualtype <STRING> 

=head1 OPTIONS

=over 30

=item B<[--help]>

Print the help message and exit

=back

=cut

$options{'help|h|?'} = \( my $opt_help );

=over 30

=item B<[--version]>

Show version number of PGCGAP and exit

=back

=cut

$options{'version'} = \( my $opt_version );

=over 30

=item B<[--check-external-programs]>

Check if all of the required external programs can be found and are executable, then exit

=back

=cut

$options{'check-external-programs'} = \( my $opt_check_external_programs = 0 );

=over 30

=item B<[--setup-COGdb]>

Setup COG database. Users should execute "pgcgap --setup-COGdb" after first installation of pgcgap

=back

=cut

$options{'setup-COGdb'} = \( my $opt_setup_COGdb );

=head2 *********************************************************** Fuctions ***********************************************************

=for text



=over 30

=item B<[--All]>

Perform Assemble, Annotate, CoreTree, Pan, OrthoF, ANI and pCOG functions with one command

=back

=cut

$options{'All'} = \(my $opt_All);

=over 30

=item B<[--Assemble]>

Assemble reads into contigs

=back

=cut

$options{'Assemble'} = \(my $opt_Assemble);

=over 30

=item B<[--Annotate]>

Genome annotation

=back

=cut

$options{'Annotate'} = \(my $opt_Annotate);

=over 30

=item B<[--CoreTree]>

Construct single-copy core proteins tree and core SNPs tree

=back

=cut

$options{'CoreTree'} = \(my $opt_CoreTree);

=over 30

=item B<[--Pan]>

Run "roary" pan genome pipeline with gff3 files, and construct a phylogenetic tree with the sing-copy core proteins called by roary

=back

=cut

$options{'Pan'} = \(my $opt_Pan);

=over 30

=item B<[--OrthoF]>

Identify orthologous protein sequence families

=back

=cut

$options{'OrthoF'} = \(my $opt_OrthoF);

=over 30

=item B<[--ANI]>

Compute whole-genome Average Nucleotide Identity ( ANI )

=back

=cut

$options{'ANI'} = \(my $opt_ANI);

=over 30

=item B<[--MASH]>

Genome and metagenome similarity estimation using MinHash

=back

=cut

$options{'MASH'} = \(my $opt_MASH);

=over 30

=item B<[--pCOG]>

Run COG annotation for each strain (*.faa), and generate a table containing the relative abundance of each flag for all strains

=back

=cut

$options{'pCOG'} = \(my $opt_pCOG);

=over 30

=item B<[--VAR]>

Rapid haploid variant calling and core genome alignment

=back

=cut

$options{'VAR'} = \(my $opt_VAR);

=head2 ******************************************************** Global Options ********************************************************

=for text



=over 30

=item B<[--strain_num (INT)]>

I<[Required by "--All", "--CoreTree", "--Pan", "--VAR" and "--pCOG"]> The total number of strains used for analysis, not including the reference genome

=back

=cut

$options{'strain_num=i'} = \( my $opt_strain_num );

=over 30

=item B<[--ReadsPath (PATH)]>

I<[Required by "--All", "--Assemble" and "--VAR"]> Reads of all strains as file paths ( Default ./Reads/Illumina )

=back

=cut

$options{'ReadsPath=s'} = \( my $opt_ReadsPath = "./Reads/Illumina" );

=over 30

=item B<[--scafPath (PATH)]>

I<[Required by "--All", "--Annotate" and "--MASH"]> Path for contigs/scaffolds ( Default "Results/Assembles/Scaf/Illumina" )

=back

=cut

$options{'scafPath=s'} = \(my $opt_scafPath = "Results/Assembles/Scaf/Illumina");

=over 30

=item B<[--AAsPath (PATH)]>

I<[Required by "--All", "--CoreTree", "--OrthoF" and "--pCOG"]> Amino acids of all strains as fasta file paths, ( Default "./Results/Annotations/AAs" )

=back

=cut

$options{'AAsPath=s'} = \( my $opt_AAsPath = "./Results/Annotations/AAs" );

=over 30

=item B<[--reads1 (STRING)]>

I<[Required by "--All", "--Assemble" and "--VAR"]> The suffix name of reads 1 ( for example: if the name of reads 1 is "YBT-1520_L1_I050.R1.clean.fastq.gz", "YBT-1520" is the strain same, so the suffix name should be ".R1.clean.fastq.gz" )

=back

=cut

$options{'reads1=s'} = \(my $opt_reads1);

=over 30

=item B<[--reads2 (STRING)]>

I<[Required by "--All", "--Assemble" and "--VAR"]> The suffix name of reads 2( for example: if the name of reads 2 is "YBT-1520_2.fq", the suffix name should be _2.fq" )

=back

=cut

$options{'reads2=s'} = \(my $opt_reads2);

=over 30

=item B<[--Scaf_suffix (STRING)]>

The suffix of scaffolds or genomes [Required by "--All", "--Annotate" "MASH" and "--ANI"] Here, "-8.fa" for Illumina data, ".contigs.fasta" for PacBio data and Oxford data. Users can also fill in other suffixes according to the actual situation ( Default -8.fa )

=back

=cut

$options{'Scaf_suffix=s'} = \( my $opt_Scaf_suffix = "-8.fa" );

=over 30

=item B<[--codon (INT)]>

I<[Required by "--All", "--Annotate", "--CoreTree" and "--Pan"]> Translation table ( Default 11 )

=back

=cut

$options{'codon=i'} = \( my $opt_codon = 11 );

=over 30

 1   Universal code
 2   Vertebrate mitochondrial code
 3   Yeast mitochondrial code
 4   Mold, Protozoan, and Coelenterate Mitochondrial code and Mycoplasma/Spiroplasma code
 5   Invertebrate mitochondrial
 6   Ciliate, Dasycladacean and Hexamita nuclear code
 9   Echinoderm and Flatworm mitochondrial code
 10  Euplotid nuclear code
 11  Bacterial, archaeal and plant plastid code ( Default )
 12  Alternative yeast nuclear code
 13  Ascidian mitochondrial code
 14  Alternative flatworm mitochondrial code
 15  Blepharisma nuclear code
 16  Chlorophycean mitochondrial code
 21  Trematode mitochondrial code
 22  Scenedesmus obliquus mitochondrial code
 23  Thraustochytrium mitochondrial code

=back

=cut

=over 30

=item B<[--suffix_len (INT)]>

I<[Required by "--All", "--Assemble" and "--VAR"]> B<(Strongly recommended)> The suffix length of the reads file, that is the length of the reads name minus the length of the strain name. For example the --suffix_len of "YBT-1520_L1_I050.R1.clean.fastq.gz" is 26 ( "YBT-1520" is the strain name ) ( Default 0 )

=back

=cut

$options{'suffix_len=i'} = \(my $opt_suffix_len = 0);

=over 30

=item B<[--logs (STRING)]>

Name of the log file ( Default Logs.txt )

=back

=cut

$options{'logs=s'} = \( my $opt_logs = "Logs.txt" );

=over 30

=item B<[--threads (INT)]>

Number of threads to be used ( Default 4 )

=back

=cut

$options{'threads=i'} = \( my $opt_threads = 4 );

=head2 ******************************************************** Local Options *********************************************************

=for text



=head3 ======================= Options of "--Assemble" for reads assembly ============================

=for text



=begin html

If you use the results of "--Assemble" function in your work, please also cite one of the following:

</br>

</br>Shaun D Jackman, Benjamin P Vandervalk, Hamid Mohamadi, Justin Chu, Sarah Yeo, S Austin Hammond, Golnaz Jahesh, Hamza Khan, Lauren Coombe, Ren&eacute; L Warren, and Inanc Birol (2017). ABySS 2.0: Resource-efficient assembly of large genomes using a Bloom filter. Genome research, 27(5), 768-777. doi:10.1101/gr.214346.116

</br>

</br>Koren S, Walenz BP, Berlin K, Miller JR, Phillippy AM. Canu: scalable and accurate long-read assembly via adaptive k-mer weighting and repeat separation. Genome Research. (2017).

=end html

=over 30

=item B<[--platform (STRING)]>

I<[Required]> Sequencing Platform, "illumina", "pacbio" and "oxford" available ( Default illumina )

=back

=cut

$options{'platform=s'} = \(my $opt_platform = "illumina");

=over 30

=item B<[--kmmer (INT)]>

I<[Required]> k-mer size for genome assembly of Illumina data ( Default 81 )

=back

=cut

$options{'kmmer=i'} = \(my $opt_kmmer = 81);

=over 30

=item B<[--genomeSize (FLOAT)]>

I<[Required]> An estimate of the size of the genome. Common suffices are allowed, for example, 3.7m or 2.8g. Needed by PacBio data and Oxford data ( Default Unset )

=back

=cut

$options{'genomeSize=s'} = \(my $opt_genomeSize);

=head3 ======================= Options of "--Annotate" for genome annotation ============================

=for text



=begin html

If you use the results of "--Assemble" function in your work, please also cite:

</br>

</br>Seemann T. Prokka: rapid prokaryotic genome annotation. Bioinformatics 2014 Jul 15;30(14):2068-9. PMID:24642063

=end html

=over 30

=item B<[--genus (STRING)]>

Genus name of the strain ( Default "NA" )

=back

=cut

$options{'genus=s'} = \(my $opt_genus = "NA");

=over 30

=item B<[--species (STRING)]>

Species name of the strain ( Default "NA" )

=back

=cut

$options{'species=s'} = \(my $opt_species = "NA");

=head3 ======================================== Options for "--CoreTree" constructing ================================================

=for text



=begin html

If you use the results of "--CoreTree" function in your work, please also cite:

</br>

</br>CD-HIT: a fast program for clustering and comparing large sets of protein or nucleotide sequences", Weizhong Li & Adam Godzik. Bioinformatics, (2006) 22:1658-1659

</br>

</br>CD-HIT: accelerated for clustering the next generation sequencing data", Limin Fu, Beifang Niu, Zhengwei Zhu, Sitao Wu & Weizhong Li. Bioinformatics, (2012) 28:3150-3152

</br>

</br>Katoh K, Misawa K, Kuma K, Miyata T. MAFFT: a novel method for rapid multiple sequence alignment based on fast Fourier transform. Nucleic Acids Res. 2002;30(14):3059-3066

</br>

</br>Price MN, Dehal PS, Arkin AP. FastTree 2--approximately maximum-likelihood trees for large alignments. PLoS One. 2010;5(3):e9490. Published 2010 Mar 10. doi:10.1371/journal.pone.0009490

</br>

</br>Mikita Suyama, David Torrents, and Peer Bork (2006) PAL2NAL: robust conversion of protein sequence alignments into the corresponding codon alignments. Nucleic Acids Res. 34, W609-W612

</br>

</br>"SNP-sites: rapid efficient extraction of SNPs from multi-FASTA alignments", Andrew J. Page, Ben Taylor, Aidan J. Delaney, Jorge Soares, Torsten Seemann, Jacqueline A. Keane, Simon R. Harris, Microbial Genomics 2(4), (2016)

</br>

</br>Croucher N. J., Page A. J., Connor T. R., Delaney A. J., Keane J. A., Bentley S. D., Parkhill J., Harris S.R. "Rapid phylogenetic analysis of large samples of recombinant bacterial whole genome sequences using Gubbins". Nucleic Acids Res. 2015 Feb 18;43(3):e15. doi: 10.1093/nar/gku1196

=end html

=over 30

=item B<[--CDsPath (PATH)]>

I<[Required]> CDs of all strains as fasta file paths, ( Default "./Results/Annotations/CDs" )

=back

=cut

$options{'CDsPath=s'} = \( my $opt_CDsPath = "./Results/Annotations/CDs" );

=over 30

=item B<[-c (FLOAT)]>

Sequence identity threshold, ( Default 0.5)

=back

=cut

$options{'c=f'} = \( my $opt_c = 0.5 );

=over 30

=item B<[-n (INT)]>

Word_length, -n 2 for thresholds 0.4-0.5, -n 3 for thresholds 0.5-0.6, -n 4 for thresholds 0.6-0.7, -n 5 for thresholds 0.7-1.0 ( Default 2 )

=back

=cut

$options{'n=i'} = \( my $opt_n = 2 );

=over 30

=item B<[-G (INT)]>

Use global (set to 1) or local (set to 0) sequence identity, ( Default 0 )

=back

=cut

$options{'G=i'} = \( my $opt_G = 0 );

=over 30

=item B<[-t (INT)]>

Tolerance for redundance ( Default 0 )

=back

=cut

$options{'t=i'} = \( my $opt_t = 0 );

=over 30

=item B<[-aL (FLOAT)]>

Alignment coverage for the longer sequence. If set to 0.9, the alignment must covers 90% of the sequence ( Default 0.5 )

=back

=cut

$options{'aL=f'} = \( my $opt_aL = 0.5 );

=over 30

=item B<[-aS (FLOAT)]>

Alignment coverage for the shorter sequence. If set to 0.9, the alignment must covers 90% of the sequence ( Default 0.7 )

=back

=cut

$options{'aS=f'} = \( my $opt_aS = 0.7 );

=over 30

=item B<[-g (INT)]>

If set to 0, a sequence is clustered to the first cluster that meet the threshold (fast cluster). If set to 1, the program will cluster it into the most similar cluster that meet the threshold (accurate but slow mode, Default 1)

=back

=cut

$options{'g=i'} = \( my $opt_g = 1 );

=over 30

=item B<[-d (INT)]>

length of description in .clstr file. if set to 0, it takes the fasta defline and stops at first space ( Default 0 )

=back

=cut

$options{'d=i'} = \( my $opt_d = 0 );

=head3 ===================================== Options for "--Pan" analysis ============================================================

=for text



=begin html

If you use the results of "--Pan" function in your work, please also cite:

</br>

</br>"Roary: Rapid large-scale prokaryote pan genome analysis", Andrew J. Page, Carla A. Cummins, Martin Hunt, Vanessa K. Wong, Sandra Reuter, Matthew T. G. Holden, Maria Fookes, Daniel Falush, Jacqueline A. Keane, Julian Parkhill, Bioinformatics, (2015). doi: http://dx.doi.org/10.1093/bioinformatics/btv421

=end html

=over 30

=item B<[--GffPath (PATH)]>

I<[Required]> Gff files of all strains as paths ( Default "./Results/Annotations/GFF" )

=back

=cut

$options{'GffPath=s'} = \( my $opt_GffPath = "./Results/Annotations/GFF" );

=head3 ===================================== Options for "--OrthoF" analysis =========================================================

=for text



=begin html

If you use the results of "--OrthoF" function in your work, please also cite:

</br>

</br>Emms, D.M. and Kelly, S. (2018) OrthoFinder2: fast and accurate phylogenomic orthology analysis from gene sequences. bioRxiv

=end html

=over 30

=item B<[--Sprogram (STRING)]>

Sequence search program, Options: blast, mmseqs, blast_gz, diamond ( Default blast )

=back

=cut

$options{'Sprogram=s'} = \( my $opt_Sprogram = "blast" );

=head3 ===================================== Options for "--ANI" analysis ============================================================

=for text



=begin html

If you use the results of "--ANI" function in your work, please also cite:

</br>

</br>Jain C, Rodriguez-R LM, Phillippy AM, Konstantinidis KT, Aluru S. High throughput ANI analysis of 90K prokaryotic genomes reveals clear species boundaries. Nat Commun. 2018;9(1):5114. Published 2018 Nov 30. doi:10.1038/s41467-018-07641-9

=end html

=over 30

=item B<[--queryL (FILE)]>

I<[Required]> The file containing full paths to query genomes, one per line ( Default scaf.list )

=back

=cut

$options{'queryL=s'} = \( my $opt_queryL = "scaf.list" );

=over 30

=item B<[--refL (FILE)]>

I<[Required]> The file containing full paths to reference genomes, one per line. ( Default scaf.list )

=back

=cut

$options{'refL=s'} = \( my $opt_refL = "scaf.list" );

=over 30

=item B<[--ANIO (FILE)]>

The name of output file ( Default "Results/ANI/ANIs" )

=back

=cut

$options{'ANIO=s'} = \( my $opt_ANIO = "Results/ANI/ANIs" );

=head3 ===================================== Options for "--VAR" analysis ============================================================

=for text



=begin html

If you use the results of "--VAR" function in your work, please also cite:

</br>

</br>Joshi NA, Fass JN. (2011). Sickle: A sliding-window, adaptive, quality-based trimming tool for FastQ files (Version 1.33) [Software].  Available at https://github.com/najoshi/sickle.

</br>

</br>Seemann T (2015) snippy: fast bacterial variant calling from NGS reads https://github.com/tseemann/snippy.

</br>

</br>Croucher N. J., Page A. J., Connor T. R., Delaney A. J., Keane J. A., Bentley S. D., Parkhill J., Harris S.R. "Rapid phylogenetic analysis of large samples of recombinant bacterial whole genome sequences using Gubbins". Nucleic Acids Res. 2015 Feb 18;43(3):e15. doi: 10.1093/nar/gku1196

</br>

=end html

=over 30

=item B<[--refgbk (FILE)]>

I<[Required]> The B<full path and name> of reference genome in GENBANK format ( B<recommended> ), fasta format is also OK. For example: "/mnt/g/test/ref.gbk"

=back

=cut

$options{'refgbk=s'} = \( my $opt_refgbk );

=over 30

=item B<[--qualtype (STRING)]>

I<[Required]> Type of quality values (solexa (CASAVA < 1.3), illumina (CASAVA 1.3 to 1.7), sanger (which is CASAVA >= 1.8)). ( Default sanger )

=back

=cut

$options{'qualtype=s'} = \(my $opt_qualtype = "sanger");

=over 30

=item B<[--qual (INT)]>

Threshold for trimming based on average quality in a window. ( Default 20 )

=back

=cut

$options{'qual=i'} = \(my $opt_qual = "20");

=over 30

=item B<[--length (INT)]>

Threshold to keep a read based on length after trimming. ( Default 20 )

=back

=cut

$options{'length=i'} = \(my $opt_length = "20");

=over 30

=item B<[--mincov (INT)]>

The minimum number of reads covering a site to be considered ( Default 10 )

=back

=cut

$options{'mincov=i'} = \(my $opt_mincov = "10");

=over 30

=item B<[--minfrac (FLOAT)]>

The minimum proportion of those reads which must differ from the reference ( Default 0.9 )

=back

=cut

$options{'minfrac=f'} = \(my $opt_minfrac = "0.9");

=over 30

=item B<[--minqual (INT)]>

The minimum VCF variant call "quality" ( Default 100 )

=back

=cut

$options{'minqual=i'} = \(my $opt_minqual = "100");

=over 30

=item B<[--ram (INT)]>

Try and keep RAM under this many GB ( Default 8 )

=back

=cut

$options{'ram=i'} = \(my $opt_ram = "8");

=over 30

=item B<[--tree_builder (STRING)]>

Application to use for tree building [raxml|fasttree|hybrid] ( Default fasttree )

=back

=cut

$options{'tree_builder=s'} = \(my $opt_tree_builder = "fasttree");

=over 30

=item B<[--iterations (INT)]>

Maximum No. of iterations for gubbins ( Default 5 )

=back

=cut

$options{'iterations=i'} = \(my $opt_iterations = "5");

=head2 ************************************* Paths of external programs ***************************************************************

=for text



=over 1

Not needed if they were in the environment variables path. Users can check with the "--check-external-programs" option for the essential programs

=back

=cut

=over 30

=item B<[--abyss-bin (PATH)]>

Path to abyss binary file. Default tries if abyss is in PATH;

=back

=cut

$options{'abyss-bin=s'} = \( my $opt_abyss_bin = `which abyss-pe 2>/dev/null` );

=over 30

=item B<[--canu-bin (PATH)]>

Path to canu binary file. Default tries if canu is in PATH;

=back

=cut

$options{'canu-bin=s'} = \( my $opt_canu_bin = `which canu 2>/dev/null` );

=over 30

=item B<[--prodigal-bin (PATH)]>

Path to prodigal binary file. Default tries if prodigal is in PATH;

=back

=cut

$options{'prodigal-bin=s'} = \( my $opt_prodigal_bin = `which prodigal 2>/dev/null` );

=over 30

=item B<[--prokka-bin (PATH)]>

Path to prokka binary file. Default tries if prokka is in PATH;

=back

=cut

$options{'prokka-bin=s'} = \( my $opt_prokka_bin = `which prokka 2>/dev/null` );

=over 30

=item B<[--cd-hit-bin (PATH)]>

Path to cd-hit binary file. Default tries if cd-hit is in PATH;

=back

=cut

$options{'cd-hit-bin=s'} = \( my $opt_cdhit_bin = `which cd-hit 2>/dev/null` );

=over 30

=item B<[--mafft-bin (PATH)]>

Path to mafft binary file. Default tries if mafft is in PATH;

=back

=cut

$options{'mafft-bin=s'} = \( my $opt_mafft_bin = `which mafft 2>/dev/null` );

=over 30

=item B<[--fasttree-bin (PATH)]>

Path to the fasttree binary file. Default tries if fasttree is in PATH;

=back

=cut

$options{'fasttree-bin=s'} = \( my $opt_fasttree_bin = `which fasttree 2>/dev/null` );

=over 30

=item B<[--pal2nal-bin (PATH)]>

Path to the pal2nal.pl binary file. Default tries if pal2nal.pl is in PATH;

=back

=cut

$options{'pal2nal-bin=s'} = \( my $opt_pal2nal_bin = `which pal2nal.pl 2>/dev/null` );

=over 30

=item B<[--snp-sites-bin (PATH)]>

Path to the snp-sites binary file. Default tries if snp-sites is in PATH;

=back

=cut

$options{'snp-sites-bin=s'} = \( my $opt_snpsites_bin = `which snp-sites 2>/dev/null` );

=over 30

=item B<[--roary-bin (PATH)]>

Path to the roary binary file. Default tries if roary is in PATH;

=back

=cut

$options{'roary-bin=s'} = \( my $opt_roary_bin = `which roary 2>/dev/null` );

=over 30

=item B<[--orthofinder-bin (PATH)]>

Path to the orthofinder binary file. Default tries if orthofinder is in PATH;

=back

=cut

$options{'orthofinder-bin=s'} = \( my $opt_orthofinder_bin = `which orthofinder 2>/dev/null` );

=over 30

=item B<[--fastANI-bin (PATH)]>

Path to the fastANI binary file. Default tries if fastANI is in PATH;

=back

=cut

$options{'fastANI-bin=s'} = \( my $opt_fastANI_bin = `which fastANI 2>/dev/null` );

=over 30

=item B<[--gubbins-bin (PATH)]>

Path to the run_gubbins.py binary file. Default tries if run_gubbins.py is in PATH;

=back

=cut

$options{'gubbins-bin=s'} = \( my $opt_gubbins_bin = `which run_gubbins.py 2>/dev/null` );

=over 30

=item B<[--snippy-bin (PATH)]>

Path to the snippy binary file. Default tries if snippy is in PATH;

=back

=cut

$options{'snippy-bin=s'} = \( my $opt_snippy_bin = `which snippy 2>/dev/null` );

=over 30

=item B<[--sickle-bin (PATH)]>

Path to the sickle-trim binary file. Default tries if sickle is in PATH;

=back

=cut

$options{'sickle-bin=s'} = \( my $opt_sickle_bin = `which sickle 2>/dev/null` );

=over 30

=item B<[--mash-bin (PATH)]>

Path to mash binary file. Default tries if mash is in PATH;

=back

=cut

$options{'mash-bin=s'} = \( my $opt_mash_bin = `which mash 2>/dev/null` );

=begin text

  ############################################ About The Software ##############################################################################

=for text



    Software: PGCGAP - The prokaryotic genomics and comparative genomics analysis pipeline


    Author: Hualin Liu


    Contact: liaochenlanruo@webmail.hzau.edu.cn


    Citation: 


=end text

=cut

tee STDOUT, ">>$opt_logs";

GetOptions(%options) or pod2usage("Try '$0 --help' for more information.");

if($opt_version){
    print "PGCGAP version: 1.0.9\n";
    exit 0;
}

#pod2usage( -verbose => 1 ) if $opt_help;
pod2usage(1) if ($opt_help);
#pod2usage(1) if ($#ARGV == -1);
chomp($opt_sickle_bin, $opt_snippy_bin, $opt_gubbins_bin, $opt_abyss_bin, $opt_canu_bin, $opt_prodigal_bin, $opt_prokka_bin, $opt_cdhit_bin, $opt_mafft_bin, $opt_fasttree_bin, $opt_snpsites_bin, $opt_pal2nal_bin, $opt_roary_bin, $opt_orthofinder_bin, $opt_fastANI_bin, $opt_mash_bin);
check_external_programs() if($opt_check_external_programs);
pod2usage( -msg => 'cd-hit not in $PATH and binary not specified use --cd-hit-bin', -verbose => 0, -exitval => 1 ) unless ($opt_cdhit_bin);
pod2usage( -msg => 'mafft not in $PATH and binary not specified use --mafft-bin', -verbose => 0, -exitval => 1 ) unless ($opt_mafft_bin);
pod2usage( -msg => 'fasttree not in $PATH and binary not specified use --fasttree-bin', -verbose => 0, -exitval => 1 ) unless ($opt_fasttree_bin);
pod2usage( -msg => 'snp-sites not in $PATH and binary not specified use --snp-sites-bin', -verbose => 0, -exitval => 1 ) unless ($opt_snpsites_bin);
pod2usage( -msg => 'abyss not in $PATH and binary not specified use --abyss-bin', -verbose => 0, -exitval => 1 ) unless ($opt_abyss_bin);
pod2usage( -msg => 'canu not in $PATH and binary not specified use --canu-bin', -verbose => 0, -exitval => 1 ) unless ($opt_canu_bin);
pod2usage( -msg => 'prodigal not in $PATH and binary not specified use --prodigal-bin', -verbose => 0, -exitval => 1 ) unless ($opt_prodigal_bin);
pod2usage( -msg => 'prokka not in $PATH and binary not specified use --prokka-bin', -verbose => 0, -exitval => 1 ) unless ($opt_prokka_bin);
pod2usage( -msg => 'pal2nal.pl not in $PATH and binary not specified use --pal2nal-bin', -verbose => 0, -exitval => 1 ) unless ($opt_pal2nal_bin);
pod2usage( -msg => 'roary not in $PATH and binary not specified use --roary-bin', -verbose => 0, -exitval => 1 ) unless ($opt_roary_bin);
pod2usage( -msg => 'orthofinder not in $PATH and binary not specified use --orthofinder-bin', -verbose => 0, -exitval => 1 ) unless ($opt_orthofinder_bin);
pod2usage( -msg => 'fastANI not in $PATH and binary not specified use --fastANI-bin', -verbose => 0, -exitval => 1 ) unless ($opt_fastANI_bin);
pod2usage( -msg => 'gubbins not in $PATH and binary not specified use --gubbins-bin', -verbose => 0, -exitval => 1 ) unless ($opt_gubbins_bin);
pod2usage( -msg => 'snippy not in $PATH and binary not specified use --snippy-bin', -verbose => 0, -exitval => 1 ) unless ($opt_snippy_bin);
pod2usage( -msg => 'sickle not in $PATH and binary not specified use --sickle-bin', -verbose => 0, -exitval => 1 ) unless ($opt_sickle_bin);
pod2usage( -msg => 'mash not in $PATH and binary not specified use --mash-bin', -verbose => 0, -exitval => 1 ) unless ($opt_mash_bin);



sub check_external_programs{
	my %programs = ("snippy" => $opt_snippy_bin, "gubbins" => $opt_gubbins_bin, "abyss" => $opt_abyss_bin, "canu" => $opt_canu_bin, "prodigal" => $opt_prodigal_bin, "prokka" => $opt_prokka_bin, "cd-hit" => $opt_cdhit_bin, "mafft" => $opt_mafft_bin, "fasttree" => $opt_fasttree_bin, "snp-sites" => $opt_snpsites_bin, "pal2nal" => $opt_pal2nal_bin, "roary" => $opt_roary_bin, "orthofinder" => $opt_orthofinder_bin, "fastANI" => $opt_fastANI_bin, "mash" => $opt_mash_bin);
	my $fail = 0;
	foreach my $p (sort keys %programs){
		my $path = $programs{$p};
		my $result = 'ok';
		if(! -X $path){
			$result = '!fail!';
			$fail = 1;
		}
		printf "%-10s%6s\t%s\n", $p, $result, $path;
	}
	exit($fail);
}

#=============================== Get bin PATH ======================================================
my $pgcgap_dir;
my $bin = `which pgcgap`;
if ($bin=~/(.+)\/pgcgap/) {
	$pgcgap_dir = $1;
}

#=============================== setup COG database ================================================
if ($opt_setup_COGdb) {
	#system("mkdir -p ~/COGdb");
#	system("wget -c -r -nH -np -nd -R index.html -P ./ ftp://ftp.ncbi.nih.gov/pub/COG/COG2014/data/");
#	system("gunzip prot2003-2014.fa.gz");
	system("wget -P ./ http://bcam.hzau.edu.cn/COGdb/cognames2003-2014.tab");
	system("wget -P ./ http://bcam.hzau.edu.cn/COGdb/fun2003-2014.tab");
	system("wget -P ./ http://bcam.hzau.edu.cn/COGdb/cog2003-2014.csv");
	system("wget -P ./ http://bcam.hzau.edu.cn/COGdb/prot2003-2014.fa");
	system("makeblastdb -parse_seqids -in prot2003-2014.fa -input_type fasta -dbtype prot -out COG_2014");
	system("mv COG_2014.* cog2003-2014.csv cognames2003-2014.tab fun2003-2014.tab $pgcgap_dir/");
	system("chmod a+x $pgcgap_dir/COG*");
	system("chmod a+x $pgcgap_dir/cog2003-2014.csv");
	system("chmod a+x $pgcgap_dir/cognames2003-2014.tab");
	system("chmod a+x $pgcgap_dir/fun2003-2014.tab");
	system("rm prot2003-2014.fa");
#	system("rm prot2003-2014.fa prot2003-2014.gi2gbk.tab prot2003-2014.tab Readme.201610.txt");
}

#===================================================================================================
my $time_start = $^T;
my $working_dir = getcwd;
system("mkdir -p Results");
# Genome Assemble with"Abyss" or "Canu"
if ($opt_All or $opt_Assemble) {
	system("mkdir -p Results/Assembles/Scaf");
	if ($opt_platform eq "illumina") {
		print "Performing --Assemble function for Illunina data...\n\n";
		system("mkdir -p Results/Assembles/Illumina");
		system("mkdir -p Results/Assembles/Scaf/Illumina");
		
		chdir $opt_ReadsPath;
		my @files = glob("*$opt_reads1");
		my %lists;
		foreach (@files) {
			if (/(\S+)$opt_reads1/) {
				$lists{$1} = "1";
			}
		}

		my @lists = keys %lists;

		foreach my $name(@lists) {
			my $read1 = $name . $opt_reads1;
			my $read2 = $name . $opt_reads2;
			my $str = substr($read1,0,(length($read1)-$opt_suffix_len));
			print "Assembling...\n";
			system("abyss-pe name=$str k=$opt_kmmer in='$read1 $read2' np=$opt_threads");
			print "Assemble complete !\n";
			my $assem = $str . "_assembly";
			system("mkdir -p $working_dir/Results/Assembles/Illumina/$assem");
			my $scaf = $str . "-8.fa";
#			system("mkdir Over");
			system("cp $scaf $working_dir/Results/Assembles/Scaf/Illumina/");
#			system("mv $read1 $read2 Over/");
			system("mv $str*.dot* $str*.fa $str*.path* $str*.dist $str*.fai $str*stats* $str*.hist coverage.hist $working_dir/Results/Assembles/Illumina/$assem/");
		}
		chdir $working_dir;
		system("realpath $working_dir/Results/Assembles/Scaf/Illumina/* >> scaf.list");
		my $time_assemble = time();
		my $time_assemblex = ($time_assemble - $time_start)/3600;
		print "The 'Assemble' program runs for $time_assemblex hours.\n\n";
	}elsif ($opt_platform eq "pacbio") {
		print "Performing --Assemble function for PacBio data...\n\n";
		#system("mkdir Results/Assembles/PacBio");
		system("mkdir Results/Assembles/Scaf/PacBio");
		chdir $opt_ReadsPath;
		my @files = glob("*$opt_reads1");
		foreach (@files) {
			my $name = substr($_,0,(length($_)-$opt_suffix_len));
#			if (/(\S+)$opt_reads1/) {
#				my $name = $1;
			my $outdir = "$working_dir/Results/Assembles/PacBio/" . $name;
			my $scaf = $name . ".contigs.fasta";
			system("canu -p $name -d $outdir genomeSize=$opt_genomeSize maxThreads=$opt_threads useGrid=false -pacbio-raw $_");
			system("cp $outdir/$scaf $working_dir/Results/Assembles/Scaf/PacBio/");
#			}
		}
		chdir $working_dir;
		system("realpath Results/Assembles/Scaf/PacBio/* >> scaf.list");
	}elsif ($opt_platform eq "oxford") {
		print "Performing --Assemble function for Oxford Nanopore data...\n\n";
		#system("mkdir Results/Assembles/Oxford");
		system("mkdir Results/Assembles/Scaf/Oxford");
		chdir $opt_ReadsPath;
		my @files = glob("*$opt_reads1");
		foreach (@files) {
			my $name = substr($_,0,(length($_)-$opt_suffix_len));
#			if (/(\S+)$opt_reads1/) {
#				my $name = $1;
			my $outdir = "$working_dir/Results/Assembles/Oxford/" . $name;
			my $scaf = $name . ".contigs.fasta";
			system("canu -p $name -d $outdir genomeSize=$opt_genomeSize maxThreads=$opt_threads useGrid=false -nanopore-raw $_");
			system("cp $outdir/$scaf $working_dir/Results/Assembles/Scaf/Oxford/");
#			}
		}
		chdir $working_dir;
		system("realpath Results/Assembles/Scaf/Oxford/* >> scaf.list");
	}
}

#=========================================================================================================================================

##Annotate
if ($opt_All or $opt_Annotate) {
	system("mkdir -p Results/Annotations");
	system("mkdir -p Results/Annotations/CDs");
	system("mkdir -p Results/Annotations/AAs");
	system("mkdir -p Results/Annotations/GFF");
	chdir $opt_scafPath;
	my $path = `pwd`;
	print $path . "\n";
	my @scaf = glob("*$opt_Scaf_suffix");
	foreach my $scaf (@scaf) {
		$scaf=~/(.+)$opt_Scaf_suffix/;
		my $str = $1;
		my $faa = $str . ".faa";
		my $fna = $str . ".ffn";
		my $gff = $str . ".gff";
		my $outdir = $str . "_annotation";
		print "Running ORFs finding and annotating...\n";
		system("prokka --outdir $outdir --prefix $str --locustag $str --genus $opt_genus --species $opt_species --strain $str --gcode $opt_codon --cpus $opt_threads $scaf");
		system("cp $outdir/$faa $working_dir/Results/Annotations/AAs");
		system("cp $outdir/$fna $working_dir/Results/Annotations/CDs");
		system("cp $outdir/$gff $working_dir/Results/Annotations/GFF");
		system("mv $outdir $working_dir/Results/Annotations/");
	}
	
}

#=========================================================================================================================================

## Wrapper to produce phylogenetic tree from the single core proteins and SNPs tree from the single core genes
if ($opt_All or $opt_CoreTree) {
	my $time_coretrees = time();
	print "Performing --CoreTree function...\n\n";
	system("mkdir -p Results/CoreTrees");
	system("cat $opt_AAsPath/*.faa > All.pep");
	print "Running CD-hit...\n";
	system("cd-hit -i All.pep -o All.pep.nr -c $opt_c -n $opt_n -G $opt_G -T $opt_threads -t $opt_t -aS $opt_aS -aL $opt_aL -g $opt_g -M 0 -d $opt_d");

	print "Starting to extract the list of single copied core proteins...\n\n";
	open CLSTR, "All.pep.nr.clstr" || die;
	open LIST, ">core.pep.list" || die;

	my $count = 0;
	my @array = ();
	my %hashc = ();
	my $locustag = '';
	my $strainame = '';
	my $geneno = 0;

	while (<CLSTR>){
		chomp;
		if (/^>Cluster/){
			foreach my $flag (keys %hashc){
				$count++;
			}
			$geneno = scalar @array;
			if(($count == $opt_strain_num) && ($geneno == $opt_strain_num)){
				print LIST join("\t",@array), "\n";
			}
			$count = 0;
			$geneno = 0;
			@array = ();
			%hashc = ();
		}
			if(/\s+>(\S+.*?)\.\.\./){
				$locustag = $1;
				push @array, $locustag;
				if($locustag =~ /(\S+)_\d+/){
					$strainame = $1;
					$hashc{$strainame}++;
					#$count++;
				}
			}
	}
	close CLSTR;

	foreach my $flag (keys %hashc){
		$count++;
	}
	$geneno = scalar @array;
	if(($count == $opt_strain_num) && ($geneno = $opt_strain_num)){
		print LIST join("\t",@array), "\n";
	}
	close LIST;
	print "Starting to extract sequences of single copied core proteins and genes...\n";
	#============================extract ortholog cluster of protein=============================
	open SEQP, "All.pep" || die;

	local $/ = '>';
	my %hashP = ();

	while(<SEQP>){
		chomp;
		my ($name, $sequence) = split (/\n/, $_, 2);
		next unless ($name && $sequence);
		my ($n) = $name =~ /^(\S+)/;
		$sequence =~ s/\s+|\n|\-//g;
		$hashP{$n} = $sequence;
	}
	close(SEQP);

	$/ = "\n";
	open LISTP, "core.pep.list" || die;

	my $dirP = "faa";

	system("mkdir faa");

	my $d = 0;
	my $new_d = 0;

	while(<LISTP>){
		chomp;

		my @array = split (/\n/, $_);
		for my $ele (@array){
			$d++;
			$new_d = sprintf("%04d",$d);
			my @cluster = split (/\s+/, $ele);
			my $fna_file = "OG$new_d".".fa";

			open (OUT, ">$dirP/$fna_file") || die "cannot open $fna_file\n";
			for my $ele (@cluster){
				if(exists $hashP{$ele}){
					print OUT ">$ele\n$hashP{$ele}\n";
				}else{
					warn "error! The gene id is missing in the sequence file.\n";
				}
			}
		}
	}
	close(LISTP);

	
	print "Running mafft...\n\n";
	chdir "faa";
#	system("unset MAFFT_BINARIES");
	my @fa = glob("*.fa");
	foreach (@fa){
		my $name=substr($_,0,(length($_)-3));
		my $in=$name.".fa";
		my $out=$name.".aln";
		system("mafft --quiet --auto --thread $opt_threads $in > $out");
	}


	##==============CONSTRUCT SINGLE CORE PROTEIN TREE========================================================
	#print "Starting to construct single core protein tree...\n\n";
	open CON, ">ALL.core.protein.fasta" || die "open ALL.core.protein.fasta failed\n";
	my $nfilesp = 0; # count number of files
	my %nseqp_hashp = (); # key:infile, val:nseqp
	my %seqid_count_hashp = (); # key:seqid, val:count
	my %HoHp              = ();   #
	my %seqid_HoHp        = ();   #
	my $first_namep       = q{};  # First name in matrix.
	my $lwidthp           = 60;   # default line width for fasta
	my $spacep            = "\t"; # spacepr for aligned print
	my $ncharp            = 0;    # ncharp for phyml header.
	my $nseqp;                    # nseqp for phyml header. Do not initiate!
	my $termp             = $/;   # input record separator
	my @hash_refp_arrayp   = ();   # array with hash references


	my @fasp = glob("*.aln");
	foreach my $argp (@fasp) {
		my $infilep  = $argp;
		my %seq_hashp = parse_fastap($infilep); # key: seqid, value:sequence
		$nfilesp++;

		## Save sequences in array with hash references. Does this work for really large number of fasta files?
		my $hash_refp     = \%seq_hashp;
		push(@hash_refp_arrayp, $hash_refp);

		## Add nseqps to global nseqp_hashp:
		$nseqp_hashp{$infilep} = scalar(keys(%seq_hashp));

		## Get length of sequence for all tax labels. Put in hashes.
		foreach my $tax_keyp (keys %seq_hashp) {
			$seqid_count_hashp{$tax_keyp}++;
			$HoHp{$infilep}{$tax_keyp} = length($seq_hashp{$tax_keyp});
			$seqid_HoHp{$infilep}{$tax_keyp}++;
		}

		## Check all seqs are same length
		my $length;
		my $lnamep;
		foreach my $name (keys %seq_hashp) {
			my $l = length $seq_hashp{$name};
			if (defined $length) {
				if ($length != $l) {
					print STDERR "Error!\nseqpuences in $infilep not all same length ($lnamep is $length, $name is $l)\n";
					exit(1);
				}
			}else {
				$length = length $seq_hashp{$name};
				$lnamep  = $name;
			}
		}
	} # Done with file


	#---------------------------------------------------------------------------
	#  Check if the same number of sequences
	#---------------------------------------------------------------------------
	my $lnamep;
	foreach my $file (keys %nseqp_hashp) {
		my $l = $nseqp_hashp{$file}; # val is a length
		if (defined $nseqp) {
			if ($nseqp != $l) {
				print STDERR "Error!\nNumber of sequences in files differ ($lnamep has $nseqp, $file has $l)\n";
				exit(1);
			}
		}else {
			$nseqp = $nseqp_hashp{$file};
			$lnamep  = $file;
		}
	}


	#---------------------------------------------------------------------------
	#  Check sequence id's
	#---------------------------------------------------------------------------
	if (scalar((keys %seqid_count_hashp)) != $nseqp) { # number of unique seqid's not eq to nseqps
		foreach my $key (sort { $seqid_count_hashp{$b} <=> $seqid_count_hashp{$a} } (keys %seqid_count_hashp)) {
			print STDERR "$key --> $seqid_count_hashp{$key}\n";
		}
		print STDERR "\nError!\nSome sequence labels does not occur in all files.\n";
		print STDERR "That is, sequence id's needs to be identical for concatenation.\n\n";
		exit(1);
	}else {
		## Find the longest taxon name for aligned printing
		my @sorted_names = sort { length($b) <=> length($a) } keys %seqid_count_hashp;
		$spacep = length( shift(@sorted_names) ) + 2;
		$first_namep = $sorted_names[0];
	}


	#---------------------------------------------------------------------------
	#Get ncharp
	#---------------------------------------------------------------------------
	foreach my $h_ref (@hash_refp_arrayp) {
		$ncharp = $ncharp + length($h_ref->{$first_namep});
	}


	#---------------------------------------------------------------------------
	#Print everything to STDOUT
	#---------------------------------------------------------------------------
	print STDERR "\nChecked $nfilesp files -- sequence labels and lengths seems OK.\n";
	print STDERR "Concatenated $nseqp sequences, length $ncharp.\n";
	print STDERR "Printing concatenation to 'ALL.core.protein.fasta'.\n\n";

	##Print the array with hash references (does this work with really large number of files (hashes))?
	##First, concatenate all sequences from hashes
	my %print_hashp = (); # key:label, value:sequence
	foreach my $h_ref (@hash_refp_arrayp) {
		foreach my $seqid (sort keys %$h_ref) {
			$print_hashp{$seqid} .= $h_ref->{$seqid};
		}
	}
	##Then print, and add line breaks in sequences
	foreach my $label (sort keys  %print_hashp) {
		print CON ">$label\n";

		##Print sequence
		##TODO: phylip strict printing of sequence in blocks of 10
		$print_hashp{$label} =~ s/\S{$lwidthp}/$&\n/gs; ## replace word of size $lwidthp with itself and "\n"
		print CON $print_hashp{$label}, "\n";
	}

	print STDERR "Concatenate FASTA alignments to FASTA format completed.\n\n";


	sub parse_fastap {
		my ($infilep) = @_;
		my $termp     = $/; # input record separator;
		my %seq_hashp = (); # key:seqid, val:seq
		open my $INFILEP, "<", $infilep or die "could not open infile '$infilep' : $! \n";
		$/ = ">";
		while(<$INFILEP>) {
		    chomp;
		    next if($_ eq '');
		    my ($id, @sequencelines) = split /\n/;
		    if ($id=~/(^\S+)_\S+$/) {
				$id = $1;
				foreach my $line (@sequencelines) {
					$seq_hashp{$id} .= $line;
				}
		    }
		}
		$/ = $termp;
		return(%seq_hashp);
	} # end of parse_fasta


	print "Constructing ML tree of the single copy core proteins...\n\n";
	system("fasttree ALL.core.protein.fasta > ALL.core.protein.nwk");
	print "Constructing single copy core protein tree completed\n\n";
	system("mv ALL.core.protein.nwk ../Results/CoreTrees/");
	my $time_coretreem = time();
	my $time_coretreep = ($time_coretreem - $time_coretrees)/3600;
	print "The 'CoreTree' program runs for $time_coretreep hours to build single-copy core proteins tree.\n\n";

	#===============================================================================

	chdir "../";

	if ($opt_CDsPath ne "NO") {
		system("cat $opt_CDsPath/*.ffn > All.nuc");
		system("mkdir faa2ffn");
		#============================extract ortholog cluster of genes=============================
		open SEQN, "All.nuc" || die;
		local $/ = '>';
		my %hashN = ();
		<SEQN>;
		while(<SEQN>){
			#local $/ = '>';
			chomp;
			my ($name, $sequence) = split (/\n/, $_, 2);
			next unless ($name && $sequence);
			my ($n) = $name =~ /^(\S+)/;
			$sequence =~ s/\s+|\n|\-//g;
			$hashN{$n} = $sequence;
		}
		close(SEQN);
		$/ = "\n";
		open LISTN, "core.pep.list" || die;

		my $dirN = "ffn";

		system("mkdir ffn");

		my $dn = 0;
		my $new_dn = 0;

		while(<LISTN>){
			chomp;

			my @array = split (/\n/, $_);
			for my $ele (@array){
				$dn++;
				$new_dn = sprintf("%04d",$dn);
				my @cluster = split (/\s+/, $ele);
				my $fna_file = "OG$new_dn".".fa";

				open (OUT, ">$dirN/$fna_file") || die "cannot open $fna_file\n";
				for my $ele (@cluster){
					if(exists $hashN{$ele}){
						print OUT ">$ele\n$hashN{$ele}\n";
					}else{
						warn "error! The gene id is missing in the sequence file.\n";
					}
				}
			}
		}
		close(LISTN);


		opendir(DIR, "faa") || die "Can't open directory\n";
		my @store_array = ();
		@store_array = readdir(DIR);
		my $name = '';

		foreach my $file (@store_array) {
			next unless ($file =~ /^\S+\.aln$/);
			if ($file =~ /^(\S+)\.aln$/){
				$name = $1;
			}

			system("pal2nal.pl faa/$file ffn/$name.fa -nogap -output fasta -codontable $opt_codon > faa2ffn/$name.codon.aln");
		}


		chdir "faa2ffn";

		my @aln=glob("*.aln");
		foreach (@aln){
			my $name=substr($_,0,(length($_)-4));
			my $in=$name.".aln";
			my $out=$name.".fas";
			open ALNIN,"$in" or die;
			open ALNOUT, ">$out" or die;
			while(<ALNIN>){
				chomp;
				if (/(\>\S+)_\S+/){
					print ALNOUT $1."\n";
				}else{
					print ALNOUT $_."\n";
				}
			}
		}
		close ALNIN;
		close ALNOUT;

		open CON, ">ALL.core.nucl.fasta" || die "open ALL.core.nucl.fasta failed\n";
		my $nfiles = 0; # count number of files
		my %nseq_hash = (); # key:infile, val:nseq
		my %seqid_count_hash = (); # key:seqid, val:count
		my %HoH              = ();   #
		my %seqid_HoH        = ();   #
		my $first_name       = q{};  # First name in matrix.
		my $lwidth           = 60;   # default line width for fasta
		my $space            = "\t"; # spacer for aligned print
		my $nchar            = 0;    # nchar for phyml header.
		my $nseq;                    # nseq for phyml header. Do not initiate!
		my $term             = $/;   # input record separator
		my @hash_ref_array   = ();   # array with hash references


		my @fas = glob("*.fas");
		foreach my $arg (@fas) {
			my $infile  = $arg;
			my %seq_hash = parse_fasta($infile); # key: seqid, value:sequence
			$nfiles++;

			## Save sequences in array with hash references. Does this work for really large number of fasta files?
			my $hash_ref     = \%seq_hash;
			push(@hash_ref_array, $hash_ref);

			## Add nseqs to global nseq_hash:
			$nseq_hash{$infile} = scalar(keys(%seq_hash));

			## Get length of sequence for all tax labels. Put in hashes.
			foreach my $tax_key (keys %seq_hash) {
				$seqid_count_hash{$tax_key}++;
				$HoH{$infile}{$tax_key} = length($seq_hash{$tax_key});
				$seqid_HoH{$infile}{$tax_key}++;
			}

			## Check all seqs are same length
			my $length;
			my $lname;
			foreach my $name (keys %seq_hash) {
				my $l = length $seq_hash{$name};
				if (defined $length) {
					if ($length != $l) {
						print STDERR "Error!\nSequences in $infile not all same length ($lname is $length, $name is $l)\n";
						exit(1);
					}
				}
				else {
					$length = length $seq_hash{$name};
					$lname  = $name;
				}
			}
		} # Done with file


		#---------------------------------------------------------------------------
		#  Check if the same number of sequences
		#---------------------------------------------------------------------------
		my $lname;
		foreach my $file (keys %nseq_hash) {
			my $l = $nseq_hash{$file}; # val is a length
			if (defined $nseq) {
				if ($nseq != $l) {
					print STDERR "Error!\nNumber of sequences in files differ ($lname has $nseq, $file has $l)\n";
					exit(1);
				}
			}
			else {
				$nseq = $nseq_hash{$file};
				$lname  = $file;
			}
		}


		#---------------------------------------------------------------------------
		#  Check sequence id's
		#---------------------------------------------------------------------------
		if (scalar((keys %seqid_count_hash)) != $nseq) { # number of unique seqid's not eq to nseqs
			foreach my $key (sort { $seqid_count_hash{$b} <=> $seqid_count_hash{$a} } (keys %seqid_count_hash)) {
				print STDERR "$key --> $seqid_count_hash{$key}\n";
			}
			print STDERR "\nError!\nSome sequence labels does not occur in all files.\n";
			print STDERR "That is, sequence id's needs to be identical for concatenation.\n\n";
			exit(1);
		}
		else {
			## Find the longest taxon name for aligned printing
			my @sorted_names = sort { length($b) <=> length($a) } keys %seqid_count_hash;
			$space = length( shift(@sorted_names) ) + 2;
			$first_name = $sorted_names[0];
		}


		#---------------------------------------------------------------------------
		#Get nchar
		#---------------------------------------------------------------------------
		foreach my $h_ref (@hash_ref_array) {
			$nchar = $nchar + length($h_ref->{$first_name});
		}


		#---------------------------------------------------------------------------
		#Print everything to STDOUT
		#---------------------------------------------------------------------------
		print STDERR "\nChecked $nfiles files -- sequence labels and lengths seems OK.\n";
		print STDERR "Concatenated $nseq sequences, length $nchar.\n";
		print STDERR "Printing concatenation to 'ALL.core.nucl.fasta'.\n\n";

		## Print the array with hash references (does this work with really large number of files (hashes))?
		## First, concatenate all sequences from hashes
		my %print_hash = (); # key:label, value:sequence
		foreach my $h_ref (@hash_ref_array) {
			foreach my $seqid (sort keys %$h_ref) {
				$print_hash{$seqid} .= $h_ref->{$seqid};
			}
		}
		## Then print, and add line breaks in sequences
		foreach my $label (sort keys  %print_hash) {
			print CON ">$label\n";

			## Print sequence
			## TODO: phylip strict printing of sequence in blocks of 10
			$print_hash{$label} =~ s/\S{$lwidth}/$&\n/gs; ## replace word of size $lwidth with itself and "\n"
			print CON $print_hash{$label}, "\n";
		}

		print STDERR "Concatenate FASTA alignments to FASTA format completed.\n\n";


		sub parse_fasta {

			my ($infile) = @_;

			my $term     = $/; # input record separator;
			my %seq_hash = (); # key:seqid, val:seq

			open my $INFILE, "<", $infile or die "could not open infile '$infile' : $! \n";
			$/ = ">";
			while(<$INFILE>) {
				chomp;
				next if($_ eq '');
				my ($id, @sequencelines) = split /\n/;
				foreach my $line (@sequencelines) {
					$seq_hash{$id} .= $line;
				}
			}
			$/ = $term;

			return(%seq_hash);

		} # end of parse_fasta


		print "Calling core SNPs...\n";
		system("snp-sites -o ALL.core.snp.fasta ALL.core.nucl.fasta");

		print "Constructing ML tree of core SNPS...\n\n";

		system("fasttree -nt -gtr ALL.core.snp.fasta > ALL.core.snp.nwk");
		system("mv ALL.core.snp.fasta ALL.core.snp.nwk ../Results/CoreTrees/");
		
		chdir "../";
		system("mv faa2ffn ./Results/CoreTrees/");
		system("mv ffn ./Results/CoreTrees/");
	}
	system("mv faa ./Results/CoreTrees/");
	system("mv All.* ./Results/CoreTrees/");
	system("mv core.pep.list ./Results/CoreTrees/");
	my $time_coretreed = time();
	my $time_coretree = ($time_coretreed - $time_coretrees)/3600;
	print "The 'CoreTree' program runs for $time_coretree hours.\n\n";
}


if ($opt_All or $opt_Pan) {
	my $time_pans = time();
	print "Performing --Pan function...\n\n";
	#Roary takes GFF3 files as input. They must contain the nucleotide sequence at the end of the file. All GFF3 files created by Prokka are valid with Roary
	my $pangenome = "Results/PanGenome";
	#system("roary -p $opt_threads -e --mafft -r -t $opt_codon -f $pangenome $opt_GffPath/*.gff");
	system("roary -p $opt_threads -r -t $opt_codon -f $pangenome $opt_GffPath/*.gff");
	chdir "Results/PanGenome";
	system("create_pan_genome_plots.R");#create pan genome plots
	system("Rscript $pgcgap_dir/plot_3Dpie.R");#plot pangenome 3D-pie
	system("python $pgcgap_dir/fmplot.py --labels accessory_binary_genes.fa.newick gene_presence_absence.csv");
	#Constructing Roary single-copy core proteins tree
	system("mkdir Core");
	chdir $working_dir;
	
	my %hash;
	system("cat $opt_AAsPath/*.faa > Results/PanGenome/Core/All_aa.fa");
	chdir "Results/PanGenome/Core";
	local $/ = ">";
	open AA, "All_aa.fa" || die;
	<AA>;
	while (<AA>) {
		chomp;
		my ($head, $seq) = split "\n", $_, 2;
		$head=~/^(\S+)/;
		$hash{$1} = $seq;
	}

	close AA;

	$/ = "\n";
	open IN, "../gene_presence_absence.csv" || die;
	open TBL, ">gene_presence_absence.tbl" || die;
	while (<IN>) {
		chomp;
		$_=~s/,"/\t/g;
		$_=~s/"//g;
		print TBL $_ . "\n";
	}
	close IN;
	close TBL;


	open INF, "gene_presence_absence.tbl" || die;
	open OUT, ">IDs.txt" || die;
	my $count;
	<INF>;
	while(<INF>){
		chomp;
		my @lines = split /\t/;
		if ($lines[3] == $opt_strain_num && $lines[5] == 1) {
			$count++;
			my $group = "Group_" . $count;
			print OUT $group;
			for (my $i=14; $i<@lines; $i++) {
				$lines[$i]=~/(\S+)/;
				print OUT "\t$1";
			}
			print OUT "\n";
		}
	}
	close INF;
	close OUT;

	open ID, "IDs.txt" || die;
	while (<ID>) {
		chomp;
		my @line = split /\t/;
		my $gene = $line[0] . ".aa";
		open OUTF, ">$gene" || die;
		for (my $j=1; $j<@line; $j++) {
			if (exists $hash{$line[$j]}) {
				print OUTF ">$line[$j]\n$hash{$line[$j]}\n";
			}
		}
		close OUTF;
	}
	close ID;


	print "Running mafft...\n\n";
	my @fa = glob("*.aa");
	foreach (@fa){
		my $name=substr($_,0,(length($_)-3));
		my $in=$name.".aa";
		my $out=$name.".aln";
		system("mafft --quiet --auto --thread $opt_threads $in > $out");
	}

	my @aln = glob("*.aln");
	foreach  (@aln) {
		$_=~/(\S+).aln/;
		my $aa = $1 . ".aa";
		my $file_size = -s $_;
		if ($file_size == 0) {
			system("rm -f $_");
			system("rm -f $aa");
		}
	}
	##==============CONSTRUCT SINGLE CORE PROTEIN TREE========================================================
	#print "Starting to construct single core protein tree...\n\n";
	open CON, ">Roary.core.protein.fasta" || die "open Roary.core.protein.fasta failed\n";
	my $nfilesr = 0; # count number of files
	my %nseqr_hashr = (); # key:infile, val:nseqp
	my %seqid_count_hashr = (); # key:seqid, val:count
	my %HoHr              = ();   #
	my %seqid_HoHr        = ();   #
	my $first_namer       = q{};  # First name in matrix.
	my $lwidthr           = 60;   # default line width for fasta
	my $spacer            = "\t"; # spacepr for aligned print
	my $ncharr            = 0;    # ncharp for phyml header.
	my $nseqr;                    # nseqp for phyml header. Do not initiate!
	my $termr             = $/;   # input record separator
	my @hash_refr_arrayr   = ();   # array with hash references


	my @fasr = glob("*.aln");
	foreach my $argr (@fasr) {
		my $infiler  = $argr;
		my %seq_hashr = parse_fastar($infiler); # key: seqid, value:sequence
		$nfilesr++;

		## Save sequences in array with hash references. Does this work for really large number of fasta files?
		my $hash_refr     = \%seq_hashr;
		push(@hash_refr_arrayr, $hash_refr);

		## Add nseqps to global nseqp_hashp:
		$nseqr_hashr{$infiler} = scalar(keys(%seq_hashr));

		## Get length of sequence for all tax labels. Put in hashes.
		foreach my $tax_keyr (keys %seq_hashr) {
			$seqid_count_hashr{$tax_keyr}++;
			$HoHr{$infiler}{$tax_keyr} = length($seq_hashr{$tax_keyr});
			$seqid_HoHr{$infiler}{$tax_keyr}++;
		}

		## Check all seqs are same length
		my $length;
		my $lnamer;
		foreach my $name (keys %seq_hashr) {
			my $l = length $seq_hashr{$name};
			if (defined $length) {
				if ($length != $l) {
					print STDERR "Error!\nseqpuences in $infiler not all same length ($lnamer is $length, $name is $l)\n";
					exit(1);
				}
			}else {
				$length = length $seq_hashr{$name};
				$lnamer  = $name;
			}
		}
	} # Done with file


	#---------------------------------------------------------------------------
	#  Check if the same number of sequences
	#---------------------------------------------------------------------------
	my $lnamer;
	foreach my $file (keys %nseqr_hashr) {
		my $l = $nseqr_hashr{$file}; # val is a length
		if (defined $nseqr) {
			if ($nseqr != $l) {
				print STDERR "Error!\nNumber of sequences in files differ ($lnamer has $nseqr, $file has $l)\n";
				exit(1);
			}
		}else {
			$nseqr = $nseqr_hashr{$file};
			$lnamer  = $file;
		}
	}


	#---------------------------------------------------------------------------
	#  Check sequence id's
	#---------------------------------------------------------------------------
	if (scalar((keys %seqid_count_hashr)) != $nseqr) { # number of unique seqid's not eq to nseqrs
		foreach my $key (sort { $seqid_count_hashr{$b} <=> $seqid_count_hashr{$a} } (keys %seqid_count_hashr)) {
			print STDERR "$key --> $seqid_count_hashr{$key}\n";
		}
		print STDERR "\nError!\nSome sequence labels does not occur in all files.\n";
		print STDERR "That is, sequence id's needs to be identical for concatenation.\n\n";
		exit(1);
	}else {
		## Find the longest taxon name for aligned printing
		my @sorted_names = sort { length($b) <=> length($a) } keys %seqid_count_hashr;
		$spacer = length( shift(@sorted_names) ) + 2;
		$first_namer = $sorted_names[0];
	}


	#---------------------------------------------------------------------------
	#Get ncharp
	#---------------------------------------------------------------------------
	foreach my $h_ref (@hash_refr_arrayr) {
		$ncharr = $ncharr + length($h_ref->{$first_namer});
	}


	#---------------------------------------------------------------------------
	#Print everything to STDOUT
	#---------------------------------------------------------------------------
	print STDERR "\nChecked $nfilesr files -- sequence labels and lengths seems OK.\n";
	print STDERR "Concatenated $nseqr sequences, length $ncharr.\n";
	print STDERR "Printing concatenation to 'Roary.core.protein.fasta'.\n\n";

	##Print the array with hash references (does this work with really large number of files (hashes))?
	##First, concatenate all sequences from hashes
	my %print_hashr = (); # key:label, value:sequence
	foreach my $h_ref (@hash_refr_arrayr) {
		foreach my $seqid (sort keys %$h_ref) {
			$print_hashr{$seqid} .= $h_ref->{$seqid};
		}
	}
	##Then print, and add line breaks in sequences
	foreach my $label (sort keys  %print_hashr) {
		print CON ">$label\n";

		##Print sequence
		##TODO: phylip strict printing of sequence in blocks of 10
		$print_hashr{$label} =~ s/\S{$lwidthr}/$&\n/gs; ## replace word of size $lwidthr with itself and "\n"
		print CON $print_hashr{$label}, "\n";
	}

	print STDERR "Concatenate FASTA alignments to FASTA format completed.\n\n";


	sub parse_fastar {
		my ($infiler) = @_;
		my $termp     = $/; # input record separator;
		my %seq_hashr = (); # key:seqid, val:seq
		open my $INFILER, "<", $infiler or die "could not open infile '$infiler' : $! \n";
		$/ = ">";
		while(<$INFILER>) {
		    chomp;
		    next if($_ eq '');
		    my ($id, @sequencelines) = split /\n/;
		    if ($id=~/(^\S+)_\S+$/) {
				$id = $1;
				foreach my $line (@sequencelines) {
					$seq_hashr{$id} .= $line;
				}
		    }
		}
		$/ = $termr;
		return(%seq_hashr);
	} # end of parse_fastar

	print "Constructing ML tree of the single-copy core proteins...\n\n";
	system("fasttree Roary.core.protein.fasta > Roary.core.protein.nwk");
	print "Constructing single-copy core protein tree completed\n\n";
	my $time_pand = time();
	my $time_pan = ($time_pand - $time_pans)/3600;
	print "The 'Pan' program runs for $time_pan hours.\n\n";
	chdir $working_dir;
}

if ($opt_All or $opt_OrthoF) {
	my $time_OrthoFs = time();
	print "Performing --OrthoF function...\n\n";
	#system("mkdir Results/OrthoF");
	my $orthoFprefix = "orthoF";
	system("orthofinder -a $opt_threads -t $opt_threads -S $opt_Sprogram -n $orthoFprefix -f $opt_AAsPath");
	my $time_OrthoFd = time();
	my $time_OrthoF = ($time_OrthoFd - $time_OrthoFs)/3600;
	print "The 'OrthoF' program runs for $time_OrthoF hours.\n\n";
	#system("mv $opt_AAsPath/Results_orthoF* Results/OrthoF");
#	system("mv $opt_AAsPath/OrthoFinder/ Results/");
	system("mv $opt_AAsPath/*rtho*/ Results/");
}

if ($opt_All or $opt_MASH) {
	my $time_MASHs = time();
	print "Performing --MASH function...\n\n";
	system("mkdir Results/MASH");
	chdir $opt_scafPath;
	my @genome = glob("*$opt_Scaf_suffix");
	foreach  (@genome) {
		system("mash sketch $_");
	}

	my @msh = glob("*.msh");
	for (my $i=0; $i<@msh; $i++) {
		for (my $j=0; $j<@msh; $j++) {
			system("mash dist $msh[$i] $msh[$j] >> MASH");
		}
	}
	open IN, "MASH" || die;
	open OUT, ">MASH2" || die;
	while (<IN>) {
		chomp;
		my @lines = split /\t/;
		my $dis = (1-$lines[2])*100;
		print OUT "$lines[0]\t$lines[1]\t$dis\t$lines[3]\t$lines[4]\n";
	}
	system("perl $pgcgap_dir/get_Mash_Matrix.pl --Scaf_suffix $opt_Scaf_suffix");
	system("Rscript $pgcgap_dir/Plot_MashHeatmap.R");
	system("rm -f *.msh");
	system("mv MASH MASH2 MASH.heatmap MASH_matrix.pdf $working_dir/Results/MASH");
	chdir $working_dir;
	my $time_MASHd = time();
	my $time_MASH = ($time_MASHd - $time_MASHs)/3600;
	print "The 'MASH' program runs for $time_MASH hours.\n\n";
}

if ($opt_All or $opt_ANI) {
	my $time_ANIs = time();
	print "Performing --ANI function...\n\n";
	system("mkdir Results/ANI");
	system("fastANI --matrix -t $opt_threads --ql $opt_queryL --rl $opt_refL -o $opt_ANIO");
	chdir "Results/ANI";
	system("perl $pgcgap_dir/get_ANImatrix.pl --Scaf_suffix $opt_Scaf_suffix");
	system("Rscript $pgcgap_dir/Plot_ANIheatmap.R");
	chdir $working_dir;
	my $time_ANId = time();
	my $time_ANI = ($time_ANId - $time_ANIs)/3600;
	print "The 'ANI' program runs for $time_ANI hours.\n\n";
}

if ($opt_VAR) {
	my $time_VARs = time();
	print "Performing --VAR function...\n\n";
	system("mkdir Results/Variants");
	chdir "$opt_ReadsPath";
	system("mkdir Trimmed");
	system("cp $opt_refgbk ./");
	my @files = glob("*$opt_reads1");
	my %lists;
	foreach (@files) {
		if (/(\S+)$opt_reads1/) {
			$lists{$1} = "1";
		}
	}

	my @lists = keys %lists;

	foreach my $name(@lists) {
		my $read1 = $name . $opt_reads1;
		my $read2 = $name . $opt_reads2;
		my $str = substr($read1,0,(length($read1)-$opt_suffix_len));
		my $trif = $str . "_trimmed_1.fastq";
		my $trir = $str . "_trimmed_2.fastq";
		my $tris = $str . "_trimmed_s.fastq";
		system("sickle pe -f $read1 -r $read2 -t $opt_qualtype -o Trimmed/$trif -p Trimmed/$trir -s Trimmed/$tris -q $opt_qual -l $opt_length");#Quality trimming
		system("snippy --cpus $opt_threads --ram $opt_ram --prefix $str --mincov $opt_mincov --minfrac $opt_minfrac --minqual $opt_minqual --outdir ../../Results/Variants/$str --ref $opt_refgbk --R1 Trimmed/$trif --R2 Trimmed/$trir --report");
	}
	chdir $working_dir;
	system("snippy-core --ref $opt_refgbk $working_dir/Results/Variants/*");
	system("mkdir Results/Variants/Core");

	if ($opt_strain_num > 2) {
		my @corefull = ("run_gubbins.py --tree_builder $opt_tree_builder --iterations $opt_iterations --prefix gubbins.core.full core.full.aln");
		system("mv gubbins.* Results/Variants/Core/");
		my $corefull = system(@corefull);
		if (!($corefull == 0)) {
			print "Some error happens when running gubbins! The recombinations will not be predicted, and running fasttree to construct the trees instead!\n";
			system("fasttree -nt -gtr core.full.aln > core.full.nwk");
			system("mv core.full.aln core.ref.fa core.tab core.txt core.vcf core.full.nwk Results/Variants/Core/");
		}else {
			system("mv core.full.aln core.ref.fa core.tab core.txt core.vcf gubbins.* core.full.aln.iteration* *.joint.txt Results/Variants/Core/");
			print "running gubbins successfully!\n";
		}
	} else {
		system("fasttree -nt -gtr core.full.aln > core.full.nwk");
		system("mv core.full.aln core.ref.fa core.tab core.txt core.vcf core.full.nwk Results/Variants/Core/");
	}
	system("fasttree -nt -gtr core.aln > core.nwk");
	system("mv core.aln core.nwk Results/Variants/Core/");
	my $time_VARd = time();
	my $time_VAR = ($time_VARd - $time_VARs)/3600;
	print "The 'ANI' program runs for $time_VAR hours.\n\n";
}

if ($opt_All or $opt_pCOG) {
	my $time_COGs = time();
	print "Performing --COG function...\n\n";
	system("mkdir Results/COG");
	system("COG.pl --threads $opt_threads --strain_num $opt_strain_num --AAsPath $opt_AAsPath");
	system("mv $opt_AAsPath/*.table $opt_AAsPath/*.pdf $opt_AAsPath/*.xml $working_dir/Results/COG");
	chdir $working_dir;
	my $time_COGd = time();
	my $time_COG = ($time_COGd - $time_COGs)/3600;
	print "The 'pCOG' program runs for $time_COG hours.\n\n";
}

my $time_end = time();
my $time_total = ($time_end - $time_start)/3600;
print "Total $time_total hours used.\n\n";
