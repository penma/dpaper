package DPaper::Encoder;

use strict;
use warnings;
use 5.010;

use MIME::Base64;
use Number::Range;
use PostScript::Simple;

use DPaper::BarcodeMaker qw(code128 code2eps);

sub new {
	my ($class, %args) = @_;
	my $self = {
		fileid => $args{fileid} // "stdin",
		offset => $args{offset} // 0,
	};
	$self->{pss} = PostScript::Simple->new(
		papersize   => "A4",      units     => "cm",
		colour      => 1,         eps       => 0,
		coordorigin => "LeftTop", direction => "RightDown"
	);
	return bless($self, $class);
}

sub writepage {
	my ($self, %args) = @_;
	my $data = $args{data};
	my $offset = $args{offset} // $self->{offset};
	my $datalen = $args{length};

	print "encoder: writepage $offset\n";

	$self->{pss}->newpage();
	$self->{pss}->setfont("OCRA", 4);

	my ($data_line, $ps_line) = (0, 0);
	my @lines_empty;
	foreach my $chunk (unpack("(a30)*", $data)) {
		if ($data_line >= 160) {
			warn("Received 160x30 bytes of input data, this is more than will fit on the page");
		}

		# detect and record full-null blocks
		if ($chunk eq "\0" x 30) {
			push(@lines_empty, $data_line);
			next;
		}

		# generate barcode
		my $code = sprintf("%02x:%s", $data_line, encode_base64($chunk, ""));

		# include barcode in document
		my $e = PostScript::Simple::EPS->new(source => code2eps(code128($code)));
		$e->scale(18 / $e->width, 0.14 / $e->height);
		$self->{pss}->importeps($e, 2, 2.8 + $ps_line / 6.2);
		$self->{pss}->text(2 - 0.5, 2.8 - 0.02 + ($ps_line + 1) / 6.2, sprintf("%02x", $data_line));
		$ps_line++;
	} continue {
		$data_line++;
	}

	# generate the header
	my ($eps);

	# length/offset information
	my $header_x = 1.25;
	foreach my $code (split(/ /, sprintf("LE%x OS%x", $datalen, $offset))) {
		$eps = PostScript::Simple::EPS->new(source => code2eps(code128($code)));
		$eps->scale(4 / $eps->width, 0.5 / $eps->height);
		$self->{pss}->importeps($eps, $header_x + 0.25, 1.6);
		$header_x += 4.5;
	}

	# fileid
	$eps = PostScript::Simple::EPS->new(source => code2eps(code128("FI$self->{fileid}")));
	$eps->scale(8.5 / $eps->width, 0.5 / $eps->height);
	$self->{pss}->importeps($eps, $header_x + 0.25, 1.6);

	# store information about full-null-blocks
	my $range = Number::Range->new();
	$range->addrange(@lines_empty);
	my $code = "DB" . ($range->size() ? scalar($range->range()) : "NONE");
	$eps = PostScript::Simple::EPS->new(source => code2eps(code128($code)));
	$eps->scale(17.5 / $eps->width, 0.5 / $eps->height);
	$self->{pss}->importeps($eps, 1.5, 2.25);

	# human-readable header
	$self->{pss}->setfont("OCRA", 10);
	$self->{pss}->text(1, 1.5, "DPaper fid:$self->{fileid} off:$offset rawlen:$datalen");

	$self->{offset} = $offset + $datalen;
}

sub get {
	my ($self) = @_;
	$self->{pss}->get();
}

1;

