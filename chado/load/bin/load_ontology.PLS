#!perl -w

use Config;
use File::Basename qw(&basename &dirname);
use FindBin '$Bin';
use Cwd;


$origdir = cwd;
chdir dirname($0);
$file = basename($0, '.PL','.PLS');
$file = "gmod_$file.pl";

my %OPTIONS;
if (open F,"$Bin/../../build.conf") {
  while (<F>) {
    next if /^\#/;
    chomp;
    $OPTIONS{$1} = $2 if /^(\w+)\s*=\s*(.+)/;
  }
  close F;
}


open OUT,">$file" or die "Can't create $file: $!";
print OUT "$Config{startperl}\n";

if ($OPTIONS{LIB}) {
  print OUT "use lib '$OPTIONS{LIB}';\n";
}
if ($OPTIONS{PREFIX}) {
  print OUT "use lib '$OPTIONS{PREFIX}/lib'i\n";
}

print OUT <<'!NO!SUBS!';

print <<END_OF_SCRIPT;

---------------------DEPRECATED-----------------------------
The script gmod_load_ontologies.pl is no longer supported.
To load ontologies, either use the `make ontologies` command
or read the INSTALL document describing the make ontologies
command and how to do it 'by hand'.

END_OF_SCRIPT
;

__END__
use strict;
use lib 'lib';
use File::Basename;
use DBI;
use Data::Dumper;
use Bio::Chado::LoadDBI;
use Bio::OntologyIO;
use Bio::Ontology::TermFactory;
use Term::ProgressBar;

use constant DEBUG=>0;

#######################################
# COPYRIGHT
#######################################
#
# This software is free.  You can use it under the terms of the 
# Perl Artistic License.
#
# Allen Day <allenday@ucla.edu>
# October 2, 2003

#######################################
# INITIALIZATION
#######################################

#perl load_ontology.pl SODA.ontology SODA.defs
my ($ontology_file, $ontology_deffile) = @ARGV;

#allow non-existant defsfile for this one
die "USAGE: $0 <dagedit file> [<defs file>]" unless $ontology_file;

Bio::Chado::LoadDBI->init();

#######################################
# SET UP GLOBAL VARS
#######################################
my $ontology_file2 = $ontology_file;
$ontology_file2 =~ s!.+/(.+)!$1!;

#infer the name of the ontology based on the file name.  this may be unreliable.

my $ontname = $ontology_file2 =~ /^EMAP/            ? "Mouse Embryo Anatomy Ontology" :
              $ontology_file2 =~ /^MA/              ? "Mouse Adult Anatomy Ontology" :
              $ontology_file2 =~ /^mouse_pathology/ ? "Mouse Pathology Ontology (Pathbase)" :
              $ontology_file2 =~ /^rel/             ? "Relationship Ontology" :
              $ontology_file2 =~ /^component/       ? "Cellular Component (Gene Ontology)" : #cjm request
              $ontology_file2 =~ /^function/        ? "Molecular Function (Gene Ontology)" : #cjm request
              $ontology_file2 =~ /^process/         ? "Biological Process (Gene Ontology)" : #cjm request
#no longer used
#              $ontology_file2 =~ /^cell_type/       ? "eVOC Cell Type Ontology" :
              $ontology_file2 =~ /^cell/            ? "Cell Ontology" :
              $ontology_file2 =~ /^pathology/       ? "eVOC Pathology Ontology" :
              $ontology_file2 =~ /^SO[FD]A|so\./    ? "Sequence Ontology" :
              $ontology_file2 =~ /^MPheno/          ? "Mammalian Phenotype Ontology" :
              $ontology_file2 =~ /^sofa\./          ? "Sequence Ontology Feature Annotation" :
              $ontology_file2 =~ /^plant\./          ? "Plant Ontology" :
              undef;

die "no ontology name defined for $ontology_file2!" unless defined($ontname);

