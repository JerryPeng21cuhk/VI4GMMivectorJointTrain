
all:

EXTRA_CXXFLAGS = -Wno-sign-compare
include ../kaldi2.mk

#BINFILES = ivector-extractor-conv-init ivector-extractor-conv-acc-stats \
		   ivector-extractor-conv-sum-acc ivector-extractor-conv-est \
		   ivector-extract-conv \
		   copy-tmat-conv 

BINFILES = jvector-copy-plda jvector-compute-plda jvector-plda-scoring boostrap-utterances
#BINFILES = jvector-plda-scoring
#BINFILES = boostrap-utterances
#BINFILES = jvector-extractor-acc-stats
#BINFILES = jvector-extractor-sum-accs jvector-extractor-acc-stats \
jvector-extractor-est jvector-extractor-init jvector-extractor-test \
jvector-extract jvector-extractor-copy jvector-compute-wccn

OBJFILES =

TESTFILES =
#ADDLIBS = ../jvector/kaldi-jvector.a ../hmm/kaldi-hmm.a ../gmm/kaldi-gmm.a \
    ../tree/kaldi-tree.a ../matrix/kaldi-matrix.a \
    ../util/kaldi-util.a ../base/kaldi-base.a

ADDLIBS = ../jvector/kaldi-plda-simplified.a ../hmm/kaldi-hmm.a ../gmm/kaldi-gmm.a \
    ../tree/kaldi-tree.a ../matrix/kaldi-matrix.a \
    ../util/kaldi-util.a ../base/kaldi-base.a
#../vivector/kaldi-vivector.a

include ../makefiles/default_rules.mk
