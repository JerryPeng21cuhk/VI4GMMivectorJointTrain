import pdb
import sys
import os, os.path
import signal
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

foo_cosine = sys.argv[1]

lang_dict = {'ct-cn':'lang0', 'id-id':'lang1', 'ja-jp':'lang2', 'ko-kr':'lang3', 'ru-ru':'lang4', 'vi-vn':'lang5', 'zh-cn':'lang6', 'Kazak':'lang7', 'Tibet':'lang8', 'Uyghu':'lang9'}

#ref_dict = {'ct':'lang0', 'id':'lang1', 'ja':'lang2', 'Kazak':'lang7', 'ko':'lang3', 'ru':'lang4', 'Tibet':'lang8', 'Uyghu':'lang9', 'vi':'lang5', 'zh':'lang6'}
ref_dict = {'ct':0, 'id':1, 'ja':2, 'Kazak':7, 'ko':3, 'ru':4, 'Tibet':8, 'Uyghu':9, 'vi':5, 'zh':6}

fo = sys.argv[2]
if fo == '-':
    fo = sys.stdout
else:
    fo = open(fo, 'w')
fo.write('      lang0    lang1    lang2    lang3    lang4    lang5    lang6    lang7    lang8    lang9 \n')

with open(foo_cosine, 'r') as fi:
    cnt = 0
    for col in [line.strip().split() for line in fi]:
	ref_id = ref_dict[col[0]]
	line_id = col[1]
	lang_id = lang_dict[line_id[0:5]]
	score = col[2]
	if 0 == cnt:
	    # update
            lang_cur = lang_id
    	    scores = [None] * 10
	    scores[ref_id] = score
	else:
	    assert lang_cur == lang_id, "lang_cur lang land_id mismatched: {0}".format(line)
            scores[ref_id] = score
	if 9 == cnt:
	    # checking variables is neglected
	    # write to file
	    fo.write(lang_cur + ' ' + ' '.join(scores) + '\n')
	    # reset cnt
            cnt = 0
	else:
	    cnt = cnt + 1
	    
	
