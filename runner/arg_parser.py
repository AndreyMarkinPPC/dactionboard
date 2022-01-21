# Copyright 2021 Google LLC
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

import argparse


def parse_cli_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("query", nargs="+")
    parser.add_argument("--customer_id", dest="customer_id")
    parser.add_argument("--save", dest="save", default="csv")
    parser.add_argument("-p", dest="print", default=False)
    parser.add_argument("--destination", dest="destination")
    parser.add_argument("--bq_project", dest="project")
    parser.add_argument("--bq_dataset", dest="dataset")
    parser.add_argument("--start_date", dest="start_date")
    parser.add_argument("--end_date", dest="end_date")
    return parser.parse_args()
