#!/bin/bash

#
#   Copyright 2006-2009 Adrian Thurston <thurston@complang.org>
#

#   This file is part of Ragel.
#
#   Ragel is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   Ragel is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with Ragel; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 

while getopts "gcnmleB:T:F:G:P:CDJRAZ" opt; do
	case $opt in
		B|T|F|G|P) 
			genflags="$genflags -$opt$OPTARG"
			options="$options -$opt$OPTARG"
			;;
		n|m|l|e) 
			minflags="$minflags -$opt"
			options="$options -$opt"
			;;
		c) 
			compile_only="true"
			options="$options -$opt"
			;;
		g) 
			allow_generated="true"
			;;
		C|D|J|R|A|Z)
			langflags="$langflags -$opt"
			;;
	esac
done

# Prohibitied genflags for specific languages.
cs_prohibit_genflags="-G2"
java_prohibit_genflags="-T1 -F0 -F1 -G0 -G1 -G2"
ruby_prohibit_genflags="-G0 -G1 -G2"

[ -z "$minflags" ] && minflags="-n -m -l -e"
[ -z "$genflags" ] && genflags="-B0 -T0 -T1 -F0 -F1 -G0 -G1 -G2"
[ -z "$langflags" ] && langflags="-C -D -J -R -A -Z"

shift $((OPTIND - 1));

[ -z "$*" ] && set -- *.rl

config=../src/config.h
ragel=../src/ragel

cxx_compiler="@CXX@"
c_compiler="@CC@"
objc_compiler="@GOBJC@"
d_compiler="@GDC@"
java_compiler="@JAVAC@"
ruby_engine="@RUBY@"
csharp_compiler="@GMCS@"
go_compiler="@GOBIN@"

function test_error
{
	exit 1;
}

#	split_objs=""
#	if test $split_iters != "$gen_opt"; then
#		n=0;
#		while test $n -lt $split_iters; do
#			part_root=${root}_`awk 'BEGIN {
#				width = 0;
#				high = '$split_iters' - 1;
#				while ( high > 0 ) {
#					width = width + 1;
#					high = int(high / 10);
#				}
#				suffFormat = "%" width "." width "d\n";
#				printf( suffFormat, '$n' );
#				exit 0;
#			}'`
#			part_src=${part_root}.c
#			part_bin=${part_root}.o
#			echo "$compiler -c $flags -o $part_bin $part_src"
#			if ! $compiler -c $flags -o $part_bin $part_src; then
#				test_error;
#			fi
#			split_objs="$split_objs $part_bin"
#			n=$((n+1))
#		done
#	fi

function run_test()
{
	echo "$ragel $lang_opt $min_opt $gen_opt -o $code_src $test_case"
	if ! $ragel $lang_opt $min_opt $gen_opt -o $code_src $test_case; then
		test_error;
	fi

	out_args=""
	[ $lang != java ] && out_args="-o ${binary}";
    [ $lang == csharp ] && out_args="-out:${binary}";

	# Ruby doesn't need to be compiled.
	if [ $lang != ruby ]; then
		echo "$compiler ${flags} ${out_args} ${code_src}"
		if ! $compiler ${flags} ${out_args} ${code_src}; then
			test_error;
		fi
	fi

	if [ "$compile_only" != "true" ]; then
		echo -n "running $root ... ";
		
		exec_cmd=./$binary
		[ $lang = java ] && exec_cmd="java ${root}"
		[ $lang = ruby ] && exec_cmd="ruby ${code_src}"
		[ $lang = csharp ] && [ "$csharp_compiler" = gmcs ] && exec_cmd="mono ${exec_cmd}"

		$exec_cmd 2>&1 > $output;
		if diff --strip-trailing-cr $expected_out $output > /dev/null; then
			echo "passed";
		else
			echo "FAILED";
			test_error;
		fi;
	fi
}

