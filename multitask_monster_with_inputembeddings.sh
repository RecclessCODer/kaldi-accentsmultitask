. ./cmd.sh
. ./path.sh


bnf_dim=1024
affix=

nj=40
train_stage=-10	#originally -10
srand=0
get_egs_stage=-10
decode_stage=-10
num_jobs_initial=2
num_jobs_final=8
proportional_shrink=10



#for egs
left_context=30
right_context=22

modelDirectories=/home/abhinav/kaldi/accents/exp

bnfNnetModelDir=/exp/abhinav/accent_recognizer_exp/nnet3/tdnn_relufirst_1024nodes_300bnlayer_nz
singletask=1
bnf_exp_dir=scratch


. utils/parse_options.sh
affix=a300_t024_10shrink_0.9_0.1_withsaloneembedinput_utt
dir=scratch/nnet3_combined_withembedding/multitask_$affix
# dir=exp/nnet3_combined/multitask_$affix






[ ! -f local_opt.conf ] && echo 'the file local.conf does not exist! Read README.txt for more details.' && exit 1;
. local_opt.conf || exit 1;

num_langs=${#lang_list[@]}


mfccForBaseData=0
mfccForSp=0
align=0
mfccHiresForBaseData=0
mfccHiresForSp=0
ivector=0
bnftrain=0
bnftrainx=0
append_bnf_train=0
append_bnf_trainx=0
config=0
egRecog=0
egAccents=0
combineEgs=0
train=0
priors=0
decode=1
wer=1

mfccdir=exp/mfcc
if [ $mfccForBaseData -eq 1 ]; then
  #do this for-
  #data={data/101-cla-min/cv_trainx_nz,data/101-recog-min/cv_train_nz}
	data=data/101-recog-min
	for x in cv_train_nz; do
		steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_16k.conf --cmd "$train_cmd" \
				$data/$x exp/make_mfcc/$x $mfccdir
		steps/compute_cmvn_stats.sh $data/$x exp/make_mfcc/$x $mfccdir
		utils/fix_data_dir.sh $data/$x
	done
fi

mfccdir=exp/mfcc_perturbed
if [ $mfccForSp -eq 1 ]; then
  #do this for-
  #data={data/101-cla-min/cv_trainx_nz,data/101-recog-min/cv_train_nz}
	data=data/102-cla-min
	for x in cv_trainx_nz; do
		#./utils/data/perturb_data_dir_speed_3way.sh $data/${x} $data/${x}_sp

		utils/perturb_data_dir_speed.sh 0.9 $data/${x} $data/temp1
		utils/perturb_data_dir_speed.sh 1.1 $data/${x} $data/temp2
		utils/copy_data_dir.sh --spk-prefix sp1.0- --utt-prefix sp1.0- $data/${x} $data/temp0
		utils/combine_data.sh $data/${x}_sp $data/temp0 $data/temp1 $data/temp2
		rm -r $data/temp0 $data/temp1 $data/temp2
		utils/validate_data_dir.sh --no-feats --no-text $data/${x}_sp


		steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_16k.conf --cmd "$train_cmd" \
				$data/${x}_sp exp/make_mfcc/${x} $mfccdir
		steps/compute_cmvn_stats.sh $data/${x}_sp exp/make_mfcc/$x $mfccdir
		utils/fix_data_dir.sh $data/${x}_sp
	done
fi

ali_dir0=exp/101-recog-min/tri4_cv_train_nz_ali
if [ $align -eq 1 ]; then

  steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" \
                   data/101-recog-min/cv_train_nz_sp data/101-recog-min/lang $modelDirectories/tri4 ${ali_dir0}
fi

mfccdir=exp/mfcc_hires
if [ $mfccHiresForBaseData -eq 1 ]; then
  #data={data/101-cla-min/cv_trainx_nz,data/101-recog-min/cv_train_nz}
	data=data/101-recog-min
	for x in cv_dev_nz cv_test_onlynz; do
		utils/copy_data_dir.sh $data/${x} $data/${x}_hires || exit 1;
		steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_16k_hires.conf --cmd "$train_cmd" \
				$data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
		steps/compute_cmvn_stats.sh $data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
		utils/fix_data_dir.sh $data/${x}_hires
	done
fi


if [ $mfccHiresForSp -eq 1 ]; then
  #data={data/101-cla-min/cv_trainx_nz,data/101-recog-min/cv_train_nz}
  #data/101-recog-min/cv_train_nz_sp
	data=data/101-recog-min
	for x in cv_train_nz_sp; do
		utils/copy_data_dir.sh $data/${x} $data/${x}_hires || exit 1;
		utils/data/perturb_data_dir_volume.sh $data/${x}_hires || exit 1;
		steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_16k_hires.conf --cmd "$train_cmd" \
				$data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
		steps/compute_cmvn_stats.sh $data/${x}_hires exp/make_mfcc/${x}_hires $mfccdir
		utils/fix_data_dir.sh $data/${x}_hires
	done


fi

online_ivector_dir0=exp/101-recog-min/nnet3/ivectors_cv_train_nz_sp
online_ivector_dir1=exp/102-cla-min/nnet3/ivectors_cv_trainx_nz_sp
if [ $ivector -eq 1 ]; then
	steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
		data/101-recog-min/cv_train_nz_sp $modelDirectories/nnet3/extractor $online_ivector_dir0 || exit 1;
	steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
		data/102-cla-min/cv_trainx_nz_sp $modelDirectories/nnet3/extractor $online_ivector_dir1 || exit 1;
fi
#relu-renorm-layer name=tdnn5 input=Append(-3,3) dim=1024
#relu-renorm-layer name=tdnn_bn dim=$bnf_dim




if [ $bnftrain -eq 1 ]; then

    steps/nnet3/make_bottleneck_features_from_singletask.sh \
    --nj $nj \
    --use-gpu true \
    --cmd "$train_cmd" \
        tdnn_bn.renorm data/101-recog-min/cv_train_nz_sp_hires data/101-recog-min/cv_train_nz_sp_bnf \
        $bnfNnetModelDir $bnf_exp_dir/101-recog-min/cv_train_nz_sp $bnf_exp_dir/make_bnf/101-recog-min
  
fi

if [ $bnftrainx -eq 1 ]; then

    steps/nnet3/make_bottleneck_features_from_singletask.sh \
    --nj $nj \
    --use-gpu true \
    --cmd "$train_cmd" \
        tdnn_bn.renorm data/102-cla-min/cv_trainx_nz_sp_hires data/102-cla-min/cv_trainx_nz_sp_bnf \
        $bnfNnetModelDir $bnf_exp_dir/102-cla-min/cv_trainx_nz_sp $bnf_exp_dir/make_bnf/102-cla-min

fi

appended_dir0=data_uttLevel/101-recog-min/cv_train_nz_mfcc_bnf_appended_sp
dump_bnf_dir0=$bnf_exp_dir/append_mfcc_bnf/101-recog-min
if [ $append_bnf_train -eq 1 ]; then

    steps/append_feats.sh \
        --cmd "$train_cmd" \
        --nj $nj \
      data/101-recog-min/cv_train_nz_sp_bnf data/101-recog-min/cv_train_nz_sp_hires $appended_dir0 \
      $bnf_exp_dir/append_hires_mfcc_bnf/101-recog-min/cv_train_nz_sp $dump_bnf_dir0 || exit 1;
    steps/compute_cmvn_stats.sh $appended_dir0 \
       $bnf_exp_dir/101-recog-min/make_cmvn_mfcc_bnf $dump_bnf_dir0 || exit 1;

fi

appended_dir1=data_uttLevel/102-cla-min/cv_trainx_nz_mfcc_bnf_appended_sp
dump_bnf_dir1=$bnf_exp_dir/append_mfcc_bnf/102-cla-min
if [ $append_bnf_trainx -eq 1 ]; then

    steps/append_feats.sh \
        --cmd "$train_cmd" \
        --nj $nj \
      data/102-cla-min/cv_trainx_nz_sp_bnf data/102-cla-min/cv_trainx_nz_sp_hires $appended_dir1 \
      $bnf_exp_dir/append_hires_mfcc_bnf/102-cla-min/cv_trainx_nz_sp $dump_bnf_dir1 || exit 1;
    steps/compute_cmvn_stats.sh $appended_dir1 \
        $bnf_exp_dir/102-cla-min/make_cmvn_mfcc_bnf $dump_bnf_dir1 || exit 1;

fi

if [ $config -eq 1 ]; then

  mkdir -p $dir/configs
  feat_dim=``
  num_targets0=`tree-info ${ali_dir0}/tree 2>/dev/null | grep num-pdfs | awk '{print $2}'` || exit 1;
  num_targets1=16
  feat_dim=`feat-to-dim scp:${appended_dir0}/feats.scp -`

  cat <<EOF > $dir/configs/network.xconfig
  input dim=100 name=ivector
  input dim=$feat_dim name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=shared1 input=Append(input@-2,input@-1,input,input@1,input@2, ReplaceIndex(ivector, t, 0)) dim=1024
  relu-renorm-layer name=shared2 dim=1024



  relu-renorm-layer name=acc1 input=Append(shared2@-1,shared2@2) dim=1024
  relu-renorm-layer name=acc2 input=Append(-3,3) dim=1024
  relu-renorm-layer name=acc3 input=Append(-3,3) dim=1024
  relu-renorm-layer name=acc4 input=Append(-7,2) dim=1024
  relu-renorm-layer name=acc_btn dim=300

  relu-renorm-layer name=prefinal-affine-1 input=acc_btn dim=1024
  output-layer name=output-1 dim=${num_targets1} max-change=1.5

  
  relu-renorm-layer name=tdnn1 input=Append(shared2@-1,shared2@2, acc_btn@-1, acc_btn@2) dim=1024
  relu-renorm-layer name=tdnn2 input=Append(-3,3) dim=1024
  relu-renorm-layer name=tdnn3 input=Append(-3,3) dim=1024
  relu-renorm-layer name=tdnn4 input=Append(-7,2) dim=1024
  relu-renorm-layer name=tdnn_bn dim=1024

  relu-renorm-layer name=prefinal-affine-0 input=tdnn_bn dim=1024
  output-layer name=output-0 dim=${num_targets0} max-change=1.5


  
#
EOF

  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig \
    --config-dir $dir/configs/ \
    --nnet-edits="rename-node old-name=output-0 new-name=output"
    

fi


if [ $egRecog -eq 1 ]; then
  cmd=run.pl


  context_opts="--left-context=$left_context --right-context=$right_context"

    transform_dir=${ali_dir0}
    cmvn_opts="--norm-means=false --norm-vars=false"
    extra_opts=()
    extra_opts+=(--cmvn-opts "$cmvn_opts")
    extra_opts+=(--online-ivector-dir ${online_ivector_dir0})
    extra_opts+=(--transform-dir $transform_dir)
    extra_opts+=(--left-context $left_context)
    extra_opts+=(--right-context $right_context)
    echo "$0: calling get_egs.sh for generating examples with alignments as output"


  steps/nnet3/get_egs.sh $egs_opts "${extra_opts[@]}" \
    --num-utts-subset 300 \
    --nj $nj \
      --samples-per-iter 400000 \
      --cmd "$cmd" \
      --generate-egs-scp true \
      --frames-per-eg 8 \
      $appended_dir0 ${ali_dir0} $dir/egs_aligns || exit 1;

fi

ali_dir1=exp/102-cla-min/ali
if [ $egAccents -eq 1 ]; then
	cmd=run.pl

  context_opts="--left-context=$left_context --right-context=$right_context"

    transform_dir=${ali_dir1}
    cmvn_opts="--norm-means=false --norm-vars=false"
    extra_opts=()
    extra_opts+=(--cmvn-opts "$cmvn_opts")
    extra_opts+=(--online-ivector-dir ${online_ivector_dir1})
    extra_opts+=(--transform-dir $transform_dir)
    extra_opts+=(--left-context $left_context)
    extra_opts+=(--right-context $right_context)
    echo "$0: calling get_egs.sh for generating examples with alignments as output"


  steps/nnet3/get_egs_mod.sh $egs_opts "${extra_opts[@]}" \
    --num-utts-subset 300 \
    --nj $nj \
    --num-pdfs 16 \
      --samples-per-iter 400000 \
      --cmd "$cmd" \
      --generate-egs-scp true \
      --frames-per-eg 8 \
      $appended_dir1 ${ali_dir1} $dir/egs_accents || exit 1;

fi


if [ $combineEgs -eq 1 ]; then
  if [ ! -z "$lang2weight" ]; then
      egs_opts="--lang2weight '$lang2weight'"
  fi
  common_egs_dir="scratch/nnet3_combined_withembedding/multitask_a300_t024_10shrink_0.9_0.1_withsaloneembedinput_utt/egs_aligns scratch/nnet3_combined_withembedding/multitask_a300_t024_10shrink_0.9_0.1_withsaloneembedinput_utt/egs_accents $dir/egs"
  steps/nnet3/multilingual/combine_egs.sh $egs_opts \
    --cmd "$decode_cmd" \
    --samples-per-iter 400000 \
    $num_langs ${common_egs_dir[@]} || exit 1;
fi


if [ $train -eq 1 ]; then
  steps/nnet3/train_raw_dnn.py --stage=$train_stage \
    --cmd="$decode_cmd" \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.num-epochs 2 \
    --trainer.optimization.num-jobs-initial=2 \
    --trainer.optimization.num-jobs-final=8 \
    --trainer.optimization.initial-effective-lrate=0.0015 \
    --trainer.optimization.final-effective-lrate=0.00015 \
    --trainer.optimization.minibatch-size=256,128 \
    --trainer.optimization.proportional-shrink=${proportional_shrink} \
    --trainer.samples-per-iter=400000 \
    --trainer.max-param-change=2.0 \
    --trainer.srand=$srand \
    --feat-dir $appended_dir0 \
    --feat.online-ivector-dir ${online_ivector_dir0} \
    --egs.dir $dir/egs \
    --use-dense-targets false \
    --targets-scp ${ali_dir0} \
    --cleanup.remove-egs false \
    --cleanup.preserve-model-interval 50 \
    --use-gpu true \
    --dir=$dir  || exit 1;
fi


if [ $priors -eq 1 ]; then
	lang_dir=$dir/101-recog-min
    mkdir -p  $lang_dir
    nnet3-copy --edits="rename-node old-name=output-0 new-name=output" \
      $dir/final.raw - | \
      nnet3-am-init exp/101-recog-min/tri4_cv_train_nz_ali/final.mdl - \
      $lang_dir/final.mdl || exit 1;

    cp $dir/cmvn_opts $lang_dir/cmvn_opts || exit 1;
    echo "$0: compute average posterior and readjust priors for language $101-recognition."
    steps/nnet3/adjust_priors.sh --cmd "$decode_cmd" \
      --use-gpu true \
      --iter final --use-raw-nnet false --use-gpu true \
      $lang_dir scratch/nnet3_combined_withembedding/multitask_a300_t024_10shrink_0.9_0.1_withsaloneembedinput_utt/egs_aligns || exit 1;

fi

if [ $decode -eq 1 ]; then
	
	dnn_beam=15.0
	dnn_lat_beam=8.0
	decode_stage=-2
  # decode_sets="cv_dev_nz cv_test_onlynz cv_test_onlyindian cv_test_newonlyindian"
  decode_sets="cv_finaltest_nz"
	score_opts="--skip-scoring false"

	ivectorsForDecode=0
  bnfForDecode=0
  appendForDecode=1

	for x in ${decode_sets}; do

		decode=$dir/101-recog-min/decode_${x}
		ivec_dir=exp/101-recog-min/nnet3/ivectors_${x}

		if [ $ivectorsForDecode -eq 1 ]; then			
			steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj \
				data/101-recog-min/$x $modelDirectories/nnet3/extractor ${ivec_dir} || exit 1;
		fi

    if [ $bnfForDecode -eq 1 ]; then
      steps/nnet3/make_bottleneck_features_from_singletask.sh \
    --nj $nj \
    --use-gpu true \
    --cmd "$train_cmd" \
        tdnn_bn.renorm data/101-recog-min/${x}_hires data/101-recog-min/${x}_bnf \
        $bnfNnetModelDir $bnf_exp_dir/101-recog-min/${x} $bnf_exp_dir/make_bnf/101-recog-min

    fi

    appended_dir=data/101-recog-min/${x}_mfcc_bnf_appended
    dump_bnf_dir=$bnf_exp_dir/append_mfcc_bnf/101-recog-min
    if [ $appendForDecode -eq 1 ]; then
      
       steps/append_feats.sh \
        --cmd "$train_cmd" \
        --nj $nj \
      data/101-recog-min/${x}_bnf data/101-recog-min/${x}_hires $appended_dir \
      $bnf_exp_dir/append_hires_mfcc_bnf/101-recog-min/$x $dump_bnf_dir || exit 1;
    steps/compute_cmvn_stats.sh $appended_dir \
        $bnf_exp_dir/101-recog-min/make_cmvn_mfcc_bnf $dump_bnf_dir || exit 1;


    fi

		ivector_opts="--online-ivector-dir ${ivec_dir}"
		# appended_dir=data/101-recog-min/${x}_hires
		mkdir -p $decode
		steps/nnet3/decode.sh --nj $nj --cmd "$decode_cmd" --iter final_adj \
		      --stage $decode_stage \
		      --beam $dnn_beam --lattice-beam $dnn_lat_beam \
		      $score_opts $ivector_opts \
		      $modelDirectories/tri4/graph_sw1_tg $appended_dir $decode | tee $decode/decode.log
	done
fi


if [ $wer -eq 1 ]; then
  #for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done 
  for x in $dir/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
  #for x in exp/*/*/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
fi
