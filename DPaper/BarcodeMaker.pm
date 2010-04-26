package DPaper::BarcodeMaker;

use strict;
use warnings;

use Barcode::Code128;
use PostScript::Simple;

use base 'Exporter';
our @EXPORT_OK = qw(code128 code2eps);

sub code128 {
	my ($text) = @_;
	return Barcode::Code128->new()->barcode($text);
}

sub code2eps {
	my ($code) = @_;

	my $eps = PostScript::Simple->new(
		units       => "cm",          eps       => 1,
		xsize       => length($code), ysize     => 1,
	);
	$eps->setlinewidth(0.001);

	my $pos = 0;
	$code =~ s/(([# ])\2*)/length($1) . ":$2,"/ge;
	my @codes = split(/,/, $code);
	while (@codes) {
		my ($l, $c) = split(/:/, shift(@codes));
		if ($c eq "#") {
			$eps->box({ filled => 1 }, $pos, 1, $pos + $l, 0);
		}
		$pos += $l;
	}

	return $eps->get();
}

1;

__END__

=head1 NAME

DPaper::BarcodeMaker - encodes barcodes and produces EPS files of barcodes

=head1 SYNOPSIS

 my $code = code128("foobar");

 my $eps = code2eps($code);
 my $eps_obj = PostScript::Simple::EPS->new(source => $eps);
 $eps_obj->scale(10, 2);
 $ps_page->importeps($eps_obj, $x, $y);

=head1 DESCRIPTION

This module provides some functions that encode data into barcodes, and
renders EPS files from barcode input.

The B<code128> function takes string input and creates the Code128 form
of it.  The return value is the barcode data, with C<#> chars standing
for black parts and spaces standing for white parts.

The B<code2eps> function takes any such string and returns an EPS
document that has a barcode in the above form encoded.  This document
has a width and a height of one centimeter.

=cut

