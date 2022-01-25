CREATE OR REPLACE TABLE {bq_project}.{bq_dataset}.geo_performance_F
AS (
WITH
    GeoConstants AS (
	SELECT DISTINCT
	   constant_id,
           country_code,
 	   name
	FROM {bq_project}.{bq_dataset}.geo_target_constant
    )
SELECT
    PARSE_DATE("%Y-%m-%d", AP.date) AS day,
    M.account_id,
    M.account_name,
    M.currency,
    M.campaign_id,
    M.campaign_name,
    M.campaign_status,
    M.ad_group_id,
    M.ad_group_name,
    M.ad_group_status,
    GT.country_code AS country_code,
    GT.name AS country_name,
    SUM(AP.clicks) AS clicks,
    SUM(AP.impressions) AS impressions,
    SUM(AP.all_conversions) AS all_conversions,
    SUM(AP.conversions) AS conversions,
    SUM(AP.video_views) AS video_views,
    SUM(AP.view_through_conversions) AS view_through_conversions,
    SUM(AP.engagements) AS engagements,
    ROUND(SUM(AP.cost) / 1e6) AS cost
FROM {bq_project}.{bq_dataset}.geo_performance AS AP
INNER JOIN {bq_project}.{bq_dataset}.mapping AS M
  ON AP.ad_group_id = M.ad_group_id
INNER JOIN GeoConstants AS GT
  ON AP.country_criterion_id = GT.constant_id
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);