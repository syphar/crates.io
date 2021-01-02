explain analyze SELECT
(rank_download_percent * 2 + rank_full_text) AS combined_rank,
aa.*

FROM (
    SELECT
        ii.name,
        array_agg(k.keyword) AS keywords,
        sum(ii.downloads) AS downloads,
        max(
            ts_rank_cd(
                '{0.00, 0.0, 0.4, 1.0}',
                textsearchable_index_col, plainto_tsquery('english', 'serde json') || plainto_tsquery('simple', 'serde json'),
                0
            )
        ) AS rank_full_text,
        max(rank_download_percent) AS rank_download_percent

    FROM (
        SELECT
            c.id,
            c.name,
            c.downloads,
            c.textsearchable_index_col,
            percent_rank() OVER (ORDER BY downloads ASC) AS rank_download_percent

        FROM crates AS c

        WHERE
            plainto_tsquery('english', 'serde json') || plainto_tsquery('simple', 'serde json') @@ c.textsearchable_index_col

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

