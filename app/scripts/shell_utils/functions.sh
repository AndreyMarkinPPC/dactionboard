#!/bin/bash
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

check_ads_config() {
  validate=$1
  if [[ -n $ads_config ]]; then
    use_google_ads_config='y'
  elif [[ -f "./google-ads.yaml" ]]; then
    echo -n "Would you like to use google-ads.yaml (Y/n)?: "
    read -r use_google_ads_config
    use_google_ads_config=$(convert_answer $use_google_ads_config 'Y')
    ads_config=google-ads.yaml
  elif [[ -f "$HOME/google-ads.yaml" ]]; then
    echo -n "Would you like to use ~/google-ads.yaml (Y/n)?: "
    read -r use_google_ads_config
    use_google_ads_config=$(convert_answer $use_google_ads_config 'Y')
    ads_config=$HOME/google-ads.yaml
  fi

  if [[ $use_google_ads_config != 'y' ]]; then
    # entering credentials one by one
    read -p "developer_token (from your Google Ads account): " -r DEVELOPER_TOKEN
    read -p "OAuth client id: " -r OAUTH_CLIENT_ID
    read -p "OAuth client secret: " -r OAUTH_CLIENT_SECRET
    echo "See details on how to generate a refresh token here: https://github.com/google/ads-api-report-fetcher/blob/main/docs/how-to-authenticate-ads-api.md"
    read -p "refresh_token: " -r REFRESH_TOKEN
    read -p "login_customer_id (MCC): " -r MCC_ID
    ads_config=google-ads.yaml
    if [[ -f "./google-ads.yaml" ]]; then
      read -p "File google-ads.yaml already exists, do you want to overwrite it (Y/n)? " -r overwrite
      overwrite=$(convert_answer $overwrite 'Y')
      if [[ $overwrite = 'n' ]]; then
        read -p "Enter a file name for your google-ads.yaml: " -r ads_config
      fi
    fi
    echo "# google-ads.yaml was auto-generated by installer (run-local.sh) ${date}
developer_token: ${DEVELOPER_TOKEN}
client_id: ${OAUTH_CLIENT_ID}
client_secret: ${OAUTH_CLIENT_SECRET}
refresh_token: ${REFRESH_TOKEN}
login_customer_id: ${MCC_ID}
use_proto_plus: True
    " > $ads_config
  fi
  if [[ $validate = "y" ]]; then
    echo "Validating $ads_config..."
    temp_file=$(mktemp)
    set +e
    gaarf "SELECT mobile_device_constant.type FROM mobile_device_constant LIMIT 1" --ads-config=$ads_config --input=console --output=console &> $temp_file
    set -e
    errors=$(cat $temp_file | grep -E "errors|exception" | wc -l)
    if (($errors > 0)); then
      echo -e "${RED}$ads_config is invalid, details below${NC} "
      error_message=`sed -n -e '/GoogleAdsException/,/request_id/p' $temp_file`
      if [[ -n $error_message ]]; then
        echo $error_message
      else
        sed -n -e '/exception/,$p' $temp_file
      fi
      exit
    fi
  fi
}

convert_answer() {
  answer="$1"
  echo ${answer:-y} | tr '[:upper:]' '[:lower:]' | cut -c1
}

prompt_running() {
  if [[ $generate_config_only = "y" ]]; then
    exit
  fi
  echo -n -e "${COLOR}Start running $solution_name? Y/n: ${NC}"
  read -r answer
  answer=$(convert_answer $answer 'Y')

  if [[ $answer = "y" ]]; then
    echo "Running..."
  else
    echo "Exiting the script..."
    exit
  fi
}

parse_yaml () {
   local yaml_file="$1"
   local prefix="$2"
   while read line; do
      local variable=`echo "$line" | sed -e 's/: /=/'`
      if [ "${variable::1}" != "#" ] && [ `echo "$variable" | wc -c` -gt 2 ]; then
         eval "export ${prefix}${variable}"
      fi
   done < <(cat $yaml_file)
}

check_gaarf_version() {
  if [[ $quiet = "n" ]]; then
    echo "checking google-ads-api-report-fetcher version"
    gaarf_version=`gaarf --version | cut -d ' ' -f3`
    IFS='.' read -r -a version_array <<< "$gaarf_version"
    major_version="${version_array[0]}"
    minor_version="${version_array[1]}"

    if [[ $major_version -ge 1 && $minor_version -ge 9 ]]; then
      echo "google-ads-api-report-fetcher is up-to-date"
    else
      echo "You are using an old version of google-ads-api-report-fetcher library"
      echo "Please update it by running the following command:"
      echo -e "${COLOR}pip install -U google-ads-api-report-fetcher${NC}"
      exit 1
    fi
  fi
}

