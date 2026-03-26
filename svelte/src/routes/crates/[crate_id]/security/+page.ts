import type { Advisory } from '$lib/utils/version-ranges';

import { error } from '@sveltejs/kit';

import { versionRanges } from '$lib/utils/version-ranges';

export interface EnrichedAdvisory extends Advisory {
  versionRanges: string | null;
  cvss: string | null;
}

function extractCvss(advisory: Advisory): string | null {
  let cvssEntry =
    advisory.severity?.find(s => s.type === 'CVSS_V4') ?? advisory.severity?.find(s => s.type === 'CVSS_V3');
  return cvssEntry?.score ?? null;
}

async function fetchAdvisories(crateId: string, fetch: typeof globalThis.fetch): Promise<EnrichedAdvisory[]> {
  let url = `https://rustsec.org/packages/${crateId}.json`;
  let response = await fetch(url);
  if (response.status === 404) {
    return [];
  } else if (response.ok) {
    let advisories: Advisory[] = await response.json();
    return advisories
      .filter(
        advisory =>
          !advisory.withdrawn &&
          !advisory.affected?.some(affected => affected.database_specific?.informational === 'unmaintained'),
      )
      .map(advisory => ({
        ...advisory,
        versionRanges: versionRanges(advisory),
        cvss: extractCvss(advisory),
      }));
  } else {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
}

export async function load({ fetch, params }) {
  let crateName = params.crate_id;

  try {
    let [advisories, micromarkModule, gfmModule] = await Promise.all([
      fetchAdvisories(crateName, fetch),
      import('micromark'),
      import('micromark-extension-gfm'),
    ]);

    let convertMarkdown = (markdown: string): string => {
      return micromarkModule.micromark(markdown, {
        extensions: [gfmModule.gfm()],
        htmlExtensions: [gfmModule.gfmHtml()],
      });
    };

    return { advisories, convertMarkdown };
  } catch {
    error(500, { message: `${crateName}: Failed to load advisories`, tryAgain: true });
  }
}
