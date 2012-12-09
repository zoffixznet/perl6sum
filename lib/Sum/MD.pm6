=begin pod

=head1 NAME

Sum::MD

=head1 SYNOPSIS

    use Sum::MD;

    class myMD5 does Sum::MD5 does Sum::Marshal::Raw { }
    my myMD5 $a .= new();
    $a.finalize("123456789".encode('ascii')).say;
        # 50479014739749459024317001064922631435

    # Usage is basically the same for MD4, MD4ext, RIPEMD128,
    # RIPEMD160, RIPEMD256 and RIPEMD320.

=end pod

# This is a bit of a hack.  We want the test suite to be able to try to
# run the code in the synopsis.  When pod is more functional maybe this
# will become more maintainable.  In the meantime, if you edit anything
# above, take care to adjust the sections here.

$Sum::MD::Doc::synopsis = $=pod[0].content[3..4]>>.content.Str;

=begin pod

=head1 DESCRIPTION

    Using C<Sum::MD> defines roles for generating types of C<Sum> that
    calculate the MD series of message digests (MD2, MD4, MD5) and
    close variants.  MD6 is not yet implemented.

    Note that many of these algorithms are considered deprecated for new
    applications, and insecure in some current applications.

    These sums require a small but significant memory profile while not
    finalized, so care must be taken when huge numbers of concurrent
    instances are used.

    NOTE: This implementation is unaudited and is for experimental
    use only.  When audits will be performed will depend on the maturation
    of individual Perl6 implementations, and should be considered
    on an implementation-by-implementation basis.

=end pod

use Sum;
use Sum::MDPad;

