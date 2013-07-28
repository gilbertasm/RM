#! /usr/bin/perl
use strict;
use warnings;
use Math::Combinatorics;
use Bit::Vector;
use Data::Dumper;
use Image::BMP;


my $r; my $m; my $p;
if ( $#ARGV < 3) {
	print "neteisingas argumentu skaicius:\n";
	usage();
	exit();
}

my $input_file, my $output_file;
check_r_m_p();
print "|$p|\n";
if (defined($ARGV[4])) {
	$input_file = $ARGV[4];
} else {
	$input_file = 'lena128.bmp';
}

if (defined($ARGV[5]))  {
	$output_file = $ARGV[5];
} else {
	$output_file = 'lena128_out.bmp';
}


#my $p = $ARGV[3];

if ($ARGV[0] eq '-is') {
	image_send($r, $m, $input_file, $output_file, $p);
} elsif ($ARGV[0] eq  '-id') {
	image_encode_decode($r, $m, $input_file, $output_file, $p);
} elsif ($ARGV[0] eq '-ts') {
	send_text($r, $m, $p);
} elsif ($ARGV[0] eq '-te') {
	code_decode_text($r, $m, $p);
} elsif ($ARGV[0] eq '-int') {
	interactive_input($r, $m, $p);
} else {
	usage();
}

sub check_r_m_p {
    if ( ($ARGV[1] < 0) && ($ARGV[2] < 1) ) {
        print "neteisingi kodo parametrai r ir m\n";
        exit;
    } else {
        $r = $ARGV[1];
 	$m = $ARGV[2];
    }
    
    if ( ($ARGV[3] < 0) or ($ARGV[3] > 1)) {
        print "neteisingai nurodyta tikimybe\n";
	exit;
    } else {
	$p = $ARGV[3];
    }
} 



sub usage {
    print "$0 -is|-id|-ts|-te|-int r m tikimybe [input_file] [output_file]";
    exit();
}


 

