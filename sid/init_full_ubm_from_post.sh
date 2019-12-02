#!/bin/bash
# Copyright 2015-2017   David Snyder
#           2015        Johns Hopkins University (Author: Daniel Garcia-Romero)
#           2015        Johns Hopkins University (Author: Daniel Povey)
#           2018        JerryPeng (delete dnn model)
# Apache 2.0

# This script derives a full-covariance UBM from posteriors and
# speaker recognition features.

# Begin configuration section.
nj=8
cmd="run.pl"
stage=-2
delta_window=3
delta_order=2
cleanup=true
chunk_size=256
stage=0
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
#update some revised bins of kaldi
if [ -f ~/tools/kaldi_bin_revised.sh ]; then . ~/tools/kaldi_bin_revised.sh; fi
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
  #TODO: revise description
  echo "Usage: steps/init_full_ubm_from_post.sh <data-dir> <post-dir> <new-ubm-dir>"
  echo "Initializes a full-covariance UBM from posterior and speaker recognition features."
  echo " e.g.: steps/init_full_ubm_from_post.sh data/train data/phnrec/post exp/full_ubm"
  echo "main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --nj <n|16>                                      # number of parallel training jobs"
  echo "  --delta-window <n|3>                             # delta window size"
  echo "  --delta-order <n|2>                              # delta order"
  echo "  --chunk-size <n|256>                             # Number of frames processed at a time by the DNN"
  echo "  --nnet-job-opt <option|''>                       # Options for the DNN jobs which add to or"
  echo "                                                   # replace those specified by --cmd"
  exit 1;
fi

data=$1     # Features for the GMM
post=$2
dir=$3


for f in $data/feats.scp $data/vad.scp $post/feats.scp; do
  [ ! -f $f ] && echo "No such file $f" && exit 1;
done

mkdir -p $dir/log
echo $nj > $dir/num_jobs
sdata=$data/split$nj;
utils/split_data.sh $data $nj || exit 1;

delta_opts="--delta-window=$delta_window --delta-order=$delta_order"
echo $delta_opts > $dir/delta_opts

logdir=$dir/log

spost=$post/split$nj
echo ">> Splitting post dir"
utils/split_data.sh $post $nj || exit 1;
#mkdir -p $spost
##copy-feats ark:$post/feats.ark ark,scp:$post/feats.ark,$/feats.scp
#for i in $(seq $nj); do
#  spost_scp[$i]=$spost/feats.${i}.scp
#done
#split_scp.pl $post/feats.scp  ${spost_scp[@]} || exit 1;

# feat setup is the same as feats setup in traditional ubm training except subsampling.
feats="ark,s,cs:add-deltas $delta_opts scp:$sdata/JOB/feats.scp ark:- | \
apply-cmvn-sliding --norm-vars=false --center=true --cmn-window=300 ark:- ark:- | \
select-voiced-frames ark:- scp,s,cs:$sdata/JOB/vad.scp ark:- |"

# Get the dim of $post.  This will also correspond to the number of components
# in the ancillary GMM.
num_components=`feat-to-dim --print-args=false scp:$post/feats.scp -`

if [ $stage -le 0 ]; then
  echo "$0: accumulating stats from posteriors and speaker ID features"
  $cmd JOB=1:$nj $dir/log/make_stats.JOB.log \
    select-voiced-frames scp:$spost/JOB/feats.scp scp,s,cs:$sdata/JOB/vad.scp ark:- \
    \| feat2post ark:- ark:- \
    \| fgmm-global-acc-stats-post ark:- $num_components \
    "$feats" $dir/stats.JOB.acc || exit 1;
fi

if [ $stage -le 1 ]; then
  echo "$0: initializing GMM from stats"
  $cmd $dir/log/init.log \
    fgmm-global-init-from-accs --verbose=2 \
    "fgmm-global-sum-accs - $dir/stats.*.acc |" $num_components \
    $dir/final.ubm || exit 1;
fi

if $cleanup; then
  echo "$0: removing stats"
  for g in $(seq $nj); do
    rm $dir/stats.$g.acc || exit 1
  done
fi