role Sum::MD4_5 [ :$alg where { $_ eqv [|] <MD5 MD4 MD4ext RIPEMD-128 RIPEMD-160 RIPEMD-256 RIPEMD-320 > } = "MD5" ] does Sum::MDPad[:lengthtype<uint64_le>] {
    has @!w is rw;     # "Parsed" message gets bound here.
    has @!s is rw;     # Current hash state.  H in specification.

    # MD5 table of constants (a.k.a. T[1..64] in RFC1321)
    my @t = (Int(4294967296 * .sin.abs) for 1..64);

    method size ( --> int) {
        given $alg {
            when "MD4"|
                 "MD5"|
                 "RIPEMD-128" { 128 }
            when "MD4ext"     { 256 }
            when "RIPEMD-256" { 256 }
            when "RIPEMD-160" { 160 }
            when "RIPEMD-320" { 320 }
        }
    }

    submethod BUILD () {
        @!s = (0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476);
        if $alg eqv "MD4ext" {
            @!s.push(0x33221100,0x77665544,0xbbaa9988,0xffeeddcc);
        }
        if $alg eqv ("RIPEMD-160"|"RIPEMD-320") {
            @!s.push(0xc3d2e1f0);
        }
	if $alg eqv ("RIPEMD-256"|"RIPEMD-320") {
            @!s.push(@!s.map({
                (0xf0f0f0f0 +& ($_ +< 4)) +|
                (0x0f0f0f0f +& ($_ +> 4)) }));
        }
    }

    # A moment of silence for the pixies that die every time something
    # like this gets written in an HLL.
    my sub rol ($v, int $count where { -1 < * < 32 }) {
        my $tmp = ($v +< $count) +& 0xffffffff;
        $tmp +|= (($v +& 0xffffffff) +> (32 - $count));
	$tmp;
    }

    method md4_round1_step ($data, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + (($b +& $c) +| ((+^$b) +& $d))), $shift));
    }

    method md4_ext_round1_step ($data, int $shift) {
        my $a := @!s[4];
        my $b := @!s[5];
        my $c := @!s[6];
        my $d := @!s[7];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + (($b +& $c) +| ((+^$b) +& $d))), $shift));
    }

    method md4_round2_step ($data, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + 0x5a827999 +
                 ([+|] (($b,$b,$c) Z+& ($c,$d,$d)))), $shift));
    }

    method md4_ext_round2_step ($data, int $shift) {
        my $a := @!s[4];
        my $b := @!s[5];
        my $c := @!s[6];
        my $d := @!s[7];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + 0x50a28be6 +
                 ([+|] (($b,$b,$c) Z+& ($c,$d,$d)))), $shift));
    }

    method md4_round3_step ($data, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + 0x6ed9eba1 + ([+^] $b, $c, $d)), $shift));
    }

    method md4_ext_round3_step ($data, int $shift) {
        my $a := @!s[4];
        my $b := @!s[5];
        my $c := @!s[6];
        my $d := @!s[7];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol(($a + $data + 0x5c4dd124 + ([+^] $b, $c, $d)), $shift));
    }

    method md5_round1_step ($data, $idx, $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b, 0xffffffff +& (
             $b + rol(($a + @t[$idx] + $data +
                      (($b +& $c) +| (+^$b +& $d))), $shift)));
    }

    method md5_round2_step ($data, int $idx, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b, 0xffffffff +& (
             $b + rol(($a + @t[$idx] + $data +
                      (($b +& $d) +| (+^$d +& $c))), $shift)));
    }

    method md5_round3_step ($data, int $idx, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b, 0xffffffff +& (
             $b + rol(($a + $data + @t[$idx] + ([+^] $b, $c, $d)), $shift)));
    }

    method md5_round4_step ($data, int $idx, int $shift) {
        my $a := @!s[0];
        my $b := @!s[1];
        my $c := @!s[2];
        my $d := @!s[3];
        ($a,$d,$c,$b) = ($d, $c, $b, 0xffffffff +& (
          $b + rol(($a + $data + @t[$idx] + ($c +^ (+^$d +| $b))), $shift)));
    }

    method ripe_f1_5 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        my $e := @!s[$lr + 4];
        ($a,$e,$d,$c,$b) = ($e, $d, rol($c,10), $b, 0xffffffff +&
             ($e + rol($a + $k + $data + ([+^] $b, $c, $d), $shift)));
    }

    method ripe_f1_4 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol($a + $k + $data + ([+^] $b, $c, $d), $shift));
    }

    method ripe_f2_5 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        my $e := @!s[$lr + 4];
        ($a,$e,$d,$c,$b) = ($e, $d, rol($c,10), $b, 0xffffffff +&
             ($e + rol($a + $k + $data + (($b +& $c) +| (+^$b +& $d)),
                       $shift)));
    }

    method ripe_f2_4 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol($a + $k + $data + (($b +& $c) +| (+^$b +& $d)), $shift));
    }

    method ripe_f3_5 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        my $e := @!s[$lr + 4];
        ($a,$e,$d,$c,$b) = ($e, $d, rol($c,10), $b, 0xffffffff +&
             ($e + rol($a + $k + $data + ((+^$c +| $b) +^ $d), $shift)));
    }

    method ripe_f3_4 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol($a + $k + $data + ((+^$c +| $b) +^ $d), $shift));
    }

    method ripe_f4_5 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        my $e := @!s[$lr + 4];
        ($a,$e,$d,$c,$b) = ($e, $d, rol($c,10), $b, 0xffffffff +&
             ($e + rol($a + $k + $data + (($b +& $d) +| (+^$d +& $c)),
                       $shift)));
    }

    method ripe_f4_4 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        ($a,$d,$c,$b) = ($d, $c, $b,
             rol($a + $k + $data + (($b +& $d) +| (+^$d +& $c)), $shift));
    }

    method ripe_f5_5 (int $lr, $data, $k, int $shift) {
        my $a := @!s[$lr + 0];
        my $b := @!s[$lr + 1];
        my $c := @!s[$lr + 2];
        my $d := @!s[$lr + 3];
        my $e := @!s[$lr + 4];
        ($a,$e,$d,$c,$b) = ($e, $d, rol($c,10), $b, 0xffffffff +&
             ($e + rol($a + $k + $data + ($b +^ (+^$d +| $c)), $shift)));
    }

    method md4_comp () {
        my @s = @!s[];
        for (^16) Z (3,7,11,19) xx 4 {
            self.md4_round1_step(@!w[$^idx],$^shift);
	    self.md4_ext_round1_step(@!w[$^idx],$^shift)
                if $alg eqv "MD4ext";
        }
        for (0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15) Z (3,5,9,13) xx 4 {
            self.md4_round2_step(@!w[$^idx],$^shift);
            self.md4_ext_round2_step(@!w[$^idx],$^shift)
                if $alg eqv "MD4ext";
        }
        for (0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15) Z (3,9,11,15) xx 4 {
            self.md4_round3_step(@!w[$^idx],$^shift);
            self.md4_ext_round3_step(@!w[$^idx],$^shift)
                if $alg eqv "MD4ext";
        }
        @!s >>+=<< @s;
        @!s >>+&=>> 0xffffffff; # Should go away with sized types
        @!s[0,4] = @!s[4,0] if $alg eqv "MD4ext";
    }

    method md5_comp () {
        my @s = @!s[];
        for (^16) Z (^16) Z (7,12,17,22) xx 4 {
            self.md5_round1_step(@!w[$^didx], $^idx, $^shift);
        }
        for (1,6,11,0,5,10,15,4,9,14,3,8,13,2,7,12)
            Z (16..^32) Z (5,9,14,20) xx 4 {
            self.md5_round2_step(@!w[$^didx], $^idx, $^shift);
        }
        for (5,8,11,14,1,4,7,10,13,0,3,6,9,12,15,2)
            Z (32..^48) Z (4,11,16,23) xx 4 {
            self.md5_round3_step(@!w[$^didx], $^idx, $^shift);
        }
        for (0,7,14,5,12,3,10,1,8,15,6,13,4,11,2,9)
            Z (48..^64) Z (6,10,15,21) xx 4 {
            self.md5_round4_step(@!w[$^didx], $^idx, $^shift);
        }
        @!s >>+=<< @s;
        @!s >>+&=>> 0xffffffff; # Should go away with sized types
    }

    # RIPEMD constants
    my @lperms = [^16], { [ (7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8)[$_[]] ] }
        ... *[0]  == 4;
    my @rperms = [(9 * $_ + 5) % 16 for ^16], { [ @lperms[1][$_[]] ] }
        ... *[0]  == 12;
    my @kl = (0,0x5a827999,0x6ed9eba1,0x8f1bbcdc,0xa953fd4e);
    my @kr = (0x50a28be6,0x5c4dd124,0x6d703ef3,0x7a6d76e9,0);

    # These shifts appear in the spec, but are not used in the
    # example code, which seems to be what is used in other
    # implementations.  They may be leftover from the original
    # RIPEMD proposal, superseded by RIPEMD-128.
    # my @lr_shifts =
    #     [11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8],
    #     [12,13,11,15,6,9,9,7,12,15,11,13,7,8,7,7],
    #     [13,15,14,11,7,7,6,8,13,14,13,12,5,5,6,9],
    #     [14,11,12,14,8,6,5,5,15,12,15,14,9,9,8,6],
    #     [15,12,13,13,9,5,8,6,14,11,12,11,8,6,5,5];

    my @lshifts =
        [ 11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8 ],
        [ 7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12 ],
        [ 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5 ],
        [ 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12 ],
        [ 9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6 ];
    my @rshifts =
        [ 8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6 ],
        [ 9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11 ],
        [ 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5 ],
        [ 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8 ],
        [ 8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11 ];

    method ripe5_comp {

        my @s = @!s[];
        @!s.push(@s) if $alg eqv "RIPEMD-160";

        for @lperms[0] Z @lshifts[0] {
            self.ripe_f1_5(0,@!w[$^didx],@kl[0],$^shift);
        }
        for @rperms[0] Z @rshifts[0] {
            self.ripe_f5_5(5,@!w[$^didx],@kr[0],$^shift);
        }
        @!s[1,6] = @!s[6,1] if $alg eqv "RIPEMD-320";
        for @lperms[1] Z @lshifts[1] {
            self.ripe_f2_5(0,@!w[$^didx],@kl[1],$^shift);
        }
        for @rperms[1] Z @rshifts[1] {
            self.ripe_f4_5(5,@!w[$^didx],@kr[1],$^shift);
        }
        @!s[3,8] = @!s[8,3] if $alg eqv "RIPEMD-320";
        for @lperms[2] Z @lshifts[2] {
            self.ripe_f3_5(0,@!w[$^didx],@kl[2],$^shift);
        }
        for @rperms[2] Z @rshifts[2] {
            self.ripe_f3_5(5,@!w[$^didx],@kr[2],$^shift);
        }
        @!s[0,5] = @!s[5,0] if $alg eqv "RIPEMD-320";
        for @lperms[3] Z @lshifts[3] {
            self.ripe_f4_5(0,@!w[$^didx],@kl[3],$^shift);
        }
        for @rperms[3] Z @rshifts[3] {
            self.ripe_f2_5(5,@!w[$^didx],@kr[3],$^shift);
        }
        @!s[2,7] = @!s[7,2] if $alg eqv "RIPEMD-320";
        for @lperms[4] Z @lshifts[4] {
            self.ripe_f5_5(0,@!w[$^didx],@kl[4],$^shift);
        }
        for @rperms[4] Z @rshifts[4] {
            self.ripe_f1_5(5,@!w[$^didx],@kr[4],$^shift);
        }
        @!s[4,9] = @!s[9,4] if $alg eqv "RIPEMD-320";
        if $alg eqv "RIPEMD-160" {
            @!s = @s[1,2,3,4,0] Z+ @!s[2,3,4,0,1] Z+ @!s[8,9,5,6,7];
        }
        else {
            @!s = @!s Z+ @s;
        }
        @!s = 0xffffffff X+& @!s;
    }

    method ripe4_comp {

        my @s = @!s[];
        @!s.push(@s) if $alg eqv "RIPEMD-128";

        for @lperms[0] Z @lshifts[0] {
            self.ripe_f1_4(0,@!w[$^didx],@kl[0],$^shift);
        }
        for @rperms[0] Z @rshifts[0] {
            self.ripe_f4_4(4,@!w[$^didx],@kr[0],$^shift);
        }
        @!s[0,4] = @!s[4,0] if $alg eqv "RIPEMD-256";
        for @lperms[1] Z @lshifts[1] {
            self.ripe_f2_4(0,@!w[$^didx],@kl[1],$^shift);
        }
        for @rperms[1] Z @rshifts[1] {
            self.ripe_f3_4(4,@!w[$^didx],@kr[1],$^shift);
        }
        @!s[1,5] = @!s[5,1] if $alg eqv "RIPEMD-256";
        for @lperms[2] Z @lshifts[2] {
            self.ripe_f3_4(0,@!w[$^didx],@kl[2],$^shift);
        }
        for @rperms[2] Z @rshifts[2] {
            self.ripe_f2_4(4,@!w[$^didx],@kr[2],$^shift);
        }
        @!s[2,6] = @!s[6,2] if $alg eqv "RIPEMD-256";
        for @lperms[3] Z @lshifts[3] {
            self.ripe_f4_4(0,@!w[$^didx],@kl[3],$^shift);
        }
        for @rperms[3] Z @rshifts[3] {
            self.ripe_f1_4(4,@!w[$^didx],@kr[4],$^shift);
        }
        @!s[3,7] = @!s[7,3] if $alg eqv "RIPEMD-256";
        if $alg eqv "RIPEMD-128" {
            @!s = @s[1,2,3,0] Z+ @!s[2,3,0,1] Z+ @!s[7,4,5,6];
        }
        else {
            @!s = @!s Z+ @s;
        }
        @!s = 0xffffffff X+& @!s;
    }

    multi method do_add (Buf $block where { .elems == 64 }) {

        # Update the length count and check for problems via Sum::MDPad
        given self.pos_block_inc {
            when Failure { return $_ };
        }

        # Explode the message block into a scratchpad

        # First 16 uint32's are a straight copy of the data.
        # When endianness matches and with native types,
        # this would boil down to a simple memcpy.
        my @m = (:256[ $block[ $_+3 ... $_ ] ] for 0,4 ...^ 64);

	@!w := @m;
        self.md4_comp if $alg eqv ("MD4"|"MD4ext");
        self.md5_comp if $alg eqv "MD5";
        self.ripe4_comp if $alg eqv ("RIPEMD-128"|"RIPEMD-256");
        self.ripe5_comp if $alg eqv ("RIPEMD-160"|"RIPEMD-320");
    };

    method finalize(*@addends) {
        given self.push(@addends) {
            return $_ unless $_.exception.WHAT ~~ X::Sum::Push::Usage;
        }

        self.add(self.drain) if self.^can("drain");

        self.add(Buf.new()) unless $.final;

        :256[ 255 X+& (@!s[] X+> (0,8,16,24)) ]
    }
    method Numeric () { self.finalize };
    method buf8 () {
        self.finalize;
        Buf.new(255 X+& (@!s[] X+> (0,8,16,24)));
    }
    method Buf () { self.buf8 }
}

