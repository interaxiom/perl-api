use ExtUtils::MakeMaker;
use utf8;

WriteMakefile(
	NAME => 'InteraxiomApi',
	VERSION => '1.0',
	PREREQ_PM => {
		'LWP::UserAgent' => '6.44',
		'JSON' => '2.97',
	},
	ABSTRACT => "Perl wrapper for Interaxiom's APIs",
	AUTHOR => 'Joshua Lawson <joshua.lawson@interaxiom.com.au>',
);
