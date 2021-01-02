CREATE OR REPLACE FUNCTION trigger_crates_name_search() RETURNS TRIGGER AS $$
DECLARE kws TEXT;
begin
  SELECT array_to_string(array_agg(keyword), ',') INTO kws
    FROM keywords INNER JOIN crates_keywords
    ON keywords.id = crates_keywords.keyword_id
    WHERE crates_keywords.crate_id = new.id;
  new.textsearchable_index_col :=
     setweight(to_tsvector('pg_catalog.english',
                           coalesce(new.name, '')), 'A') ||
     setweight(to_tsvector('pg_catalog.english',
                           coalesce(kws, '')), 'B') ||
     setweight(to_tsvector('pg_catalog.english',
                           coalesce(new.description, '')), 'C') ||
     setweight(to_tsvector('pg_catalog.english',
                           coalesce(new.readme, '')), 'D');
  return new;
end
$$ LANGUAGE PLPGSQL;

-- reindex, `trigger_crates_name_search` is called `BEFORE INSERT OR UPDATE OF updated_at`
UPDATE crates SET updated_at = updated_at;