=begin pod

=head1 ROLES

=head2 role Sum::MD4 does Sum::MDPad
       role Sum::MD4ext does Sum::MDPad
       role Sum::MD5 does Sum::MDPad
       role Sum::RIPEMD128 does Sum::MDPad
       role Sum::RIPEMD160 does Sum::MDPad
       role Sum::RIPEMD256 does Sum::MDPad
       role Sum::RIPEMD320 does Sum::MDPad

    Classes using these roles behave as described in C<Sum::MDPad>,
    which means they have rather restrictive rules as to the type
    and number of provided addends when used with C<Sum::Marshal::Raw>.

    Mixing a C<Sum::Marshal::Block> role is recommended except for
    implementations that wish to optimize performance.

=end pod

role Sum::MD4       does Sum::MD4_5[ :alg<MD4>        ] { }
role Sum::MD4ext    does Sum::MD4_5[ :alg<MD4ext>     ] { }
role Sum::MD5       does Sum::MD4_5[ :alg<MD5>        ] { }
role Sum::RIPEMD128 does Sum::MD4_5[ :alg<RIPEMD-128> ] { }
role Sum::RIPEMD160 does Sum::MD4_5[ :alg<RIPEMD-160> ] { }
role Sum::RIPEMD256 does Sum::MD4_5[ :alg<RIPEMD-256> ] { }
role Sum::RIPEMD320 does Sum::MD4_5[ :alg<RIPEMD-320> ] { }

