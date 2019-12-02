
all:

OPENFST_CXXFLAGS = 
OPENFST_LDLIBS = 
#EXTRA_CXXFLAGS = -I../

include ../kaldi2.mk

TESTFILES = 

OBJFILES = jvector-extractor.o 
#OBJFILES = plda.o 
#OBJFILES = vivector-extractor-test.o
#OBJFILES = posterior-test.o


#LIBNAME = kaldi-plda-simplified
LIBNAME = kaldi-jvector

ADDLIBS = ../gmm/kaldi-gmm.a ../tree/kaldi-tree.a ../transform/kaldi-transform.a \
		../matrix/kaldi-matrix.a ../base/kaldi-base.a \
        ../util/kaldi-util.a ../hmm/kaldi-hmm.a

include ../makefiles/default_rules.mk
