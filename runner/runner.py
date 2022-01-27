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

from concurrent import futures
from typing import Any, Callable, Dict, Sequence
import sys
import logging

from google.ads.googleads.v9.services.services.google_ads_service.client import GoogleAdsServiceClient  #type: ignore
from operator import attrgetter

import arg_parser
import parsers
import writer
import api_handler
import api_clients
import query_editor

logging.basicConfig(
    format="[%(asctime)s][%(name)s][%(levelname)s] %(message)s",
    filename="dactionboard.log",
    level=logging.INFO,
    datefmt="%H:%M:%S")
logging.getLogger("google.ads.googleads.client").setLevel(logging.WARNING)

args = arg_parser.parse_cli_args()

ga_service = api_clients.GoogleAdsApiClient().get_client()

google_ads_row_parser = parsers.GoogleAdsRowParser()

writer_factory = writer.WriterFactory()
writer_client = writer_factory.create_writer(args.save, **vars(args))

customer_ids = api_handler.get_customer_ids(ga_service, args.customer_id)
logging.info("Total number of customer_ids is %d", len(customer_ids))


def process_query(query: str, customer_ids: Dict[str, str],
                  api_client: GoogleAdsServiceClient,
                  parser: parsers.BaseParser,
                  writer_client: writer.AbsWriter) -> None:
    query_elements = query_editor.get_query_elements(query)
    query_text = query_elements.query_text.format(start_date=args.start_date,
                                                  end_date=args.end_date)
    getter = attrgetter(*query_elements.fields)
    total_results = []
    for customer_id in customer_ids:
        response = api_client.search_stream(customer_id=customer_id,
                                            query=query_text)
        for batch in response:
            results = [
                api_handler.parse_ads_row(row, getter, parser)
                for row in batch.results
            ]
            logging.info(
                "[Query: %s] customer_id: %s, nrows - %d, size in bytes - %d",
                query, customer_id, len(results), sys.getsizeof(results))
            total_results.extend(results)

    logging.info("[Query: %s] total size in bytes - %d", query,
                 sys.getsizeof(total_results))
    output = writer_client.write(total_results, query,
                                 query_elements.column_names)


with futures.ThreadPoolExecutor() as executor:
    future_to_query = {
        executor.submit(process_query, query, customer_ids, ga_service,
                        google_ads_row_parser, writer_client): query
        for query in args.query
    }
    for future in futures.as_completed(future_to_query):
        query = future_to_query[future]
        try:
            result = future.result()
            print(f"{query} executed successfully")
        except Exception as e:
            print(f"{query} generated an exception: {e}")