#we see all of these, apparently it's not standardized yet.  map relationship
#types to stable Relationship Ontology IDs

my %oborelmap = (
				 'transitive_relationship' => 'OBO_REL:0001',
				 'is_a'                    => 'OBO_REL:0002',
				 'part_of'                 => 'OBO_REL:0003',
				 'develops_from'           => 'OBO_REL:0004',
				 'covered_by'              => 'OBO_REL:0005',
				 'relationship'            => 'OBO_REL:0006',
				);

my %predmap = (
		'isa'           => 'is_a',
		'is_a'          => 'is_a',
		'is a'          => 'is_a',
		'partof'        => 'part_of',
		'part_of'       => 'part_of',
		'part of'       => 'part_of',
		'developsfrom'  => 'develops_from',
		'develops_from' => 'develops_from',
		'develops from' => 'develops_from',
		'REL:0005'      => 'covered_by',
		'rel:0005'      => 'covered_by',
		'REL:0001'      => 'transitive_relationship',
		'rel:0001'      => 'transitive_relationship',
			  );

#create some default entries to satisfy chado FK requirements of ontology on db table

my($db) = Bio::Chado::CDBI::Db->find_or_create({name => $ontname});
$db->dbi_commit;
my($cv) = Bio::Chado::CDBI::Cv->find_or_create({name => $ontname});
$cv->dbi_commit;

my $termfact = Bio::Ontology::TermFactory->new();
my $relfact = Bio::Ontology::RelationshipFactory->new();

#decide what format we need.  simple indented file or DAG-Edit ?
#my $format = $ontname =~ 'eVOC' ? 'simplehierarchy' : 'so';
my $format = 'so';

warn "starting parser...\n" if DEBUG;
my $parser = Bio::OntologyIO->new(
			  -term_factory => $termfact,
			  -format => $format,
			  -indent_string => ',',
			  -ontology_name => $ontname,
			  -defs_file => $ontology_deffile,
			  -files => $ontology_file
				 );

my %allterms;
my %predicateterms;
my %allrels;

my $progress;
my $loaded = 0;

#parse the ontologies
while (my $ont = $parser->next_ontology()) {

  my $termcount = $ont->get_all_terms();
  my $ontname   = $ont->name();

  $progress = Term::ProgressBar->new(
                                     {
                                      name => "Terms: $termcount",
                                      count => $termcount,
                                      ETA => 'linear',
                                     }
                                    );

  $progress->message("loading $ontname...");
  $progress->max_update_rate(0.5);

  warn "parsing ontology...\n" if DEBUG;
  $ont->relationship_factory($relfact);
  warn "...terms...\n" if DEBUG;
  load_ontologyterms($ont);
  warn "...relationships...\n" if DEBUG;
  load_ontologyrels($ont);

}

##############
# SUBROUTINES
##############