infer_answer_from_config() {
  config=$1
  section=$2
  value="${!section}"
  if [[ $value != "y" ]]; then
    if cat $config | grep -q "$section: true"; then
      value="y"
    else
      value=`cat $config | grep $section | cut -d ":" -f2- | head -n1 | sed "s/'//g" | sed 's/"//g'`
    fi
  fi
  declare -g "$section"="$value"
}

save_to_config() {
  config=$1
  section=$2
  value="${!section}"
  echo "$section: $value"
  if [[ $value = "y" ]]; then
    if cat $config | grep -q "$section: false"; then
      sed -i "/$section/s/false/true"/g $config
    elif cat $config | grep -q "$section: true"; then
      :
    else
      echo "$section: true" >> $config
    fi
  else
    if cat $config | grep -q "$section: true"; then
      sed -i "/$section/s/true/false"/g $config
    elif cat $config | grep -q "$section: false"; then
      :
    else
      echo "$section: false" >> $config
    fi
  fi
}

check_initial_load () {
  infer_answer_from_config $config_file output_dataset
  infer_answer_from_config $config_file initial_load_date
  initial_date=`echo "$initial_load_date" | sed 's/-//g' | sed 's/ //g'`
  infer_answer_from_config $config_file project
  infer_answer_from_config $config_file start_date
  echo "SELECT * FROM ${output_dataset}.ad_video_performance_${initial_date};" > /tmp/initial_load.sql

  missing_initial_load=`gaarf-bq /tmp/initial_load.sql -c $config_file | grep "404 Not found" | wc -l`

  if (( $missing_initial_load == 1 )) ; then
    initial_load="y"
  else
    infer_answer_from_config $config_file initial_load
  fi
}

ask_for_incremental_saving() {
  bq_dataset_output=$(echo $bq_dataset"_output")
  echo -e "${COLOR}App Reporting Pack will extract fresh performance data from Google Ads API within selected reporting window (i.e. last 30 days).${NC}"
  echo -e "${COLOR}(More at https://github.com/google/app-reporting-pack/blob/main/docs/storing-data-for-extended-period.md):${NC}"
  get_start_end_date
  echo -n "Download historical performance data starting from YYYY-MM-DD or press Enter to skip: "
  read -r initial_load_date
  initial_load="n"
  if [ -z $initial_load_date ]; then
    echo -e "\tYou haven't entered initial date"
    echo -n -e "\tPlease provide initial date or press Enter to skip: "
    read -r initial_load_date
  fi
  if [ ! -z $initial_load_date ]; then
    validate_load_date $initial_load_date
    if [[ $invalid_initial_load_date = "y" ]]; then
      echo -e "\tYou've entered invalid initial date"
      echo -n -e "\tPlease provide initial date in YYYY-MM-DD format (i.e. 2023-01-01) or press Enter to skip: "
      read -r initial_load_date
      validate_load_date $initial_load_date
    fi
    if [[ $invalid_initial_load_date = "y" ]]; then
      echo "invalid initial load date ($invalid_load_date), skipping initial load"
    elif echo "$start_date" | grep -E ":YYYYMMDD-*"; then
      initial_load="y"
    else
      echo "start_date is not dynamic ($start_date), skipping initial load"
    fi
  fi
}

generate_bq_macros() {
  bq_dataset_output=$(echo $bq_dataset"_output")
  bq_dataset_legacy=$(echo $bq_dataset"_legacy")
  skan_schema_table=$(echo $bq_dataset".skan_schema")
  macros=$(echo --macro.bq_dataset=$bq_dataset --macro.output_dataset=$bq_dataset_output)
  if [[ $initial_load = "y" || $incremental = "y" ]]; then
    macros="$macros --template.incremental=true"
  fi
}
get_start_end_date() {
  echo -n -e "Enter reporting window in days (default '90 days' but not less than conversion window): "
  read -r start_date_days
  start_date=":YYYYMMDD-${start_date_days}"
  start_date=${start_date:-:YYYYMMDD-90}
  end_date=":YYYYMMDD-1"
}

validate_load_date() {
  local _initial_load_date=$1
  if [[ ! $_initial_load_date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    invalid_initial_load_date="y"
  else
    invalid_initial_load_date="n"
  fi
}