=begin pod

=head2 role Sum::MD2 does Sum

    The C<Sum::MD2> role is used to create a type of C<Sum>
    that calculates an MD2 message digest.  These digests should only
    be used for compatibility with legacy systems, as MD2 is not
    considered a cryptographically secure algorithm.

    The resulting C<Sum> expects 16-byte blocks as addends.  Currently
    that means a punned C<Buf> with 16 elements.  Passing a shorter Buf
    may be done once, before or during finalization.  Attempts to provide
    more blocks after passing a short block will result in an
    C<X::Sum::Final>.

    C<Sum::Marshal::Block> roles may be mixed in to allow for accumulation
    of smaller addends, to split large messages into blocks, or to allow
    for the mixin of the C<Sum::Partial> role.

=end pod

role Sum::MD2 does Sum {

    # S-Box. Spec claims this is a "nothing up my sleeve" value based on pi
    my @S =
        < 41  46  67 201 162 216 124   1  61  54  84 161 236 240   6  19
          98 167   5 243 192 199 115 140 152 147  43 217 188  76 130 202
          30 155  87  60 253 212 224  22 103  66 111  24 138  23 229  18
         190  78 196 214 218 158 222  73 160 251 245 142 187  47 238 122
         169 104 121 145  21 178   7  63 148 194  16 137  11  34  95  33
         128 127  93 154  90 144  50  39  53  62 204 231 191 247 151   3
         255  25  48 179  72 165 181 209 215  94 146  42 172  86 170 198
          79 184  56 210 150 164 125 182 118 252 107 226 156 116   4 241
          69 157 112  89 100 113 135  32 134  91 207 101 230  45 168   2
          27  96  37 173 174 176 185 246  28  70  97 105  52  64 126  15
          85  71 163  35 221  81 175  58 195  92 249 206 186 197 234  38
          44  83  13 110 133  40 132   9 211 223 205 244  65 129  77  82
         106 220  55 200 108 193 171 250  36 225 123   8  12 189 177  74
         120 136 149 139 227  99 232 109 233 203 213 254  59   0  29  57
         242 239 183  14 102  88 208 228 166 119 114 248 235 117  75  10
          49  68  80 180 143 237 31   26 219 153 141  51 159  17 131  20
        >>>.Int;

    has @!C is rw = 0 xx 16;   # The checksum, computed in parallel
    has @!X is rw = 0 xx 48;   # The digest state
    has Bool $!final is rw = False; # whether pad/checksum is in state already

    multi method do_add (*@addends) {
        sink for (@addends) { self.add($_) }
    }
    multi method do_add ($addend) {
        # TODO: Typed failure here?
        die("Marshalling error.  Addends must be Buf with 0..16 bytes.");
    }
    multi method do_add (Buf $block where { -1 < .elems < 16 }) {
        my int $empty = 16 - $block.elems;
        $!final = True;
        self.do_add(Buf.new($block.values, $empty xx $empty));
        self.do_add(Buf.new(@!C[]));
    }
    multi method do_add (Buf $block where { .elems == 16 }) {
        @!X[16..^32] = $block.values;
        @!X[32..^48] = @!X[^16] Z+^ @!X[16..^32];
        for 15,^15 Z ^16 -> $last, $x {
            @!C[$x] +^= @S[$block[$x] +^ @!C[$last]]
        }
        my $t = 0;
        for ^18 -> $j {
            for ^48 -> $k { $t = (@!X[$k] +^= @S[$t]) }
            $t += $j;
            $t +&= 0xff;
        }
        return;
    }
    method size ( --> int) { 128 };
    method add (*@addends) { self.do_add(|@addends) }
    method finalize(*@addends) {
        given self.push(@addends) {
            return $_ unless $_.exception.WHAT ~~ X::Sum::Push::Usage;
        }

        self.add(self.drain) if self.^can("drain");

        self.add(Buf.new()) unless $!final;

        :256[ @!X[^16] ]
    }
    method Numeric () { self.finalize };
    method buf8 () {
        self.finalize;
        Buf.new( @!X[^16] );
    }
    method Buf () { self.buf8 }
}

=begin pod

=head1 AUTHOR

    Written by Brian S. Julin

=head1 COPYRIGHT

    Copyright (c) 2012 Brian S. Julin. All rights reserved.  This program is
    free software; you can redistribute it and/or modify it under the terms
    of the Perl Artistic License 2.0.

=head1 REFERENCES

=head1 SEE ALSO

    C<Sum::(pm3)>

=end pod
