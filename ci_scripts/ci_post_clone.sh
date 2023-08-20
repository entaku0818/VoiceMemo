#!/bin/sh

#  ci_post_clone.sh
#  VoiLog
#
#  Created by 遠藤拓弥 on 20.8.2023.
#  
#!/bin/zsh

#  ci_post_clone.sh

env_file_path="../Env.swift"

typeset -A envValues

envValues[API_KEY]=$API_KEY
envValues[ADMOB_APP_ID]=$ADMOB_APP_ID

for key in ${(k)envValues}
  sed -i -e "s/${key}/${envValues[$key]}/g" "${env_file_path}"
