"use client";

import { useEffect } from "react";
import { capture, isPostHogEnabled } from "@/lib/analytics/posthog";

interface SearchAnalyticsProps {
  hasQuery: boolean;
  /**
   * The raw query text, e.g. from `?q=...`. Used ONLY as an effect-retrigger
   * key below, so two distinct searches (e.g. two different zero-result
   * typo queries in a row) that happen to share the same has_query/filters/
   * result_count don't get coalesced into a single fired event. Must NEVER
   * be read inside the effect body or added to the capture() payload — see
   * the file-level comment on why the literal query text can't be logged.
   */
  queryText: string;
  /** Selected merchant type(s), e.g. ["restaurant"] — a small, closed vocab (not free text). */
  filterTypes: string[];
  /** Selected tags, e.g. ["vegano"] — also a small, closed vocab (not free text). */
  filterTags: string[];
  resultCount: number;
}

/**
 * Fires `search_performed` when /buscar renders with a query and/or filters
 * active. Deliberately omits the literal query text — only its presence
 * (`has_query`) is tracked, since free-text search input is the one part of
 * this URL-driven, otherwise-public search state that could reconstruct a
 * real search history. `filterTypes`/`filterTags` are safe to log verbatim:
 * they're selections from a small, fixed, public vocabulary of filter chips,
 * not user-authored text.
 */
export function SearchAnalytics({
  hasQuery,
  queryText,
  filterTypes,
  filterTags,
  resultCount,
}: SearchAnalyticsProps) {
  const filterTypesKey = filterTypes.join(",");
  const filterTagsKey = filterTags.join(",");

  useEffect(() => {
    if (!isPostHogEnabled) return;
    if (!hasQuery && filterTypes.length === 0 && filterTags.length === 0) {
      return;
    }

    capture("search_performed", {
      has_query: hasQuery,
      filter_types: filterTypes,
      filter_tags: filterTags,
      result_count: resultCount,
    });
    // filterTypes/filterTags are re-created every render by the server
    // component above us, so we key the effect off their stable string
    // form instead of the array identity. queryText is included purely as
    // a retrigger key (per-search uniqueness) — it's intentionally never
    // read inside this effect body or passed to capture() above.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasQuery, queryText, filterTypesKey, filterTagsKey, resultCount]);

  return null;
}
