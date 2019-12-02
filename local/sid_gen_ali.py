#!/usr/bin/env python

# Copyright 2017 Tsinghua University (Author: Zhiyuan Tang)
# 2018 jerrypeng for sid
# Apache 2.0

import sys, collections, os
import pdb

dir = sys.argv[1]
alidir = sys.argv[2]

if not os.path.isdir(alidir):
	os.makedirs(alidir)  # store the alignment of language id

len_dict = collections.OrderedDict()
with open(dir + '/feats.len', 'r') as utt_lens:
        for utt_len in [line.strip().split(' ') for line in utt_lens]:
                len_dict[utt_len[0]] = utt_len[1]

counts = []
for n in range(0, 641):  # 641 speakers
	counts.append(0)

#lang_dict = {'ct-cn':'0', 'id-id':'1', 'ja-jp':'2', 'ko-kr':'3', 'ru-ru':'4', 'vi-vn':'5', 'zh-cn':'6', 'Kazak':'7', 'Tibet':'8', 'Uyghu':'9'} # each language with an ID
spk_dict = {}
with open(dir + '/spk2utt', 'r') as spk2utt:
	for idx, line in enumerate(spk2utt):
		spk_dict[line.strip().split(' ')[0]] = idx
		
utt2spk = {}
with open(dir + '/utt2spk', 'r') as utt2spkf:
	for line in utt2spkf:
		utt, spk = line.strip().split(' ')
		utt2spk[utt] = spk

spk_ali = open(alidir+'/ali.ark', 'w')
for i in len_dict.keys():
        uttid = i
	spkid = spk_dict[utt2spk[uttid]]
	#pdb.set_trace()
        num = int(len_dict[i])
	#pdb.set_trace()
	counts[spkid] += num
	uttid += (' ' + str(spkid)) * num
        spk_ali.write(uttid + '\n')
spk_ali.close()

spk_counts = open(alidir+'/frame_counts', 'w') # total frames for each language
spk_counts.write('[')
for j in counts:
        spk_counts.write(' ' + str(j))
spk_counts.write(' ]')
spk_counts.close()

lang_num = open(alidir+'/lang_num', 'w')
lang_num.write('10') # 10 languages
lang_num.close()

#print 'Language alignment stored in exp/olr_ali.'
