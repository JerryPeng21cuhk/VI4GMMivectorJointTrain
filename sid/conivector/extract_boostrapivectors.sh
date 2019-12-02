#!/bin/bash

# Copyright     2013  Daniel Povey
#               2014  David Snyder
# Apache 2.0.

# This script extracts iVectors for a set of utterances, given
# features and a trained iVector extractor.

# Begin configuration section.
nj=30
num_threads=4 # Number of threads used by ivector-extract.  It is usually not
              # helpful to set this to > 1.  It is only useful if you have
              # fewer speakers than the number of jobs you want to run.

cmd="run.pl"
stage=0
num_gselect=20 # Gaussian-selection using diagonal model: number of Gaussians to select
min_post=0.025 # Minimum posterior to use (posteriors below this are pruned out)
posterior_scale=1.0 # This scale helps to control for successve features being highly
                    # correlated.  E.g. try 0.1 or 0.3.
apply_cmn=true # If true, apply sliding window cepstral mean normalization
force_boostrap=false # if true, force to boostrap sub-utterances even if the utterance is too short.
unit_length=10
num_subutt=10
subutt_length=10
min_frames=20

# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f conivectorpath.sh ]; then . ./conivectorpath.sh; fi

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;


if [ $# != 3 ]; then
  echo "Usage: $0 <extractor-dir> <data> <boostrapped-ivector-dir>"
  echo " e.g.: $0 exp/extractor_2048_male data/train_male exp/bst-ivectors_male"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --nj <n|10>                                      # Number of jobs (also see num-threads)"
  echo "  --num-threads <n|1>                              # Number of threads for each job"
  echo "  --stage <stage|0>                                # To control partial reruns"
  echo "  --num-gselect <n|20>                             # Number of Gaussians to select using"
  echo "                                                   # diagonal model."
  echo "  --min-post <min-post|0.025>                      # Pruning threshold for posteriors"
  echo " --apply-cmn <true,false|true>                     # if true, apply sliding window cepstral mean"
  echo "                                                   # normalization to features"
  echo "  --force-boostrap <false|true>                    # if true, force to boostrap sub-utterances "
  echo "                                                   # even if the utterance is too short."
  exit 1;
fi

srcdir=$1
data=$2
dir=$3

for f in $srcdir/final.ie $srcdir/final.ubm $data/feats.scp $data/spk2utt ; do
  [ ! -f $f ] && echo "No such file $f" && exit 1;
done

# Set various variables.
mkdir -p $dir/log
sdata=$data/split$nj;
utils/split_data.sh $data $nj || exit 1;

delta_opts=`cat $srcdir/delta_opts 2>/dev/null`


bstextract_opts="--unit_length=$unit_length --num_subutt=$num_subutt --subutt_length=$subutt_length --min_frames=$min_frames --force_boostrap=$force_boostrap"

## Set up features.
if $apply_cmn; then
  feats="ark,s,cs:add-deltas $delta_opts scp:$sdata/JOB/feats.scp ark:- | apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 ark:- ark:- | select-voiced-frames ark:- scp,s,cs:$sdata/JOB/vad.scp ark:- | boostrap-utterances $bstextract_opts ark:- ark:- ark:/dev/null |"
else
  feats="ark,s,cs:add-deltas $delta_opts scp:$sdata/JOB/feats.scp ark:- | select-voiced-frames ark:- scp,s,cs:$sdata/JOB/vad.scp ark:- | boostrap-utterances $bstextract_opts ark:- ark:- ark:/dev/null |"
fi

if [ $stage -le 0 ]; then
  echo "$0: extracting iVectors"
  dubm="fgmm-global-to-gmm $srcdir/final.ubm -|"

  $cmd --num-threads $num_threads JOB=1:$nj $dir/log/extract_ivectors.JOB.log \
    gmm-gselect --n=$num_gselect "$dubm" "$feats" ark:- \| \
    fgmm-global-gselect-to-post --min-post=$min_post $srcdir/final.ubm "$feats" \
      ark,s,cs:- ark:- \| scale-post ark:- $posterior_scale ark:- \| \
    ivector-extract-conv --verbose=2 --num-threads=$num_threads $srcdir/final.ie "$feats" \
      ark,s,cs:- ark,scp,t:$dir/ivector.JOB.ark,$dir/ivector.JOB.scp || exit 1;
fi

if [ $stage -le 1 ]; then
  echo "$0: combining iVectors across jobs"
  for j in $(seq $nj); do cat $dir/ivector.$j.scp; done >$dir/ivector.scp || exit 1;
fi

if [ $stage -le 2 ]; then

  echo "$0: creating utt2subutt"
  $cmd --num-threads $num_threads JOB=1:$nj $dir/log/create_utt2subutt.JOB.log \
    select-voiced-frames scp:$sdata/JOB/feats.scp scp,s,cs:$sdata/JOB/vad.scp ark:- \| \
     boostrap-utterances $bstextract_opts ark:- ark:/dev/null ark,t:$sdata/JOB/utt2subutt || exit 1;
  echo "$0: combining utt2subutt across jobs"
  for j in $(seq $nj); do cat $sdata/$j/utt2subutt; done >$dir/utt2subutt || exit 1;

fi


if [ $stage -le 3 ]; then

script=$(cat <<'EOF'
if (@ARGV != 2) {
  # print join(" ", @ARGV), ".\n"
  print "usage: script spk2utt utt2subutt; output spk2subutt.\n"
}
$spk2utt = $ARGV[0];
$utt2subutt = $ARGV[1];

sub trim($)
{
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}


# create a hash u2subu that maps from utt to subutt
%u2subu = ();
if (open(my $fh_utt2subutt, "<", $utt2subutt)) {
  while (my $line = <$fh_utt2subutt>) {
    chomp $line;
    $line = trim($line);
    my @A = split(" ", $line, 2);
    @A > 1 || die "Invalid line in spk2utt file: $line";
    ($u,$subu) = @A;
    $u2subu{$u} = $subu;
  }
} else {
  die "Could not open file '$utt2subutt' $!";
}

# read in spk2utt, print spk2subutt line by line
if (open(my $fh_spk2utt, "<", $spk2utt)) {
  while (my $line = <$fh_spk2utt>) {
    chomp $line;
    my @A = split(" ", $line);
    @A > 1 || die "Invalid line in spk2utt file: $line";
    $s = shift @A;
    my @subutts = ();
    foreach my $i (@A) {
      push(@subutts, $u2subu{$i});
    }
    print "$s ", join(" ", @subutts), "\n";
  }
}
EOF
)
perl -e "$script"  $data/spk2utt $dir/utt2subutt > $dir/spk2subutt;
utils/spk2utt_to_utt2spk.pl < $dir/spk2subutt > $dir/subutt2spk;
utils/spk2utt_to_utt2spk.pl < $dir/utt2subutt > $dir/subutt2utt;

fi


# if [ $stage -le 2 ]; then
#   # Be careful here: the speaker-level iVectors are now length-normalized,
#   # even if they are otherwise the same as the utterance-level ones.
#   echo "$0: computing mean of iVectors for each speaker and length-normalizing"
#   $cmd $dir/log/speaker_mean.log \
#     ivector-normalize-length scp:$dir/ivector.scp  ark:- \| \
#     ivector-mean ark:$data/spk2utt ark:- ark:- ark,t:$dir/num_utts.ark \| \
#     ivector-normalize-length ark:- ark,scp:$dir/spk_ivector.ark,$dir/spk_ivector.scp || exit 1;
# fi
