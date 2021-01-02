CREATE OR REPLACE FUNCTION trigger_crates_name_search() RETURNS TRIGGER AS $$
DECLARE kws TEXT;
begin
  SELECT array_to_string(array_agg(keyword), ',') INTO kws
    FROM keywords INNER JOIN crates_keywords
    ON keywords.id = crates_keywords.keyword_id
    WHERE crates_keywords.crate_id = new.id;

    -- postgres default weights: {0.1, 0.2, 0.4, 1.0}  for {D, C, B, A}
    new.textsearchable_index_col :=
        -- simple catalog has no stop-words and no stemming.
        setweight(to_tsvector('pg_catalog.simple', coalesce(new.name, '')), 'A') ||
        setweight(to_tsvector('pg_catalog.simple', coalesce(kws, '')), 'A') ||

        -- for description and readme we use the normal english index
        setweight(to_tsvector('pg_catalog.english', coalesce(new.description, '')), 'D') ||
        setweight(to_tsvector('pg_catalog.english', coalesce(new.readme, '')), 'D');

  return new;
end
$$ LANGUAGE PLPGSQL;

-- reindex
SELECT trigger_crates_name_search() FROM crates;
