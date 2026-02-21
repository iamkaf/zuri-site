import type { APIRoute } from 'astro';

const REPO = 'iamkaf/zuri';
const DEFAULT_REF = 'main';
export const prerender = false;

const rawUrlForRef = (ref: string) =>
  `https://raw.githubusercontent.com/${REPO}/${encodeURIComponent(ref)}/install.sh`;

export const GET: APIRoute = async ({ url }) => {
  const ref = url.searchParams.get('ref') || DEFAULT_REF;
  const upstream = await fetch(rawUrlForRef(ref), {
    headers: { 'User-Agent': 'zuri-site-install-proxy' },
  });

  if (!upstream.ok) {
    return new Response('Failed to fetch installer script.\n', {
      status: 502,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-store',
      },
    });
  }

  const body = await upstream.text();
  return new Response(body, {
    headers: {
      'content-type': 'text/x-shellscript; charset=utf-8',
      'cache-control': 'public, s-maxage=300, max-age=60, stale-while-revalidate=86400',
      'x-install-source': `${REPO}@${ref}`,
    },
  });
};
