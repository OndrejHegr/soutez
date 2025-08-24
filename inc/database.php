<?php
function loadData(int $contestId): array
{
    return dibi::fetchAll('
        select
            co.id,
            a.id as age_id,
            a.title as age_title,
            a.age_from,
            cs.id as style_id,
            cs.title as style_title,
            cs.music_required,
            IFNULL(lev.id, 0) as level_id,
            IFNULL(lev.title, "Bez úrovně") as level_title
        from contest_offers co
        join contest_age a on a.id = co.age_id
        join contest_style cs on cs.id = co.style_id
        left join contest_level lev on lev.id = co.level_id
        where co.contest_id = %i
        order by a.age_from, cs.title, lev.sort_order',
        $contestId
    );
}

function getContestRule(int $contestId, int $ageId, ?int $styleId, ?int $levelId): array
{
    return (array) dibi::fetch('
        SELECT fee_czk, min_duration_sec, max_duration_sec
        FROM contest_rules
        WHERE contest_id = %i
          AND (age_id = %i OR age_id IS NULL)
          AND (style_id = %i OR style_id IS NULL)
          AND (level_id = %i OR level_id IS NULL)
        ORDER BY 
          (age_id IS NOT NULL) DESC,
          (style_id IS NOT NULL) DESC,
          (level_id IS NOT NULL) DESC
        LIMIT 1
    ', $contestId, $ageId, $styleId, $levelId);
}
function getTeamSizeRule(int $contestId, int $amount): array
{
    return (array) dibi::fetch('
        SELECT id, min_duration_sec, max_duration_sec
        FROM contest_team_size
        WHERE contest_id = %i
          AND min_members <= %i AND max_members >= %i
        LIMIT 1
    ', $contestId, $amount, $amount);
}
