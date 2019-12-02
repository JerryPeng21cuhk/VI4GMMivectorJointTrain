#!/bin/bash
# Copyright 2013   Daniel Povey
#           2014   David Snyder
#           2016   Lantian Li, Yixiang Chen, Zhiyuan Tang, Dong Wang
#           2018   Zhiyuan PENG
# Apache 2.0.
#
# This example script for i-vector LID is still a bit of a mess, and needs to be
# cleaned up, but it shows you all the basic ingredients.

# The default path of training set is 'data/train',
# the default path of test set is 'data/test'.
# and the default path of dev set is 'data/{dev_1s,dev_3s,dev_all}'.


. ./cmd.sh
. ./path.sh
. ./jvectorpath.sh

# Number of components
cnum=256 # num of Gaussions
civ=100   # dim of i-vector
clda=9    # dim for i-vector with LDA

testdir=dev_all  # you may change it to dev_1s, dev_3s or test
exp=exp/jvectorpost256
mkdir -p $exp

stage=2

set -e

# When doing i-vector LID, the two files ('spk2utt' and 'utt2spk') in data/{train,dev_1s,dev_3s,dev_all},
# should be replaced with those in local/olr/ivector/lan2utt, 
# after then, each 'spk' actually indicates one language of the ten.
# Those files in data/{train,dev_1s,dev_3s,dev_all}/lan2utt are outdated. 
#for subpath in {train,dev_1s,dev_3s,dev_all}/utt2spk; do
#  if ! cmp data/$subpath local/olr/ivector/lan2utt/$subpath &> /dev/null; then
#    echo "data/$subpath should be replaced with local/olr/ivector/lan2utt/$subpath and so is spk2utt" && exit 1;
#  fi
#done
. ./utils/parse_options.sh

if [ $stage -le 1 ];then
  # Feature extraction and VAD
  mfccdir=`pwd`/_mfcc
  vaddir=`pwd`/_vad
  
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 10 --cmd "$cpu_cmd" data/train $exp/_log_mfcc $mfccdir
  sid/compute_vad_decision.sh --nj 4 --cmd "$cpu_cmd" data/train $exp/_log_vad $vaddir
  
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 10 --cmd "$cpu_cmd" data/$testdir $exp/_log_mfcc $mfccdir
  sid/compute_vad_decision.sh --nj 4 --cmd "$cpu_cmd" data/$testdir $exp/_log_vad $vaddir
fi

if [ $stage -le 2 ];then
#  # Get smaller subsets of training data for faster training.
  utils/subset_data_dir.sh data/train 18000 data/train_18k
  utils/subset_data_dir.sh data/train 36000 data/train_36k

  # UBM and T-matrix training
  sid/train_diag_ubm.sh --nj 6 --cmd "$cpu_cmd" data/train_18k ${cnum} $exp/diag_ubm_${cnum} 
  sid/train_full_ubm.sh --nj 6 --cmd "$cpu_cmd" data/train_36k $exp/diag_ubm_${cnum} $exp/full_ubm_${cnum} 
fi

if [ $stage -le 3 ]; then
  # Train j-vector extractor
  # There are two approaches to initialize j-vector extractor:
  # 1. Initialize j-vector extractor with full-covar gmm and randomize T-matrix, this skips the train phase of ivector-extractor;
  # 2. Initialize j-vector extractor from both fgmm and i-vector;
  # As I have not implement the code of initialize from ivector-extractor, here we use the first approach.
 
  #sid/train_ivector_extractor.sh --nj 10  --cmd "$cpu_cmd -l mem_free=2G" \
  #  --num-iters 6 --ivector_dim $civ $exp/full_ubm_${cnum}/final.ubm data/train \
  #  $exp/extractor_${cnum}_${civ}

  #sid/train_jvector_extractor_updatepost.sh --nj 10 --cmd "$cpu_cmd -l mem_free=2G" \
  #   --num-iters 15 --jvector_dim $civ $exp/full_ubm_${cnum}/final.ubm data/train \
  #   $exp/extractor_${cnum}_${civ}

  
  # Extract j-vector
  #sid/extract_jvectors_updatepost.sh --cmd "$cpu_cmd -l mem_free=2G," --nj 10 \
  #  $exp/extractor_${cnum}_${civ} data/train $exp/jvectors_train_${cnum}_${civ}

  sid/extract_jvectors_testset.sh --cmd "$cpu_cmd -l mem_free=2G," --nj 10 \
    $exp/extractor_${cnum}_${civ} data/train $exp/jvectors_train_${cnum}_${civ}
	
  sid/extract_jvectors_testset.sh --cmd "$cpu_cmd -l mem_free=2G," --nj 10 \
    $exp/extractor_${cnum}_${civ} data/$testdir $exp/jvectors_${testdir}_${cnum}_${civ}
