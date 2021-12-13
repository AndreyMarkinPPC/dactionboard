# dActionBoard - Video Action Campaigns Reporting & Alerts

## Disclaimer
This is not an officially supported Google product.

Copyright 2021 Google LLC. This solution, including any related sample code or data, is made available on an “as is,” “as available,” and “with all faults” basis, solely for illustrative purposes, and without warranty or representation of any kind. This solution is experimental, unsupported and provided solely for your convenience. Your use of it is subject to your agreements with Google, as applicable, and may constitute a beta feature as defined under those agreements. To the extent that you make any data available to Google in connection with your use of the solution, you represent and warrant that you have all necessary and appropriate rights, consents and permissions to permit Google to use and process that data. By using any portion of this solution, you acknowledge, assume and accept all risks, known and unknown, associated with its usage, including with respect to your deployment of any portion of this solution in your systems, or usage in connection with your business, if at all.

## Getting started

1. create virtual enviroment

```
python3 -m venv dactionboard
source dactionboard/bin/activate
pip install -r requirements.txt
```

2. authenticate google ads to create `google-ads.yaml` file

    2.1. Create `google-ads.yaml` file in your home directory with the following content
    (or copy from `configs` folder):

    ```
    developer_token:
    client_id:
    client_secret:
    refresh_token:
    login_customer_id:
    client_customer_id:
    use_proto_plus: True
    ```
    2.2. [Get Google Ads Developer Token](https://developers.google.com/google-ads/api/docs/first-call/dev-token). Add developer token id to `google-ads.yaml` file.

    2.3. [Generate OAuth2 credentials for **desktop application**](https://developers.google.com/adwords/api/docs/guides/authentication#generate_oauth2_credentials)
    * Click the download icon next to the credentials that you just created and save file to your computer
    *  Add client_id and client_secret value to `google-ads.yaml` file

    2.4. Download python source file to perform desktop authentication

    ```
    curl -0 https://raw.githubusercontent.com/googleads/google-ads-python/868bf36689f1ca4310bdead9c46eed61b8ad1d11/examples/authentication/authenticate_in_desktop_application.py
    ```

    2.5. Run desktop authentication with downloaded credentials file:
    ```
    python authenticate_in_desktop_application.py --client_secrets_path=/path/to/secrets.json
    ```
    * Copy generated refresh token and add it to `google-ads.yaml` file.

    2.6. [Enable Google Ads API in your project](https://developers.google.com/google-ads/api/docs/first-call/oauth-cloud-project#enable_the_in_your_project)

    2.7. Add login_customer_id and client_customer_id (MMC under which Developer token was generated) to `google-ads.yaml`. **ID should be in 11111111 format, do not add dashes as separator**.

3. clone this repository

Before cloning this repository you need to do the following:

* Visit https://professional-services.googlesource.com/new-password and login with your account
* Once authenticated please copy all lines in box and paste them in the terminal.

```
git clone https://professional-services.googlesource.com/solutions/dactionboard
```

4. Specify enviromental variables

```
export CUSTOMER_ID=
export BQ_PROJECT=
export BQ_DATASET=
export START_DATE=
export END_DATE=
```

5. Run script to fetch data and store in BigQuery

```
cd dactionboard
python runner/runner.py google_ads_queries/*/*.sql \
    --customer_id=$CUSTOMER_ID \
    --save=bq \
    --bq_project=$BQ_PROJECT \
    --bq_dataset=$BQ_DATASET \
    --start_date=$START_DATE \
    --end_date=$END_DATE
```