# Suskaido paveiksliuko i reikiamo ilgio vektorius ir
# siuncia kanalu su iskraipymo tikimybe $p. Is gautu vektoriu atgamina
# paveiksliuka ir ji issaugo
# In: $r - kodo parametras r
#     $m - kodo parametras m
#     $input - paveikliuko failo pavadinimas
#     $p - kraipymo tikimybe
#     $out-  is gautu vektoriu issaugoto paveiksliuko pavadinimas 
# Out: 
sub image_send {
    my $r = shift;
    my $m = shift;
    my $input = shift;
    my $out = shift;
    my $p = shift;
    #$out =~ s/(.*)\.bmp/$1_out\.bmp/;
    
    (my $vardai, my $matrix, my $n) = generate_matrix($r, $m);
    
	
    my $img = new Image::BMP(
	        file            => "$input",
    );
	
	
	
    my $plotis  = $img->{Width} - 1;
    my $aukstis = $img->{Height} -1 ; 
    my @binary_text;
	
	
    for my $width (0..$plotis ) {
         for my $height (0..$aukstis) {
             #$picture_ref->[$width][$height] = $img->xy_index($width,$height);
             push @binary_text, split (//, sprintf ("%08b", $img->xy_index($width,$height) ) );
				
         }
    }
	
	
    my $string = join "", @binary_text;
	
    my $length_str = length($string);
	
    (my $blokai, my $liko) = get_blocks($n, $string, $length_str);
# 	
    my $encoded;
    my $su_triuksmu;
    my @encoded_vec;

    for my $block (@$blokai) {
        my $vector = Bit::Vector->new_Bin($n,$block);
        $su_triuksmu = make_noise($vector, $p);
        push @encoded_vec, $su_triuksmu;	
    }
	
	
    my @temp;
    for my $enc_vec (@encoded_vec) {
        my $string = $enc_vec->to_Bin;
        push @temp, split (//, $string);
    }
    
    my $rez = join "", @temp;
    ($blokai, $liko) = get_blocks(8, $rez, $length_str);
     
    my $z = 0;
    for  my $i (0 .. $plotis) {
        for my  $j (0 .. $aukstis ) {
            $img->xy_index($i,$j, oct "0b$blokai->[$z++]" );
 	}
    }
	
    $img->save($out);
	      
}


# Suskaido paveiksliuka i reikiamo ilgio vektorius, juo uzkoduoja ir
# siuncia kanalu su iskraipymo tikimybe $p. Tada dekoduoja ir
# is gautu vektoriu atgamina
# paveiksliuka ir ji issaugo
# In: $r - kodo parametras r
#     $m - kodo parametras m
#     $input - paveikliuko failo pavadinimas
#     $p - kraipymo tikimybe
#     $out-  is gautu vektoriu issaugoto paveiksliuko pavadinimas 
# Out: 
sub image_encode_decode {
	
    my $r = shift;
    my $m = shift;
    my $input = shift;
    my $out = shift;
    my $p = shift;
    
    (my $vardai, my $matrix, my $n) = generate_matrix($r, $m);
    
	
    my $img = new Image::BMP(
	        file            => "$input",
    );
	
	
	
    my $plotis  = $img->{Width} - 1;
    my $aukstis = $img->{Height} -1 ; 
    my @binary_text;
	
	
    for my $width (0..$plotis ) {
        for my $height (0..$aukstis) {
            push @binary_text, split (//, sprintf ("%08b", $img->xy_index($width,$height) ) );		
        }
    }
	
	
    my $string = join "", @binary_text;
	
    (my $blokai, my $last) = get_blocks($n, $string, length($string));
	
     my @encoded_vec;	
     my $encoded;
     my $su_triuksmu;
	    

    for my $block (@$blokai) {
        my @zodis = split //, $block;
        $encoded = encode_word($matrix, \@zodis);
        $su_triuksmu = make_noise($encoded, $p); 
        push @encoded_vec, $su_triuksmu;
        #print $block chr(oct "0b$block");
    }
		

		
    my @decoded;
    my $su_triuksmu_copy;
    my $coef;
		
    for my $enc_vec (@encoded_vec) {
        $su_triuksmu_copy = $enc_vec->Clone();
        $coef = find_coef($vardai, $matrix, $su_triuksmu_copy, $r, $m);
        push @decoded, @$coef;
    }

    my $rez = join "", @decoded;
	
    ($blokai, $last) = get_blocks(8, $rez, length($string));
	
    my $z = 0;
    for  my $i (0 .. $plotis) {
        for my  $j (0 .. $aukstis ) {
            $img->xy_index($i,$j, oct "0b$blokai->[$z++]" );
 	    #print $linijos[$i][$j], " ", $i, $j, "\n" if $linijos[$i][$j] < 255;
 	}
    }
	
    $img->save($out);

}

# Nuskaito ir suskaido teksta i reikiamo ilgio vektorius ir
# kiekviena vektoriu siuncia kanalu su kraipymo tikimye p nenaudodama kodo, 
# is gauto vektoriaus atgamina teksta ir ji parodo
# In: $r, $m - kodo paramtrai r, m
#     $p - lraipymo tikimybe
# Out:  
sub send_text {
    my $r = shift;
    my $m = shift;
    my $p = shift;
    
    (my $vardai, my $matrix, my $n) = generate_matrix($r, $m);
    
    my $block_size = $n;
	
     print "Iveskite teksta: baigite <ctrl-d>\n";
     my $string;
	
    {
        local( $/, *FH ) ;
        $string = <STDIN>
    }


	
    my $text = text_to_binary($string);
    #@print "$text\n";
    (my $blokai, my $liko) = get_blocks(8, $text, length($text));
    #print $n, " ", $liko, "\n";
	
	
    my $encoded;
    my $su_triuksmu;
    my @encoded_vec;
    #print join "", @$blokai, "\n";
    for my $block (@$blokai) {
        #my @zodis = split //, $block;
 	my $vector = Bit::Vector->new_Bin(8,$block);
        $su_triuksmu = make_noise($vector, $p);
 	push @encoded_vec, $su_triuksmu;
    }
	
	
	
    my @temp;
    for my $enc_vec (@encoded_vec) {
        my $string = $enc_vec->to_Bin;
        push @temp, split (//, $string);
    }
    
    my $rez = join "", @temp;
    ($blokai, $liko) = get_blocks(8, $rez, length($text));
    
    #print Dumper ($ats);
     
    print "\n";
    for my $word (@$blokai) {
        print chr(oct "0b$word");
    }	  
}

# Nuskaito ir suskaido teksta i reikiamo ilgio vektorius ir uzkodavus
# kiekviena vektoriu siuncia juos kanalu su kraipymo tikimye p, ji atkoduoja, 
# is gauto vektoriaus atgamina teksta ir ji parodo
# In: $r, $m - kodo paramtrai r, m
#     $p - lraipymo tikimybe
# Out:  
sub code_decode_text {
    my $r = shift;
    my $m = shift;
    my $p = shift;
    
    (my $vardai, my $matrix, my $n) = generate_matrix($r, $m);
    
    my $block_size = $n;
    my $string;
    print "Iveskite teksta: baigite <ctrl-d>\n";
    {
        local( $/, *FH ) ;
        $string = <STDIN>
    }
	

    my $text = text_to_binary($string);
    #print "$text\n";
    (my $blokai, my $liko) = get_blocks($n, $text, length($text));
    #print $n, " ", $liko, "\n";
	
    my @encoded_vec;
    #my @zodis ;
    my $encoded;
    my $su_triuksmu;
    
    #print join "", @$blokai, "\n";
    for my $block (@$blokai) {
        my @zodis = split //, $block;
        $encoded = encode_word($matrix, \@zodis);
        $su_triuksmu = make_noise($encoded, $p); 
        push @encoded_vec, $su_triuksmu;
	#print $block chr(oct "0b$block");
    }
	
	
    my @decoded;
    my $su_triuksmu_copy;
    my $coef;
	
    for my $enc_vec (@encoded_vec) {
        $su_triuksmu_copy = $enc_vec->Clone();
        $coef = find_coef($vardai, $matrix, $su_triuksmu_copy, $r, $m);
        push @decoded, @$coef;
    }
    
    #print "\n", scalar @decoded, "\n";
    
    my $rez = join "", @decoded;

    #print $rez, "\n";
    ($blokai, $liko) = get_blocks(8, $rez, length($text));
    
    #print Dumper ($ats);
     
    print "\n";
    for my $word (@$blokai) {
        #print "$word\n";
        print chr(oct "0b$word");
    }
    
    #print scalar @, " ", scalar @encoded_vec, "\n";
	    
	  
}

#interactive_input(1,3);


# Grazina reikiamo ilgio blogus is dvejetainio simboliu srauto
# In: $block_size - bloko dydis,
#     $text - dvejetainiu simboliu eilute
#     $len  - jos ilgis;
# Out: \@blokai - bloku masyvas su $block_size dydzio elementais
#      $last_size - kiek simboliu truku uzpildyti paskutini bloka
sub get_blocks {
	(my $block_size, my $text, my $len) = @_;
	my $i = $block_size;
	#my $string_len = length($text);
	my @blokai, my $substring, my $n;
	my $last_size;
		
	for ($i = 0; $i <= $len; $i += $block_size) {
	
	    $substring = substr($text, $i , $block_size);
	    
	    #print $substring, "\n";
	    $n = length($substring);
	    
	    #print "$n\n";
	    if ($n < $block_size and $n != 0) {
		    
		    $substring = $substring . 0 x  ($block_size - $n);
		    $last_size = $block_size - $n;
		    push @blokai, $substring;
	        last;
	    } else {
	       push @blokai, $substring;
        }
    }

    #print "$last_size\n";
    return (\@blokai, $last_size);
}










# Teksta pavercia dvejetaine eilute
#In: $text - tekstas;
#Out: $binary_text - dvejetaine eilute
sub text_to_binary {
	my $text = shift;
	my @binary_text;
	my @temp;
	
	foreach my $char (split //, $text) {
		push @binary_text, split (//, sprintf("%08b", ord($char) ) );
        
    }
    
    my $binary_text = join "", @binary_text;
    #print "$binary_text\n";

    return $binary_text;
	
} 







#print scalar @$ats, "\n";



# Nuskaito zodi is stdin, ir patikrina jo ilgi su n
# In:
# Out: $input - zodis, jei ilgis == n
sub get_word {
	my $n = shift;
	my $input = <STDIN>;
	chomp $input;
	if (length($input) != $n) {
		print "Ilgis turi buti $n\n";
		exit;
	}
	return $input
}

sub show_klaidas {
	
	(my $vec1, my $vec2) = @_;
	my $vec = $vec1->Shadow();
	#print "$vec1 ", $vec1->to_Bin, "\n";
	#print "$vec2 ", $vec2->to_Bin, "\n";
	$vec->Xor($vec1, $vec2);
	print $vec->to_Bin(), "\n";
}


# Nuskaito vektoriu is F2 kuno elementu, patikrina ar jo ilgis korektiskas,
#  Uzkoduoja Reedo-Mulerio kodo, parodo koda, siuncia kanalu su iskraipymo tikimybe
# p, parodo gauta is kanlo zodi ir jame aptiktas klaidas, dekoduoja ta zodi
# ir atspausdina
# Pries dekodavima galima redaguoti uzkoduota zodi
# In: $r, $m - kodo parametrai r ir m
# $p - kraipymo tikimybe $p;
sub interactive_input {
    my $r = shift;
    my $m = shift;
    my $p = shift;
    
    (my $vardai, my $matrix, my $n) = generate_matrix($r, $m);
    
	print "iveskite $n ilgio vektoriu, kurio elementai is F2 kuno\n";
	
	my $input = get_word($n);
	
	my @zodis = split //, $input;
	my $encoded = encode_word($matrix, \@zodis);
	print "Uzkoduotas zodis:\n", $encoded->to_Bin(), "\n";
	
	print "Iveskite iskraipimo tikimybe 0 <= p <= 1\n";
# 	my $p = <STDIN>;
# 	chomp $p;
# 	if ( ($p > 1) || ($p < 0)) {
# 		print "p turi buti intervale [0,1]\n";
# 	}
	
	print "Is kanalo isejas zodis:\n";
	
	my $su_triuksmu = make_noise($encoded, $p); 
	print $su_triuksmu->to_Bin(), "\n";
	
	print "Klaidos tose pozicijose, kur 1\n";
	show_klaidas($su_triuksmu, $encoded);
	
	print "Ar noresite redaguoti isejusi is kanalo zodi?<y,n>?\n";
	my $ans = <STDIN>; chomp $ans;
	if ($ans =~ /^y|^yes/i) {
		print "Iveskite ", 2 ** $m, "ilgio zodi\n";
		my $input = get_word(2 ** $m);
		$su_triuksmu =  Bit::Vector->new_Bin(2 ** $m, $input);
	}
		
	print "Dekoduotas zodis:\n";
	my $su_triuksmu_copy = $su_triuksmu->Clone();
	my $coef = find_coef($vardai, $matrix, $su_triuksmu_copy, $r, $m);
	print @$coef, "\n";
}


# Siuntimo kanalu simuliacija
# Iskraipo simbolius uzkoduotame zodije
# In: $vec - zodis
#     $slenkstis - tikimybe intervale [0,1]
# Out: Iskraipytas zodis
sub make_noise {
	(my $vec_old, my $slenkstis) = @_;
	my $size = $vec_old->Size();
    my $i = 0;
    my $random;
    my $vec_new = $vec_old->Clone(); 
    for my $index (0..$size - 1) {
	    # kiekvienam siunciamam kuno F2 elementui traukiamas atsitiktinis
	    # skaicius  $random is intervalo [0,1]. Jei a mazesnis uz klaidos tikimybe
	    # $slenkstis, siunciama elementa kanalas iskraipo
	    
	    $random = rand(); # grazina is intervalo [0,1]
	    if ($random < $slenkstis) {
		    $vec_new->bit_flip($index);
	    }

    }
    #print "Su triuksmu: " , $vec_new->to_Bin(), "\n";
	return $vec_new;
} 

#my @zodis = (1,0,1,1,1,1,1,1,1,0,0,0,0,0,0,1);

# my $encoded = encode_word($ats, \@zodis);
# my $string = sprintf ($encoded->to_Bin);
# my $err = Bit::Vector->new_Bin(length($string), $string);
# my $coef = find_coef($vardai, $ats, $err, 2, 5, 8);
# print  Dumper ($coef) ,"\n";



# procedura sugeneruoja kodavimo matricos pradine dali
# t.y. m+1 vektoriu 1...1,x1, x2,.., xm, kuriu elementai is kuno F2
# In: kodo parametras m
# Out: m vektoriu, kuriu ilgis 2^m
sub generate_pradinius_x {

    my @pradiniai_x;
    my $m = shift;

    #pirmas vektorius susideda is 2^m vienetu
    my $string = 1 x (2 ** $m);
    #Pasidarome bitu vektoriu, kad butu efektyviau
    my  $vector = Bit::Vector->new_Bin(2 ** $m, $string);
    push @pradiniai_x, $vector;
    for (my $i = $m - 1; $i >= 0; $i--) {
        push @pradiniai_x, _generate_x($m, $i);
    }
    return \@pradiniai_x
}

# sugeneruoja m vektoriu x1, ..., xm
# Vidine procedura, kvieciama is generate_pradinius_x
# In: kodo parametras m ir slenkstis i
# Out: grazina 2^m ilgio vektoriu, kur eina 2^i vientu, po to
# 2^i nuliu ir vel taip pat iki 2^m
sub _generate_x {
    
    my @x; my @tarp;
    my ($ilgis, $kiek) = @_;
    my $galas = 2 ** $kiek;
    for my $i (1 .. $galas) {
        push @tarp, 1;
    }

    for my $i (1 .. $galas) {
        push @tarp, 0;
    }

    #print $ilgis, " ", $kiek, "\n";
    my $ilgis_bitais = 2 ** $ilgis;
    my $bloko_ilgis = $ilgis_bitais / $galas/2;
    #print "bloko ilgis: ", $bloko_ilgis, "\n";
    for my $i (1 .. $bloko_ilgis) {
        push @x, @tarp;
    }
    my $string = join "", @x;
    #print "\$string, $string\n";
    my $vector = Bit::Vector->new_Bin($ilgis_bitais,$string);

    
    return $vector;
}
        
# sugeneruoja skaicius nuo 1 iki m
# jie bus reikalinga skaiciuojant kombinacijas
# In: kodo parametras m
# Out : masyvas @n su reiksmemis nuo 1 iki m
sub generate_n {
    my $m = shift;
    my @n;
    for my $i (1 .. $m) {
        push @n, $i;
    }
    return @n;
}


# sugeneruoja m vektoriu vardu
# In: kodo parametras m
# Out: masyvas @a su m vektoriu vardais, kuriu 
# reiksmes atitinka  kodavimo matricos 2 .. m+1 eilutes
sub generate_vektoriu_vardus {
    my $m = shift;
    my @a; # = generate_n($m);
    for my $i (1 .. $m) {
        push @a, [$i];
    }
    return @a;
}
        
    
#my @ats = combine(2,@a);
#print Dumper($ats);


# Sugeneruoja RM kodavimo matrica ir vektoriu vardu masyva
# In: kodo parametrai r ir m
# Out: vektoriu vardai  @vardai, kodavimo matrica $pradiniai
sub generate_matrix {
    my ($r, $m) = @_;
    my (@vardai, $n);

    #sugeneruojame m vektoriu vardus
    my @a = generate_n($m);

    #sugeneruojame pradinius m+1 vektoriu
    my $pradiniai = generate_pradinius_x($m);

    #Dabar sugeneruojame pradiniu  m kombinacijas,
    #pradedant po 2 vektorius, baigian po m t.y
    #C(2,m), ..., C(m,m)
    for my $range (2 .. $r) {
        my @tarp = combine($range, @a);
        $n += @tarp;
        push @vardai, @tarp;
    }
    
    #print "N, $n\n";
    #print Dumper(\@vardai);

    #Dabar pagal sugeneruotas vardu kombinacijas
    #generuosime kodavima matricos vektorius.
    #Noredami gauti sugeneruotai kombinacijai atitinkanti vektoriu
    #sudauginami tos kombinacijos komponentes atitinkancius vektorius ir
    #patalpiname ji i kodavimo matrica

    for my $combination (@vardai) {
    # print "combination @$combination\n";
        my $vector;

        #print "$combination->[0]\n";
        #print Dumper($pradiniai->[$combination->[1] ]);
        
        #Sudauginame pirmus du vektorius
        $vector = vector_sandauga($pradiniai->[$combination->[0] ],
                       $pradiniai->[$combination->[1] ]);
        
        #print $#$combination, "-->", @$combination; 
        
        # Po viena dauginame likusius, jeigu ju yra
        for (my $i = 2; $i < @$combination; $i++) {
             # print "cikle\n";
            $vector->Intersection($vector, $pradiniai->[$combination->[$i] ]);
        }
        push @$pradiniai, $vector; 
    }

    unshift @vardai, generate_vektoriu_vardus($m);
    $n = 1 + @vardai;
    
    #print "&&&&\n";
    #print Dumper (\@vardai);
    #print "&&&&&\n";
    return (\@vardai, $pradiniai, $n);
}







# Uzkoduoja zodi
# In: $matrix - kodavimo matrica
#     $word   - zodis
# Out: uzkoduotas zodis
sub encode_word {
	(my $matrix, my $word) = @_;
	my $pradinis = $matrix->[0]->Shadow();
	for (my $i = 0; $i < @$word; $i++) {
	    
	    if ($word->[$i] != 0) {
	       $pradinis->Xor($pradinis, $matrix->[$i]);
	    }  
    }
    
    return $pradinis;
}
	


# Sugeneruojame charakteristiniu vektoriu pradiniu simboliu aibe.
# Pvz jei m = 4, ir $polinomas = x3x4, tai sugenreuosime
# x1, x2, -x1, -x2
# In: polinomo simbolinis vardas $polinomas, kodo parametras $m
# Out: pradiniu simboliu aibe 
sub make_simb_aibe {
    (my $polinomas, my $m, my $r) = @_;
    my @prad_symb;
    my @prad_neg;
    for my $i (1 .. $m) {
        unless (grep $_ == $i, @$polinomas) {
            push @prad_symb, $i;
            push @prad_neg, -$i;
        }
    }
    
    push @prad_symb, @prad_neg;
    
    return @prad_symb;
}


# Patikrina ar sugenruota kombinacija yra tinkama
# t.y. kad nebutu xi ir -xi
sub yra_blogas {
    my $pol = shift;
    for my $digit (@$pol) {
        if (grep $_ == -$digit, @$pol) {
            return 1;
        }
    }
    return 0;
}

# Sugeneruoja charakteristinius vektorius
# In: $polinomas - polinomas, kurio generuosime charak. vektorius
#     $m, $r - kodo parametrai m ir r
#     $matrix - kodavimo matrica R(r,m)
#     $kiek - kiek sugenruoti vektoriu (2^(m-r))
# Out: \@vectors - charakteristiniai vektoriai


sub generate_charec_vectors {
    (my $polinomas, my $m, my $r, my $matrix) = @_;
    my @n = make_simb_aibe(@_);
    my @vectors;
    my $i = 0;
    #print "N - @n\n"; print @$polinomas;
    my @combinations = combine($m - @$polinomas, @n);
    my @indices = grep {!yra_blogas($combinations[$_])} 0..$#combinations;
    my @good_combinations = @combinations[@indices];
    #print "_______\n";
    
    #print "pol @$polinomas\n";
    #print "good_comn @good_combinations\n";
    if (scalar @good_combinations == 1) {
        #print "IFFFFFFFFFFFF\n";
        push @vectors, $good_combinations[0];
    } else {
        for my $combination (@good_combinations) {
            ++$i;
            if (@$combination == 1) {
                push @vectors, $matrix->[$combination->[0]];
            } else {
                my $vec =  multiply_combination($combination, $matrix);
                #print "@$combination\n", " <--->", $vec->to_Bin(), "\n";
                push @vectors, $vec;
                #last if $i > $kiek;
            }
        }
    }
        
    return \@vectors;


}

# Spausdina vektoriu masyva
sub print_vec {
    my $vec = shift;
    for my $v (@$vec) {
        print $v->to_Bin(), "\n";
    }
    
}




# Suranda, kurios matricos eilutes buvo naudojamaos uzkoduojant zodi.
# Sie koeficientai ir yra SIUSTAS ZODIS, t.y. si funkcija dekoduoja uzkoduota
# zodi 
# In: $combination kodavimo matricos polinomu vardai
#     $matrix - kodavimo matrica R(r,m)
#     $error  - uzkoduotas zodis
#     $m, $r - kodo parametrai m ir r
#    
# Out: \@coef - atkoduotas zodis
 
sub find_coef {
    my @coef;
    (my $combination, my $matrix, my $error ,my $r, my $m) = @_;
    
    my $i = $#$matrix;
    my $recent_end;
   
        # perziurim visas matricos eilutes, 
        # kurias atitinka nuo r iki 1 laipsnio polinomai
        # (t.y. nuo matricos apacios i virsu)
        for (my $j = $r; $j >= 1; $j--) {
            $recent_end = $i;
            
            # nagrinejame einamojo j ilgio polinomus
            while ((@{$combination->[$i-1]} == $j) && ($i > 0)) {
                
	            #einamaijai eilutei sugeneruojame charakteristinius vektorius
                my $vectors = generate_charec_vectors($combination->[$i-1], $m, $r,
                        $matrix);
               
                # pagal daugumos logikos taisykle randame ar ta eilute
                # buvo naudota koduojant zodi (1) ar ne (0)
                unshift @coef, major_logic($vectors, $error);
                $i--;
            }
            
            # sudauginame j laipsni atitinkanciu matricos eilutes su ju
            # ka tik suskaiciuotais koef
            my $vec = vektorius_matrica(\@coef, $matrix, $i, $recent_end);
            
            #gauta vektoriu atimame is uzkoduoto zodzio
            $error = vector_sudetis($error, $vec);

           


    }
    
    # 1-es matricos eilutes (sudarytos is vienetu) koef. randame
    # patikrindami ar daug 1 ar 0 yra auksciau modifikuotame uzkoduotame zodyje
    if (find_most_in_vec($error) == 0) {
        unshift @coef, 0;
    } else {
        unshift @coef, 1;
    }
   
    return \@coef;
}



# Sudaugina gauta zodi su vienos matricos eilutes charakteristiniais vektoriais
# ir pagal daugumo logikos taisykle nustato ar tos eilutes koefcinetas koduojant
# zodi buvo 0 ar 1
# In: $vector - charakterstiniai vektoriai
#     $error - užkoduotas zodis
# Out: 0 ar 1
sub major_logic {
    my $vectors = shift;
    my $error   = shift;
    my @booleans;
    for my $vector (@$vectors) {
        push @booleans, dot_product($vector, $error);
    }
    _find_most(\@booleans);

}

# vidine procedura, suskaiciuoja ar daugiau reiksmiu yra 1 ar 0 ir atitinkamai
# grazina 1 ar 0
# Jei 1 ir 0 yra po lygiai, tai grazina 0
# In: $values - boolinis masyvas
# Out: 0 arba 1
sub _find_most {
    my $values = shift;
    
    my %hash;
    for my $digit (@$values) {
        $hash{$digit}++;
    }
    
    if (! defined($hash{0})) {
	    return 1;
    }
    
    if (! defined($hash{1})) {
	    return 0;
    }
    
    if ($hash{0} < $hash{1}) {
        return 1;
    } else {
        return 0;
    }
}

# vidine procedura, suskaiciuoja ar daugiau reiksmiu yra 1 ar 0 ir atitinkamai
# grazina 1 ar 0
# Jei 1 ir 0 yra po lygiai, tai grazina 0
# In: $vec - Bit::Vector objektas4
# Out: 0 arba 1
sub find_most_in_vec {
    my $vec = shift;
    my $size = $vec->Size();
    my $i = 0;
   
    for my $index (0..$size - 1) {
        if ($vec->bit_test($index)) {
            $i++;
        }
    }

    
    if ($i > $size - $i) {
        return 1;
    } else {
        return 0;
    }
}


#######################################################
# Operacijos su vektoriais, kuriu elementai yra is kuno F2


# Suskaiciuoja dvieju vektoriu  skaliarine sandauga (dot_product)
# Kadangi del efektyvumo mes dirbame su bitu vektoriu,
# sandauga galima realizuoti taip: pritaikome dviem bitu vektoriam
# AND operacija ir suskaiciuojame rezultato vienetu skaiciu
# Jei vienu skaicius lyginis, tai rezultatas 0, kitu atveju - 1
# In: bitu vektoriai vec1 ir vec2
# Out: vektoriu skaliarine sandauga (vec1 . vec2)
#
sub dot_product {
    (my $vec1, my $vec2) = @_;
    my $vec = vector_sandauga($vec1,$vec2);
    my $size = $vec->Size();
    my  $i=0;
    for my $index (0..$size - 1) {
        if ($vec->bit_test($index)) {
            $i++;
        }
    }
    return $i % 2;
}

# Suskaiciuoja 2 vektoriu sandauga ir rezultata issaugo naujame vektoriuje
# Vektoriu is kuno F2 sandauga atitinka bitu vektoriu AND operacija
# In: vektoriai vec1 ir vec2
# Out: vec = vec1 * vec2
sub vector_sandauga {
    (my $vec1, my $vec2) = @_;
    my $vec = $vec1->Clone();
    $vec->And($vec1, $vec2);
    return $vec;
}

# Sudeda du vektorius
# Tai atitinka bitu vektoriu xor operacija
# (1 + 1 = 0, 1 + 0 = 1, 0 + 1 = 0, 0 + 0 = 0)
# In: vektoriai vec1 ir vec2
# Out: vec1 = vec1 + vec2
sub vector_sudetis {
    (my $vec1, my $vec2) = @_;
    $vec1->Xor($vec1, $vec2);
    return $vec1;
}


# Sudaugina kelis vektorius
# In: $combination - polinomo simbolinis vardas
#     $matrix - kodavimo matrica

# Out: $vec1 - sudauginti $combination atitinkantis vektoriai

sub multiply_combination {

     

    (my $combination, my $matrix) = @_;

    my $vec1 = $matrix->[0]->Shadow();
    my $vec2 = $matrix->[0]->Shadow();
    
    #print scalar @$matrix, "\n";
    #print "comb: @$combination\n";
    if ($combination->[0] < 0) {
        $vec1 = $matrix->[abs($combination->[0])]->Clone();
        $vec1->Flip();
    } else {
        $vec1 = $matrix->[$combination->[0]]->Clone();
    }


     if ($combination->[1] < 0) {
        $vec2 = $matrix->[abs($combination->[1])]->Clone();
        $vec2->Flip();
     } else {
        $vec2 = $matrix->[$combination->[1]]->Clone();
     }

     # print "------------------------\n";
     # print $vec1->to_Bin, "\n";
     # print $vec2->to_Bin, "\n";

     $vec1->And($vec1, $vec2);

     for (my $i = 2; $i < @$combination; $i++) {

         if ($combination->[$i] < 0) {
             $vec2 = $matrix->[abs($combination->[$i])]->Clone();
             $vec2->Flip();
         } else {
             $vec2 = $matrix->[$combination->[$i]]->Clone();
         }
     

         # print $vec2->to_Bin,"\n";
         $vec1->And($vec1, $vec2);
     }

     # print $vec1->to_Bin, "\n";
     # print "--------------------------\n";
     return $vec1;
}

# Sudaugina vektoriu su matrica (atitinkamu dimensiju)
# In: $zodis - vektorius
#     $mat   - kodavimo matrica 
#     $index, $pabaiga - matricos porcija, kuria dauginsime su veltoriumi
#     $index - matricos eilute, nuo kurios pradet daugint 
#     $pabaiga - matricos eilute, kuria bagiti daugint
sub vektorius_matrica {
    my ($zodis, $mat, $index, $pabaiga) = @_;
    my $pradinis = $mat->[$index]->Shadow();
    #print $pradinis->to_Bin, "pradinis\n";
    #$pradinis->Xor($pradinis, $mat->[$index])  if $zodis->[0] != 0;
    #print "Index: $index\n";
    #print "zodis - @$zodis\n";
    
   # print "vektorius_matrica\n";
   #print $pradinis->to_Bin, "\n";
    for (my $i = $index+1, my $j = 0; $i <= $pabaiga; $i++, $j++) {
       if ($zodis->[$j] != 0) {
           $pradinis->Xor($pradinis, $mat->[$i]);
       }  
        #print $pradinis->to_Bin, "\$i: $i\n";

    }
    #print "$index+1 \n";
    # print "end vektor_matrica\n";
    #print_vec($mat);
    return $pradinis;
}






