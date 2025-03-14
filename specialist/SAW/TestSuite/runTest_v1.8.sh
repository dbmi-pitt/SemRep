#!/bin/sh

# Usage: runTest_v1.8.sh
# Be sure to set SEMREP_TEST 

#announce() {
#   echo $1
#}

split_line(){
   LINE=$1
   FILENAME=`echo $LINE | cut -d'|' -f1`
   EXT=`echo $LINE | cut -d'|' -f2`
   FLAGS=`echo $LINE | cut -d'|' -f4`
   TITLE=`echo $LINE | cut -d'|' -f3`

}

test_filename_exists() {
   if [ ! -f $1 ]
   then
      echo ERROR: filename $1 does not exist.
      exit 1
   fi
}

#change_metamap_text() {
#
#   MODIFY=$1
#   METAMAP=$2
#   ORIG_FILENAME=$3
#   NEW_FILENAME=$4

#   if [ $MODIFY -eq 1 ]
#   then
#      echo "changing |$METAMAP|to|MetaMap|"

#      sed -e "s#$METAMAP#MetaMap#g" $ORIG_FILENAME > $NEW_FILENAME
#      /bin/rm -f $ORIG_FILENAME
#   else
#      /bin/mv -f $ORIG_FILENAME $NEW_FILENAME
#   fi
#}

diff_gold_test_files(){
   GOLD_FILENAME=$1
   TEST_FILENAME=$2
   DIFF_FILENAME=$3

   if [ ! -f $GOLD_FILENAME ]
   then
      echo "gold result file $GOLD_FILENAME does not exist"
      exit 1
   elif [ ! -f $TEST_FILENAME ]
   then
      echo "test result file $TEST_FILENAME does not exist"
      exit 1
   else
      diff -w $GOLD_FILENAME $TEST_FILENAME > $DIFF_FILENAME
      if [ -s $DIFF_FILENAME ]
      then
         cat $DIFF_FILENAME
      else
         echo DIFFS OK
         rm $DIFF_FILENAME
      fi
   fi
}

run_test() {
#   PRODorDEVL=$1
   PROGRAM=$1
   EXT=$2
   FLAGS=$3
   FILENAME=$4
#  MODIFY=$5

   INFILE=$FILENAME
   OUTFILE=$FILENAME.$EXT.TEST.OUT

   echo $PROGRAM $FLAGS $INFILE $OUTFILE
   $PROGRAM $FLAGS $INFILE $OUTFILE 
   
   if [ ! -s $OUTFILE ]
   then
      echo ERROR: $OUTFILE is zero length.
      exit 1
   fi

#   change_metamap_text $MODIFY "$PROGRAM" $TMP_OUTFILE $OUTFILE
}

PROGRAM=`basename $0`
USAGE='Usage: $PROGRAM'
LOGFILE=runTest.log
/bin/rm -f $LOGFILE

#while getopts TP option
#do
#   case $option
#   in
#   	P) RUN_PROD=1;;
#   	T) RUN_TEST=1;;
#        *) exit 1;
#   esac
#done

shift `expr $OPTIND - 1`
OPTIND=1

# The various tests are defined in lines such as the following:
# test.in|genetics_processing|Genetics processing|-G
#
#         FILENAME | EXTENSION | TITLE | FLAGS
#
# FILENAME:    The name of the file containing the text to be tested
# EXTENSION:   Extension of the gold output
# TITLE:       The name of the test (human readable)
# FLAGS:       The flags passed to SemRep to run this test.

# Set SEMREP_TEST here!!
# SEMREP_TEST is the version to be tested
# SEMREP_TEST="@@basedir@@/bin/semrep.v1.6"
SEMREP_TEST="SAWenv ../src/a.out.Linux"

echo "Start Time: `date`"
echo ""
echo "Semrep TEST: $SEMREP_TEST"
echo ""
echo "Writing system output to log file $LOGFILE"

while read LINE
do
   echo Testing $LINE

   split_line "$LINE"

   test_filename_exists $FILENAME

   echo running run_test "$SEMREP_TEST" "$FLAGS" $FILENAME
   run_test "$SEMREP_TEST" "$EXT" "$FLAGS" $FILENAME >> $LOGFILE 2>&1

   echo "====================== DIFFS for $FILENAME with $TITLE  ============================="
   diff_gold_test_files $FILENAME.$EXT $FILENAME.$EXT.TEST.OUT $FILENAME.$EXT.diff
   echo "====================== DIFFS END =========================================="
   echo ""
done << EOF
test.ml|SDFy|Full-fielded output format|-SDFy --negex_st_set ALL 
test.ml|SDXy|XML output format|-SDXy --negex_st_set ALL 
test.ml|SDy|Generic processing|-SDy --negex_st_set ALL 
test.ml|SD18y|Data/lexicon year 2018|-L 2018 -Z 2018AA -SDy --negex_st_set ALL 
test.ml|SDRy|Write syntax|-SDRy --negex_st_set ALL 
test.ml|SDAy|Anaphora resolution|-SDAy --negex_st_set ALL 
test.ml|SDMy|Relaxed model|-SDMy --negex_st_set ALL 
test.ml|SDny|Generic domain modification|-SDny --negex_st_set ALL 
test.ml|SDNy|Generic domain extension|-SDNy --negex_st_set ALL 
test.plain|SDy|Plain text generic processing|-SDy --negex_st_set ALL 
EOF

