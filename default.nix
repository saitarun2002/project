{ pkgs
, bdd100k
, bdd100k-mini
, hasktorch-datasets-utils
, src2drv
}:
let
  lib = pkgs.lib;
  resnet50 = builtins.fetchurl {
    url = "https://download.pytorch.org/models/resnet50-0676ba61.pth";
    sha256 = "12pv4bkq7rn9yy9njjrq9mi9gqp5hac8bzfgfcbvwnvrnrhvlxh6";
  };
  
  patched-pycocotools = pkgs.python310Packages.pycocotools.overrideAttrs (old: rec{
    patches = [../patches/pycocotools.patch];
  });

  mypy11 = pkgs.python311.withPackages(ps11: with ps11; 
 [
  PyGithub
 ]);


  myPython = pkgs.python310.withPackages (ps: with ps;
    [ opencv4
      pillow
      pytorch-bin
      torchvision-bin
      patched-pycocotools
      numpy
      pandas
      jupyterlab
      transformers
      jupyterlab-widgets
      tqdm
      ipywidgets
      librosa
      polars
      #matplotlib
      graphviz
      PyGithub
      bokeh
      pymc
      py-tree-sitter
      wget
      pycflow2dot
      gitpython
      networkx
      flask
      wtforms
      pyarrow
    #  aesara
    ]
  );
  mkDerivation = { pname
                 , description
                 , script
                 , scriptArgs
                 , pretrained ? ""
                 , numGpu
                 , datasets
                 , checkpoint_filename ? "checkpoint.pth"
                 } :
                   let pretrained_str =
                         if pretrained == ""
                         then ""
                         else " --resume ${pretrained.out}/output/${checkpoint_filename}";
                   in  pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1";
    nativeBuildInputs = [
      myPython
      pkgs.curl
      datasets
      pkgs.tree-sitter
    # mypy11
   #  pkgs.python310Packages.pygithub
      pkgs.clang
    ];
    buildInputs =  [];
    src = hasktorch-datasets-utils.excludeFiles 
      [ "^test\.py$"
        "^inference\.py$"
      ]
      ../src;
    buildPhase = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR

      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      mkdir -p ../torch/hub/checkpoints
      ln -s ${resnet50} ../torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l ../torch/hub/checkpoints
      mkdir output
      ln -s ${datasets.out} bdd100k
      python -m torch.distributed.launch --nproc_per_node=${toString numGpu} --use_env \
        ${script} \
        ${pretrained_str} \
        ${expandStriptArgs scriptArgs}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ${scriptArgs.output-dir} $out
    '';
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  testDerivation = { pname
         , description
         , script
         , scriptArgs
         , pretrained
         , datasets
         , checkpoint_filename ? "model.pth"
         } :
           let pretrained_str = " --resume ${pretrained.out}/output/${checkpoint_filename}";
           in  pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1";
    nativeBuildInputs = [
      myPython
      pkgs.curl
      pretrained
      datasets
    ];
    buildInputs =  [];
    src = hasktorch-datasets-utils.excludeFiles 
      [ "^train\.py$"
        "^inference\.py$"
      ]
      ../src;
    buildPhase = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR

      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      pwd
      mkdir -p ../torch/hub/checkpoints
      ln -s ${resnet50} ../torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l ../torch/hub/checkpoints
      mkdir output
      ln -s ${datasets.out} bdd100k
      python ${script} \
        ${pretrained_str} \
        --output-dir "${scriptArgs.output-dir}" \
        2>&1 | tee test.log
      python log2json.py test.log
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ${scriptArgs.output-dir} $out
      cp test.log $out/
      cp map_results.json $out/
    '';
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  expandStriptArgs = scriptArgs:
    let names = builtins.attrNames scriptArgs;
        args = builtins.map (n:
          "--" + n + " " +
          "\"" +
          builtins.toString (scriptArgs."${n}") +
          "\""
        ) names;
    in builtins.concatStringsSep " " args;
  clsDerivation = { pname
         , description
         , script
         , scriptArgs
         , pretrained
         , datasets
         , dataset-dir
         , checkpoint_filename ? "model.pth"
         } :
           let pretrained_str = " --resume ${pretrained.out}/output/${checkpoint_filename}";
           in  pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1";
    nativeBuildInputs = [
      myPython
      pkgs.curl
      pretrained
      datasets
    ];
    buildInputs =  [];
    src = hasktorch-datasets-utils.excludeFiles 
      [ "^train\.py$"
        "^test\.py$"
      ]
      ../src;
    buildPhase = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR

      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      pwd
      mkdir -p ../torch/hub/checkpoints
      ln -s ${resnet50} ../torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l ../torch/hub/checkpoints
      mkdir -p output/{trains,valids}/images
      mkdir -p output/weights
      cp ${datasets.out}/bdd100k.names output/
      ln -s ${datasets.out} ${dataset-dir}
      python ${script} \
        ${pretrained_str} \
        ${expandStriptArgs scriptArgs}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ${scriptArgs.output-dir} $out
    '';
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  runDerivation = { pname
         , description
         , script
         , scriptArgs
         , pretrained
         , checkpoint_filename ? "model.pth"
         } :
           let pretrained_str = " --resume ${pretrained.out}/output/${checkpoint_filename}";
           in  pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1";
    nativeBuildInputs = [
      myPython
      pkgs.curl
      pretrained
    ];
    buildInputs =  [];
    src = hasktorch-datasets-utils.excludeFiles 
      [ "^train\.py$"
        "^test\.py$"
      ]
      ../src;
    buildPhase = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR

      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      pwd
      mkdir -p ../torch/hub/checkpoints
      ln -s ${resnet50} ../torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l ../torch/hub/checkpoints
      python ${script} \
        ${pretrained_str} \
        ${expandStriptArgs scriptArgs}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ${scriptArgs.output-dir} $out
    '';
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  checkpoint = pkgs.stdenv.mkDerivation {
    pname = "checkpoint";
    version = "1";
    src = builtins.fetchurl {
        "sha256"= "0jiir49zhc3m9w2d5d3wyzpl6lrrv294jqy4jllq322875avjx38";
        "url"= "file:///home/hashimoto/git/torchvision-fastercnn-train/01/output/checkpoint.pth";
    };
    unpackCmd = ''
      mkdir -p $out/output
      cp "$curSrc" $out/output/"$'' + ''{curSrc#*-}"
      sourceRoot=`pwd`
    '';
    dontFixup = true;
    dontInstall = true;
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  pretrainedModel = pkgs.stdenv.mkDerivation {
    pname = "pretrained-fasterrcnn";
    version = "1";
    src = builtins.fetchurl {
        "sha256"= "1xhx9xiw5gnlnnz6kgjrarwvp5b1qvpni0sx8m99v5g1vjnibfn3";
        "url"= "https://github.com/hasktorch/hasktorch-datasets/releases/download/bdd100k/torchvision_fasterrcnn_model_e83ca1b.pth";
    };
    unpackCmd = ''
      mkdir -p $out/output
      cp "$curSrc" $out/output/model.pth
      sourceRoot=`pwd`
    '';
    dontFixup = true;
    dontInstall = true;
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
  iota = n: start:
    if n == 0
    then []
    else [start] ++ iota (n - 1) (start+1);
  detectDerivation = { pname
         , description
         , script
         , scriptArgs
         , pretrained
         , datasets
         , checkpoint_filename ? "model.pth"
         } :
           let pretrained_str = " --resume ${pretrained.out}/output/${checkpoint_filename}";
           in  pkgs.stdenv.mkDerivation {
    pname = pname;
    version = "1";
    nativeBuildInputs = [
      myPython
      pkgs.curl
      pretrained
      datasets
    ];
    buildInputs =  [];
    src = hasktorch-datasets-utils.excludeFiles 
      [ "^train\.py$"
        "^test\.py$"
      ]
      ../src;
    buildPhase = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR

      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      pwd
      mkdir -p ../torch/hub/checkpoints
      ln -s ${resnet50} ../torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l ../torch/hub/checkpoints
      mkdir -p output/{images,labels}/{trains,valids}
      ln -s ${datasets.out} bdd100k
      python ${script} \
        ${pretrained_str} \
        ${expandStriptArgs scriptArgs}
    '';
    installPhase = ''
      mkdir -p $out
      cp -r ${scriptArgs.output-dir} $out
    '';
    meta = with lib; {
      inherit description;
      longDescription = ''
      '';
      homepage = "";
      license = licenses.bsd3;
      platforms = platforms.all;
      maintainers = with maintainers; [ junjihashimoto ];
    };
  };
in
rec {
  pretrained-model = pretrainedModel;
  train = args@{...} : mkDerivation (rec {
    pname = "torchvision-fasterrcnn-trained";
    description = "Trained fasterrcnn";
    # pretrained = checkpoint;
    numGpu = 3;
    datasets = bdd100k;
    script = "train.py";
    scriptArgs = rec {
      output-dir = "output";
      epochs = 26;
      world-size = numGpu;
      batch-size = 12;
      # https://arxiv.org/abs/1711.00489
      lr = 0.02 * (batch-size / 2.0);
      # momentum = 0.9 * (1.0-(1.0/(batch-size / 2.0)));
    };
  } // args);
  finetuning = args@{...} : mkDerivation (rec {
    pname = "torchvision-fasterrcnn-finetuning";
    description = "Finetuning fasterrcnn";
    pretrained = pretrainedModel;
    checkpoint_filename = "model.pth";
    numGpu = 1;
    datasets = bdd100k-mini;
    # datasets = src2drv { srcs = [
    #   /home/hashimoto/git/cpod/git/cpod/dataset-to-fix-missclassification-of-truck
    # ]; };
    script = "train.py";
    scriptArgs = rec {
      output-dir = "output";
      epochs = 28;
      world-size = numGpu;
      batch-size = 12;
      # https://arxiv.org/abs/1711.00489
      lr = 0.02 * (batch-size / 2.0);
      # momentum = 0.9 * (1.0-(1.0/(batch-size / 2.0)));
    };
  } // args);
  trainN =
    let numGpu = 3;
        scriptArgs' = epoch: rec {
          output-dir = "output";
          epochs = epoch;
          world-size = numGpu;
          batch-size = 12;
          # https://arxiv.org/abs/1711.00489
          lr = 0.02 * (batch-size / 2.0);
          # momentum = 0.9 * (1.0-(1.0/(batch-size / 2.0)));
        };
    in builtins.foldl'
      (prev: epoch:
        train {
          pretrained = prev;
          scriptArgs = scriptArgs' epoch;
        }
      ) (train {
        scriptArgs = scriptArgs' 1;
      }
      ) (iota 26 2);
  test = args@{...} : testDerivation ({
    pname = "torchvision-fasterrcnn-test";
    description = "The test of fasterrcnn";
    script = "test.py";
    scriptArgs = {
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    datasets = bdd100k;
  } // args);
  detect = args@{...} : detectDerivation ({
    pname = "torchvision-fasterrcnn-detect";
    description = "The inference of fasterrcnn";
    script = "inference.py";
    scriptArgs = {
      device = "cpu";
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    datasets = bdd100k-mini;
  } // args);
  classification = args@{...} : clsDerivation ({
    pname = "torchvision-fasterrcnn-cls";
    description = "The classification of fasterrcnn";
    script = "classification.py";
    scriptArgs = {
      device = "cpu";
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    datasets = bdd100k-mini;
    dataset-dir = "bdd100k";
  } // args);
  gen-feature-map-with-partial-image = args@{...} : clsDerivation ({
    pname = "torchvision-fasterrcnn-feature-map";
    description = "The feature-map of fasterrcnn";
    script = "gen_feature_map.py";
    scriptArgs = {
      device = "cpu";
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    datasets = bdd100k-mini;
    dataset-dir = "bdd100k-objects";
  } // args);
  gen-feature-map = args@{...} : clsDerivation ({
    pname = "torchvision-fasterrcnn-feature-map";
    description = "The feature-map of fasterrcnn";
    script = "gen_feature_map_from_whole_camera.py";
    scriptArgs = {
#      device = "cpu";
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    datasets = bdd100k-mini;
    dataset-dir = "bdd100k";
    checkpoint_filename = "best.pth";
  } // args);
  import-weight-files = args@{...} : runDerivation ({
    pname = "import-weight-files-of-fasterrcnn";
    description = "import-weight-files-of-fasterrcnn";
    script = "import_weights.py";
    scriptArgs = {
      weight-dir = "";
      output-dir = "output";
    };
    pretrained = pretrainedModel;
    checkpoint_filename = "best.pth";
  } // args);
  myShell = self: system: pkgs.mkShell {
    packages = with pkgs; [ myPython pretrainedModel ];
    shellHook = ''
      export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
      #export REQUESTS_CA_BUNDLE=""
      export TRANSFORMERS_CACHE=$TMPDIR
      export XDG_CACHE_HOME=$TMPDIR
      
      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${myPython.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH
      pwd
      mkdir -p $TMP/torch/hub/checkpoints
      ln -s ${resnet50} $TMP/torch/hub/checkpoints/resnet50-0676ba61.pth
      ls -l $TMP/torch/hub/checkpoints
      ln -s ${pretrainedModel.out}/output/*.pth .
      mkdir -p $TMP/output
    '';
    inputsFrom = builtins.attrValues self.packages.${system};
  };
}