sub load_ontologyterms{
  my $ontref = shift;

  warn "in loading term\n" if DEBUG;

  my @predicates = $ontref->get_predicate_terms();
  my @roots = $ontref->get_root_terms();

  #load edge terms
  foreach my $predicate (@predicates) {
    $progress->update(++$loaded);
    $progress->message("this is a predicate: ". ref($predicate) ." ". ($oborelmap{ predmap($predicate->name) } || predmap($predicate->name))) if DEBUG;

    #create new predicates and dbxrefs as necessary
    if(!$oborelmap{predmap($predicate->name)}){
      $oborelmap{lc($predicate->name)} = lc($predicate->name);
    }

	#we can't use find_or_create here because the name may already be assigned another cv_id...
	my($predicate_db) = Bio::Chado::CDBI::Cvterm->search(name => predmap($predicate->name));

	if(!$predicate_db){
		$progress->message("creating predicate term for: ".predmap($predicate->name));
		my $dbxref = Bio::Chado::CDBI::Dbxref->find_or_create({
				db_id => $db->id,
				accession => $oborelmap{ predmap($predicate->name) } || predmap($predicate->name),
							   });
		$predicate_db = Bio::Chado::CDBI::Cvterm->create({
			   name => predmap($predicate->name),
			   cv_id => $cv->id,
			   dbxref_id => $dbxref->id,
                           is_relationshiptype => 1,
						  });
	}
	
	$predicateterms{ predmap($predicate->name) } = $predicate_db->id;
	$predicate_db->definition($predicate->definition) unless defined($predicate_db->definition);
	$predicate_db->update;
        $predicate_db->dbi_commit;

	load_synonyms($predicate,$predicate_db);
	load_dblinks($predicate,$predicate_db);
  }

  #load root terms
  foreach my $root (@roots) {
    $progress->update(++$loaded);
    my($root_db) = Bio::Chado::CDBI::Cvterm->search({name => $root->name, cv_id => $cv->id});

        if(!$root_db){
          #warn "oops! ".join '*', ($root->name, $root->identifier, $cv->id) unless $root->name;
          next unless $root->name;
		  my $dbxref = Bio::Chado::CDBI::Dbxref->find_or_create({
			db_id => $db->id,
			accession => $root->identifier,
							   });
		  $root_db = Bio::Chado::CDBI::Cvterm->find_or_create({
			 name                => $root->name || $oborelmap{ predmap($root->identifier) },
			 cv_id               => $cv->id,
			 dbxref_id           => $dbxref->id,
                         is_relationshiptype => ($ontname eq "Relationship Ontology") ? 1 : 0,
							});
	}
	$root_db->definition($root->definition) unless defined($root_db->definition);


	$allterms{$root->name} = $root_db->id;

	$root_db->update;
        $root_db->dbi_commit;

	load_synonyms($root,$root_db);
	load_dblinks($root,$root_db);

	#and recurse down the dag
	load_ontologytermsR($ontref, $root, "\t");
  }
}

#usage: load_ontologytermsR($ontref, $root)
sub load_ontologytermsR {
  $progress->update(++$loaded);
  my $ontref = shift;
  my $parent = shift;
  my $tab = shift;

  my @children = $ontref->get_child_terms($parent);
  foreach my $child (@children) {
	if (!(exists $allterms{$child->name})) {
	  warn  "$tab", $child->name , "\n" if DEBUG;

        my($child_db) = Bio::Chado::CDBI::Cvterm->search({name => $child->name, cv_id => $cv->id});
	if(!$child_db){

#warn "oops! ".join '*', ($child->name, $child->identifier, $cv->id) unless $child->name;
    next unless $child->name;
          my $accession = $child->identifier;
          if ($accession =~ /\S+\:(\S+)/) {
              $accession = $1;
          }
	  my $dbxref = Bio::Chado::CDBI::Dbxref->find_or_create({
				  db_id => $db->id,
				  accession => $accession,
						 });
	  $child_db = Bio::Chado::CDBI::Cvterm->find_or_create({
				name => $child->name,
				cv_id => $cv->id,
				dbxref_id => $dbxref->id,
                                is_relationshiptype => ($ontname eq "Relationship Ontology") ? 1 : 0,
						   });
	}
	  $child_db->definition($child->definition) unless defined($child_db->definition);

	  $allterms{$child->name} = $child_db->id;

	  $child_db->update;
          $child_db->dbi_commit;

	  load_synonyms($child,$child_db);
	  load_dblinks($child,$child_db);

	  load_ontologytermsR($ontref, $child, $tab . "\t");
	}
  }
}

