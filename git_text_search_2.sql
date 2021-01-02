SELECT
(rank_download_percent * 2 + rank_full_text) AS combined_rank,
aa.*

FROM (
    SELECT
        ii.name,
        array_agg(k.keyword) AS keywords,
        sum(ii.downloads) AS downloads,
        max(
            ts_rank_cd(
                '{0.00, 0.2, 0.4, 1.0}',
                textsearchable_index_col, to_tsquery('english', 'ssh') || to_tsquery('simple', 'ssh'),
                0
            )
        ) AS rank_full_text,
        max(rank_number) AS rank_number,
        max(last_value) AS last_value,
        max(rank_download_percent) AS rank_download_percent,
        sum(ii.downloads) / 1000000.0 AS rank_million_downloads,
        ii.textsearchable_index_col

    FROM (
        SELECT
            c.id,
            c.name,
            c.downloads,
            c.textsearchable_index_col,
            cume_dist() OVER (ORDER BY downloads ASC) AS rank_number,
            last_value(downloads) OVER (ORDER BY downloads ASC) AS last_value,
            percent_rank() OVER (ORDER BY downloads ASC) AS rank_download_percent

        FROM crates AS c

        WHERE
            to_tsquery('english', 'ssh') || to_tsquery('simple', 'ssh') @@ c.textsearchable_index_col
    ) AS ii

    LEFT OUTER JOIN crates_keywords AS ck ON ii.id = ck.crate_id
    LEFT OUTER JOIN keywords AS k ON ck.keyword_id = k.id

    GROUP BY
        ii.name,
        ii.textsearchable_index_col
) AS aa

ORDER BY
combined_rank DESC

;

