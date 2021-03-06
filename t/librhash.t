
use v6;
use lib <blib/lib lib>;

use Test;

use Sum::librhash;

my $abort;
if ($Sum::librhash::up) {
   plan 27;
}
else {
   plan 3;
   $abort = True;
}

ok(1,'We use Sum and we are still alive');

lives-ok { X::librhash::NotFound.new() },
	 'X::librhash::NotFound is available';
lives-ok { X::librhash::NativeError.new() },
	 'X::librhash::NativeError is available';

if $abort {
   diag "No librhash detected, or other very basic problem.  Skipping tests.";
   exit;
}

my $c = Sum::librhash::count();
ok $c > 0, "Sum::librhash::count() reports algorithms present";
is $Sum::librhash::count, $c, "\$Sum::librhash::count contains cached value";

# Should at least have MD5
my $md5 = %Sum::librhash::Algos.pairs.grep(*.value.name eq "MD5")[0].value;
isa-ok $md5, Sum::librhash::Algo, "Found an Algo named MD5";
is $md5.digest_size, 16, "MD5 has expected digest size";

my $a;
lives-ok {$a := Sum::librhash::Instance.new("CRC32")}, "rhash init lives.";
isa-ok $a, Sum::librhash::Instance, "Created Instance object";
ok $a.defined, "Created Instance is really instantiated";
lives-ok {$a.add("Please to checksum this text.".encode('ascii'))}, "rhash update lives";
is $a.finalize(:bytes(4)), buf8.new(0x32,0xd2,1,0xf6), "CRC32 alg computes expected value";
lives-ok { for 0..10000 { my $a := Sum::librhash::Instance.new("CRC32"); $a.finalize(:bytes(4)) if Bool.pick; } }, "Supposedly test GC sanity";

$a := Sum::librhash::Instance.new("CRC32");
throws-like { my $c = $a.clone; +$c; }, X::AdHoc, "Attempt to clone Instance throws exception";
$a.finalize(:bytes(4));
throws-like { $a.finalize(:bytes(4)) }, X::librhash::Final, "Double finalize gets caught for raw Instance";

lives-ok {$a := Sum::librhash::Sum.new("MD5")}, "wrapper class contructor lives";
isa-ok $a, Sum::librhash::Sum, "wrapper class intantiates";
ok $a.defined, "wrapper class intantiates for reelz";
lives-ok {$a.push(buf8.new(97 xx 64))}, "wrapper class can push";
is +$a.finalize, 0x014842d480b571495a4a0363793f7367, "MD5 is correct (test vector 1).";
is +$a.finalize, 0x014842d480b571495a4a0363793f7367, "Wrapper class caches result";
my $res;
my $b := Sum::librhash::Sum.new("MD5");
throws-like { my $c = $b.clone; +$c; }, X::AdHoc, "Attempt to clone wrapper class throws exception";
$b.push(buf8.new(97 xx 64));
$b.push(buf8.new(97 xx 64));
lives-ok { $res  = $b.finalize(buf8.new(97 xx 56)) }, "finalize also pushes";
is +$res, 0x63642b027ee89938c922722650f2eb9b, "MD5 is correct (test vector 2).";
is (+Sum::librhash::Sum.new("MD5").finalize()), 0xd41d8cd98f00b204e9800998ecf8427e, "wrapper class works with no addend ever pushed";
is (+Sum::librhash::Sum.new("MD5").finalize(buf8.new())), 0xd41d8cd98f00b204e9800998ecf8427e, "wrapper class works with just empty buffer finalized";

class sayer {
    has $.accum is rw = "";
    method print (*@s) { $.accum ~= [~] @s }
}
my sayer $p .= new();
# Rakudo-p currently does not serialize $=pod in PIR compunits so skip this.
if ($*VM.name ne 'parrot') {
{ temp $*OUT = $p; EVAL $Sum::librhash::Doc::synopsis; }
is $p.accum, $Sum::librhash::Doc::synopsis.comb(/<.after \x23\s> (<.ws> <.xdigit>+)+/).join("\n") ~ "\n", 'Code in manpage synopsis actually works';
}
