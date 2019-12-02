#!/bin/bash

# Copyright 2016 Pegah Ghahremani

# This script used to generate MFCC+pitch features for input language lang.

. ./path.sh
. ./cmd.sh
set -e
stage=1
train_stage=-10
generate_alignments=true # If true, it regenerates alignments.
speed_perturb=false
use_pitch=false      # If true, it generates pitch features and combine it with 40dim MFCC.
pitch_conf=conf/pitch.conf # Configuration used for pitch extraction.
feat_suffix=_hires  # feature suffix for training data
boost_sil=1.0
nj=30

[ -f local.conf ] && . ./local.conf

. ./utils/parse_options.sh

lang=$1

# perturbed data preparation
train_set=train

if [ $# -ne 1 ]; then
  echo "Usage:$0 [options] <language-id>"
  echo "e.g. $0 102-assamese"
  exit 1;
fi

if [ "$speed_perturb" == "true" ]; then
  if [ $stage -le 1 ]; then
    #Although the nnet will be trained by high resolution data, we still have to perturbe the normal data to get the alignment
    # _sp stands for speed-perturbed
    for datadir in train; do
      if [ ! -d data/$lang/${datadir}_sp ]; then
        ./utils/data/perturb_data_dir_speed_3way.sh data/$lang/${datadir} data/$lang/${datadir}_sp

        # Extract Plp+pitch feature for perturbed data.
        featdir=plp_perturbed/$lang
        if $use_pitch; then
          steps/make_plp_pitch.sh --cmd "$train_cmd" --nj $nj  data/$lang/${datadir}_sp exp/$lang/make_plp_pitch/${datadir}_sp $featdir
        else
          steps/make_plp.sh --cmd "$train_cmd" --nj $nj data/$lang/${datadir}_sp exp/$lang/make_plp/${datadir}_sp $featdir
        fi
        steps/compute_cmvn_stats.sh data/$lang/${datadir}_sp exp/$lang/make_plp/${datadir}_sp $featdir || exit 1;
        utils/fix_data_dir.sh data/$lang/${datadir}_sp
      fi
    done
  fi
# Here extracting plp feature is for regenerating alignments
  train_set=train_sp
  if [ $stage -le 2 ] && [ "$generate_alignments" == "true" ] && [ ! -f exp/$lang/tri3b_ali_sp/.done ]; then
    #obtain the alignment of the perturbed data
    steps/align_fmllr.sh \
      --nj $nj --cmd "$train_cmd" \
      --boost-silence $boost_sil \
      data/$lang/$train_set data/$lang/lang exp/$lang/tri3b exp/$lang/tri3b_ali_sp || exit 1
    touch exp/$lang/tri3b_ali_sp/.done
  fi
fi

# train_set=train
if [ "$speed_perturb" == "false" ] && [ "$generate_alignments" == "true" ] && [ ! -f exp/$lang/tri3b_ali/.done ]; then
    #regenerate alignnment
    steps/align_fmllr.sh \
      --nj $nj --cmd "$train_cmd" \
      --boost-silence $boost_sil \
      data/$lang/$train_set data/$lang/lang exp/$lang/tri3b exp/$lang/tri3b_ali || exit 1
    touch exp/$lang/tri3b_ali/.done
fi


hires_config="--mfcc-config conf/mfcc_hires.conf"
mfccdir=mfcc_hires/$lang
mfcc_affix=""
if $use_pitch; then
  hires_config="$hires_config --online-pitch-config $pitch_conf"
  mfccdir=mfcc_hires_pitch/$lang
  mfcc_affix=_pitch_online
fi

if [ $stage -le 3 ] && [ ! -f data/$lang/${train_set}${feat_suffix}/.done ]; then
  
  for dataset in $train_set ; do
    data_dir=data/$lang/${dataset}${feat_suffix}   #train{_sp}_hires
    log_dir=exp/$lang/make${feat_suffix}/$dataset

    # the data_dir with _hires is for extracting 40-dim MFCC
    utils/copy_data_dir.sh data/$lang/$dataset ${data_dir} || exit 1;

    # scale the waveforms, this is useful as we don't use CMVN
    utils/data/perturb_data_dir_volume.sh $data_dir || exit 1;

    steps/make_mfcc${mfcc_affix}.sh --nj $nj $hires_config \
      --cmd "$train_cmd" ${data_dir} $log_dir $mfccdir;

    steps/compute_cmvn_stats.sh ${data_dir} $log_dir $mfccdir;

    # Remove the small number of utterances that couldn't be extracted for some
    # reason (e.g. too short; no such file).
    utils/fix_data_dir.sh ${data_dir};
  done
  touch ${data_dir}/.done
fi
exit 0;
