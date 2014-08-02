#!/usr/bin/perl -w

use strict;

use BSD::Resource qw(times);
use File::Temp qw(tempfile);
use JSON;
use List::Util qw(sum);
use Statistics::Descriptive;

# Versions to test
my @versions = (
    { id => 'baseline', repository => 'https://github.com/madler/zlib.git', commit_or_branch => '50893291621658f355bc5b4d450a8d06a563053d' },
    { id => 'cloudflare', repository => 'https://github.com/cloudflare/zlib.git', commit_or_branch => '8fe233dbf33766ed73940baebdb901de8257c59c' },
    { id => 'intel', repository => 'https://github.com/jtkukunas/zlib.git', commit_or_branch => 'e176b3c23ace88d5ded5b8f8371bbab6d7b02ba8'},
);

# Compression levels to benchmark
my @compress_levels = qw(1 3 5 9);

# Number of iterations of each benchmark to run (in addition to a single
# warmup run).
my $runs = 5;
# Number of compressions / decompressions to do in each run
my $run_size = 10;

sub checkout {
    my ($id, $repository, $commit_or_branch) = @_;
    my $dir = "zlib.$id";

    return $dir;

    if (-d $dir) {
        if (system "cd $dir && git reset --hard $commit_or_branch") {
            die "'git checkout' of '$commit_or_branch' in $dir failed\n";
        }
    } else {
        if (system "git clone $repository $dir") {
            die "'git clone' of $id failed\n";
        }
        checkout(@_);
    }

    $dir;
}

sub compile {
    my ($dir) = @_;
    system "cd $dir && ./configure && make";
}

sub fetch_and_compile_all {
    for my $version (@versions) {
        $version->{dir} = checkout $version->{id}, $version->{repository}, $version->{commit_or_branch};
    }

    return;

    for my $version (@versions) {
        compile $version->{dir};
    }
}

sub benchmark_command {
    my ($command, $iters) = @_;

    my (@start_times) = times;

    my $size;
    for (1..$iters) {
        $size = length qx"$command";
    }

    my (@end_times) = times;

    { output_size => $size,
      time => sum(@end_times[2,3]) - sum(@start_times[2,3])}
}

sub benchmark_compress {
    my ($zlib_dir, $input, $level, $iters) = @_;

    benchmark_command "$zlib_dir/minigzip64 -$level < $input", $iters;
}

sub benchmark_decompress {
    my ($zlib_dir, $input, $iters) = @_;

    my $res = benchmark_command "$zlib_dir/minigzip64 < $input", $iters;
    delete $res->{size};

    return $res;
}

sub benchmark_all {
    my %results = ();

    # Compression benchmarks
    for my $version (@versions) {
        for my $level (@compress_levels) {
            for my $input (glob "corpus/[a-z]*") {
                $input =~ m{.*/(.*)} or next;
                my $id = "compress $1 -$level";

                # Warm up
                benchmark_compress $version->{dir}, $input, $level, 1;

                $results{$id}{input}{size} = (-s $input);

                for (1..$runs) {
                    my $result = benchmark_compress $version->{dir}, $input, $level, $run_size;
                    push @{$results{$id}{output}{"$version->{id}"}}, $result;
                }
            }
        }
    }

    # Decompression benchmarks. 

    # First create compressed files.
    my %compressed = ();
    for my $input (glob "corpus/[a-z]*") {
        my ($fh, $filename) = tempfile();
        $compressed{$input}{tmpfile} = $filename;
        print $fh qx"$versions[0]{dir}/minigzip64 < $input";
        close $fh;
    }

    for my $version (@versions) {
        for my $input (glob "corpus/[a-z]*") {
            $input =~ m{.*/(.*)} or next;
            my $id = "decompress $1";

            # Warm up
            benchmark_decompress $version->{dir}, $compressed{$input}{tmpfile}, 1;

            for (1..$runs) {
                my $result = benchmark_decompress $version->{dir}, $compressed{$input}{tmpfile}, $run_size;
                push @{$results{$id}{output}{"$version->{id}"}}, $result;
            }
        }
    }

    for my $input_results (values %results) {
        for my $version_results (values %{$input_results->{output}}) {
            my $processed = {};
            for my $field (qw(output_size time)) {
                my $stat = Statistics::Descriptive::Full->new();
                for my $result (@{$version_results}) {
                    $stat->add_data($result->{$field});
                }
                $processed->{$field} = {
                    mean => $stat->mean(),
                    error => $stat->standard_deviation() / sqrt($stat->count()),
                };
            }

            $version_results = $processed;
        }
    }

    return {
        versions => [ map { $_->{id} } @versions ],
        results => \%results
    }
}

sub pprint {
    my ($input) = @_;
    my @versions = @{$input->{versions}};
    my %results = %{$input->{results}};

    printf "%20s ", '';        
    for my $version (@versions) {
        printf "%-15s ", $version;        
    }

    for my $key (sort keys %results) {
        my %benchmark = %{$results{$key}};
        printf "\n%s", $key;

        if ($benchmark{input}{size}) {
            printf "\n%20s ", "Compression ratio:";
            for my $version (@versions) {
                my $output_size = $benchmark{output}{$version}{output_size}{mean};
                my $input_size = $benchmark{input}{size};
                printf("%5.2f %10s",
                       $output_size / $input_size,
                       '');
            }
        }

        printf "\n%20s ", "Execution time:";
        for my $version (@versions) {
            my $time = $benchmark{output}{$version}{time}{mean};
            my $basetime = $benchmark{output}{'baseline'}{time}{mean};
            printf("%5.2f (%6.2f%%) ",
                   $time,
                   $time / $basetime * 100, 
                   '');
        }
    }

    printf "\n";
}

fetch_and_compile_all;
my $results = benchmark_all;

if (1) {
    pprint $results;
} else {
    print encode_json $results;
}