sub load_ontologyrels {
  $progress->update(++$loaded);
  my $ontref = shift;

  my @relationships = $ontref->get_relationships();

  foreach my $relationship (@relationships) {

	my $skip = 0;

	my $obj = $relationship->object_term();
	my $subj = $relationship->subject_term();
	my $pred = $relationship->predicate_term();

	my $pred_id = $predicateterms{predmap($pred->name)};
	my $subj_id = $allterms{$subj->name};
	my $obj_id  = $allterms{$obj->name};


	if(!defined $pred_id){
		warn "pred! ".$pred->name if DEBUG;
		$skip++;
	}

	if (!(exists $allrels{$obj->name . $subj->name . $pred->name})) {

	  $allrels{$obj->name . $subj->name . $pred->name} = $relationship;

	  warn("subj! ".$subj->name .join('*',($subj->name,$subj->identifier))) if DEBUG and !defined $subj_id;
	  warn("obj! " .$obj->name  .join('*',($obj->name,$obj->identifier)))   if DEBUG and !defined $obj_id;
	  $skip++ unless defined $obj_id;
	  $skip++ unless defined $subj_id;

	  next if $skip;
	  my ($cvtermrel) = Bio::Chado::CDBI::Cvterm_Relationship->find_or_create ({
					  subject_id => $subj_id,
					  object_id => $obj_id,
					  type_id => $pred_id,
						 });
          $cvtermrel->dbi_commit; 
	}								
  }
}

sub predmap {
  my $term = shift;
  return $predmap{lc($term)} ? $predmap{lc($term)} : $term;
}

sub load_dblinks {
  my $term = shift;
  my $term_db = shift;

  my @term_links = $term->get_dblinks();
  foreach my $term_link (@term_links) {

    if(length($term_link) > 255){
      $progress->message("definition for term '".$term->name()."' too long, truncating to length 255");
      $term_link = substr($term_link, 0, 255);
    }

	my $dbxref_db = Bio::Chado::CDBI::Dbxref->find_or_create ({
				accession => $term_link,
				db_id => $db->id,
				version => 0
						   });
        $dbxref_db->dbi_commit;

	my ($cvtermdbxref) = Bio::Chado::CDBI::Cvterm_Dbxref->find_or_create ({
			   cvterm_id => $term_db->id,
			   dbxref_id => $dbxref_db->id
						  });
        $cvtermdbxref->dbi_commit; 
  }
}

sub load_synonyms {
  my $term = shift;
  my $term_db = shift;

  my @term_syns = $term->get_synonyms();
  foreach my $term_syn (@term_syns) {

#	Bio::Chado::CDBI::Cvtermsynonym->find_or_create ({
#						cvterm_id => $term_db->id,
#						synonym => $term_syn,
#					     });
	my ($synonym) = Bio::Chado::CDBI::Cvtermsynonym->find_or_create ({
						cvterm_id => $term_db->id,
						synonym => $term_syn,
					     });
        $synonym->dbi_commit;
  }
}

__END__

=head1 NAME

load_ontology.pl - load DAG-Edit or simple indented hierarchy ontology files into a Chado database.

=head1 SYNOPSIS

#with a definitions file...
/usr/bin/perl load_ontology.pl SODA.ontology SODA.defs

#...and without
/usr/bin/perl load_ontology.pl cell.ontology

=head1 DESCRIPTION

WARNING: This script has not been tested in several years and probably does not not
work.  You should look for a more modern method of loading ontologies, like the
process the Makefile.PL uses, or the SGN contributed script, gmod_load_cvterms.pl.


this script relies on three external modules:

=over

=item Bio::OntologyIO (available from Bioperl)

=item Bio::Chado::AutoDBI  (generated from chado/complete.sql using chado/bin/pg2cdbi.pl)

=item SQL::Translator required to generate Bio::Chado::AutoDBI

=back

=head1 KNOWN BUGS

may not load data into the fields you'd like.  we need to establish a SOP as to what data goes where
in Chado from a DAG-Edit file.

=head1 AUTHOR

Allen Day E<lt>allenday@ucla.eduE<gt>

Copyright 2002-2003
!NO!SUBS!
close OUT or die "Can't close $file: $!";
chmod 0755, $file or die "Can't reset permissions for $file: $!\n";
chdir $origdir;

