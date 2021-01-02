SELECT
ii.name,
array_agg(k.keyword) AS keywords,
sum(ii.downloads) as downloads,
ii.textsearchable_index_col,
max(
    ts_rank_cd(
        '{0.00, 0.2, 0.4, 1.0}',
        textsearchable_index_col, to_tsquery('english', 'git:*') || to_tsquery('simple', 'git:*'),
        0
    )
) AS rank_,
ii.weights,
ii.positions

FROM (
SELECT
c.id,
c.name,
c.downloads,
c.textsearchable_index_col,
substring((unnest(textsearchable_index_col)).lexeme FROM 1 FOR 20) AS lexeme,
(unnest(textsearchable_index_col)).weights AS weights ,
(unnest(textsearchable_index_col)).positions AS positions

FROM crates AS c

WHERE
c.name like '%git%'

) AS ii

LEFT OUTER JOIN crates_keywords AS ck ON ii.id = ck.crate_id
LEFT OUTER JOIN keywords AS k ON ck.keyword_id = k.id

WHERE
lexeme = 'git'


GROUP BY
ii.name,
ii.weights,
ii.positions,
ii.textsearchable_index_col

ORDER BY
MAX(
    ts_rank_cd(
        '{0.00, 0.2, 0.4, 1.0}',
        textsearchable_index_col, to_tsquery('english', 'git:*') || to_tsquery('simple', 'git:*'),
        0
    )
) DESC

;

