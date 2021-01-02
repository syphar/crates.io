CREATE OR REPLACE FUNCTION trigger_crates_name_search() RETURNS TRIGGER AS $$
DECLARE kws TEXT;
begin
  SELECT array_to_string(array_agg(keyword), ',') INTO kws
    FROM keywords INNER JOIN crates_keywords
    ON keywords.id = crates_keywords.keyword_id
    WHERE crates_keywords.crate_id = new.id;

    -- postgres default weights: {0.1, 0.2, 0.4, 1.0}  for {D, C, B, A}
    -- can be changed later in `ts_rank_cd` or `ts_rank` call
    new.textsearchable_index_col :=
        -- simple catalog has no stop-words and no stemming.
        setweight(to_tsvector('pg_catalog.simple', coalesce(new.name, '')), 'A') ||
        setweight(to_tsvector('pg_catalog.simple', coalesce(kws, '')), 'A')

        -- for description and readme we use the normal english index
        -- setweight(to_tsvector('pg_catalog.english', coalesce(new.description, '')), 'D') ||
        --setweight(to_tsvector('pg_catalog.english', coalesce(new.readme, '')), 'D');

  return new;
end
$$ LANGUAGE PLPGSQL;

-- reindex, `trigger_crates_name_search` is called `BEFORE INSERT OR UPDATE OF updated_at`
UPDATE crates SET updated_at = updated_at;