for test_case; do
	root=${test_case%.rl};

	if ! [ -f "$test_case" ]; then
		echo "runtests: not a file: $test_case"; >&2
		exit 1;
	fi

	# Check if we should ignore the test case
	ignore=`sed '/@IGNORE:/s/^.*: *//p;d' $test_case`
    if [ "$ignore" = yes ]; then
        continue;
    fi

	# If the generated flag is given make sure that the test case is generated.
	is_generated=`sed '/@GENERATED:/s/^.*: *//p;d' $test_case`
	if [ "$is_generated" = yes ] && [ "$allow_generated" != true ]; then
		continue;
	fi

	expected_out=$root.exp;
	sed '1,/_____OUTPUT_____/d;$d' $test_case > $expected_out

	lang=`sed '/@LANG:/s/^.*: *//p;d' $test_case`
	if [ -z "$lang" ]; then
		echo "$test_case: language unset"; >&2
		exit 1;
	fi

	case $lang in
		c++)
			lang_opt=-C;
			code_suffix=cpp;
			compiler=$cxx_compiler;
			flags="-pedantic -ansi -Wall -O3"
		;;
		d)
			lang_opt=-D;
			code_suffix=d;
			compiler=$d_compiler;
			flags="-Wall -O3"
		;;
		c)
			lang_opt=-C;
			code_suffix=c;
			compiler=$c_compiler;
			flags="-pedantic -ansi -Wall -O3"
		;;
		obj-c)
			lang_opt=-C;
			code_suffix=m;
			compiler=$objc_compiler
			flags="-Wall -O3 -fno-strict-aliasing -lobjc"
		;;
		java)
			lang_opt=-J;
			code_suffix=java;
			compiler=$java_compiler
			flags=""
		;;
		ruby)
			lang_opt=-R;
			code_suffix=rb;
			compiler=$ruby_engine
			flags=""
		;;
        csharp)
            lang_opt="-A";
            code_suffix=cs;
            compiler=$csharp_compiler
            flags=""
        ;;
        go)
			lang_opt="-Z"
			code_suffix=go
			compiler=$go_compiler
			flags="build"
		;;
		indep)
			lang_opt="";

			for lang in c d cs go java ruby; do
				case $lang in 
					c) lf="-C" ;;
					d) lf="-D" ;;
                    cs) lf="-A" ;;
					go) lf="-Z" ;;
					java) lf="-J" ;;
					ruby) lf="-R" ;;
				esac

				echo "$langflags" | grep -e $lf >/dev/null || continue

				targ=${root}_$lang.rl
				echo "./trans $lang $targ $test_case $lang ${root}_${lang}"
				if ! ./trans $lang $targ $test_case ${root}_${lang}; then
					test_error
				fi
				echo "./runtests -g $options $targ"
				if !  ./runtests -g $options $targ; then
					test_error
				fi
			done
			continue;
		;;
		*)
			echo "$test_case: unknown language type $lang" >&2
			exit 1;
		;;
	esac

	# Make sure that we are interested in the host language.
	echo "$langflags" | grep -e $lang_opt >/dev/null || continue

	code_src=$root.$code_suffix;
	binary=$root.bin;
	output=$root.out;

	# If we have no compiler for the source program then skip it.
	[ -z "$compiler" ] && continue

	additional_cflags=`sed '/@CFLAGS:/s/^.*: *//p;d' $test_case`
	[ -n "$additional_cflags" ] && flags="$flags $additional_cflags"

	prohibit_minflags=`sed '/@PROHIBIT_MINFLAGS:/s/^.*: *//p;d' $test_case`
	prohibit_genflags=`sed '/@PROHIBIT_GENFLAGS:/s/^.*: *//p;d' $test_case`

	case $lang in
	csharp) prohibit_genflags="$prohibit_genflags $cs_prohibit_genflags";;
	java) prohibit_genflags="$prohibit_genflags $java_prohibit_genflags";;
	ruby) prohibit_genflags="$prohibit_genflags $ruby_prohibit_genflags";;
	esac

	[ $lang == obj-c ] && continue;

	for min_opt in $minflags; do
		echo "" "$prohibit_minflags" | grep -e $min_opt >/dev/null && continue
		for gen_opt in $genflags; do
			echo "" "$prohibit_genflags" | grep -e $gen_opt >/dev/null && continue
			run_test
		done
	done
done