fi

# Demonstrate simple cosine-distance scoring
if [ $stage -le 4 ];then
  trials=local/olr/ivector/trials.trl
  mkdir -p $exp/score/total
  cat $trials | awk '{print $1, $2}' | \
   ivector-compute-dot-products - \
    scp:$exp/jvectors_train_${cnum}_${civ}/spk_jvector.scp \
    scp:$exp/jvectors_${testdir}_${cnum}_${civ}/jvector.scp \
    $exp/score/total/foo_cosine
  
  echo j-vector
  echo
  printf '% 16s' 'EER% is:'
  eer=$(awk '{print $3}' $exp/score/total/foo_cosine | paste - $trials | awk '{print $1, $4}' | compute-eer - 2>/dev/null)
  printf '% 5.2f' $eer
  echo
  
  python local/olr/ivector/Compute_Cavg.py  $exp/score/total/foo_cosine data/${testdir}/utt2spk
fi

if [ $stage -le 5 ];then

  echo ">> Computing wccn matrix"
  jvector-compute-wccn --total-covariance-factor=0.1 \
    "ark:ivector-normalize-length scp:${exp}/jvectors_train_${cnum}_${civ}/jvector.scp  ark:- |" \
    ark:data/train/utt2spk \
    $exp/jvectors_train_${cnum}_${civ}/wccn.mat

  echo ">> Whitening training jvector"
  ivector-transform $exp/jvectors_train_${cnum}_${civ}/wccn.mat \
    "ark:ivector-normalize-length scp:$exp/jvectors_train_${cnum}_${civ}/jvector.scp ark:- |" ark:- | \
    ivector-normalize-length ark:- ark:${exp}/jvectors_train_${cnum}_${civ}/wccn_jvector.ark

  echo ">> Whitening ${testdir} jvector"
  ivector-transform $exp/jvectors_train_${cnum}_${civ}/wccn.mat \
    "ark:ivector-normalize-length scp:$exp/jvectors_${testdir}_${cnum}_${civ}/jvector.scp ark:- |" ark:- | \
    ivector-normalize-length ark:- ark:${exp}/jvectors_${testdir}_${cnum}_${civ}/wccn_jvector.ark


fi

# Demonstrate cosine-distance scoring for i-vector with LDA
if [ $stage -le 6 ];then

  # Demonstrate cosine-scoring for i-vector with WCCN
  dir=${exp}/jvectors_train_${cnum}_${civ}

  ivector-mean ark:data/train/spk2utt \
    ark:$dir/wccn_jvector.ark ark:- ark,t:$dir/num_utts.ark | \
    ivector-normalize-length ark:- ark,scp:$dir/wccn_spk_jvector.ark,$dir/wccn_spk_jvector.scp

  trials=local/olr/ivector/trials.trl
  cat $trials | awk '{print $1, $2}' | \
    ivector-compute-dot-products - \
      scp:$exp/jvectors_train_${cnum}_${civ}/wccn_spk_jvector.scp \
      ark:$exp/jvectors_${testdir}_${cnum}_${civ}/wccn_jvector.ark \
      $exp/score/total/foo_wccn

  echo "j-vector with WCCN(whitening) "
  echo 
  printf '% 16s' 'EER% is:'
  eer=$(awk '{print $3}' $exp/score/total/foo_wccn | paste - $trials | awk '{print $1, $4}' | compute-eer - 2>/dev/null)
  printf '% 5.2f' $eer

  python local/olr/ivector/Compute_Cavg.py  $exp/score/total/foo_wccn data/${testdir}/utt2spk


fi
