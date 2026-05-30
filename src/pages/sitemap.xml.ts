import { getCollection } from 'astro:content';
import slugify from '../utils/slugify';

export async function GET(context) {
  const site = context.site?.toString() || '';
  const posts = await getCollection('blog');

  const pages = [
    '/',
    '/blog/',
    '/about/',
    '/tags/',
  ];

  const postUrls = posts.map((p) => `/posts/${slugify(p.data.title)}/`);

  const uniqueTags = [...new Set(posts.map((p) => p.data.tags).flat())];
  const tagUrls = uniqueTags.map((t) => `/tags/${slugify(t)}/`);

  const urls = [...pages, ...postUrls, ...tagUrls];

  const itemsXml = urls
    .map((url) => `  <url>\n    <loc>${site}${url}</loc>\n  </url>`)
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${itemsXml}\n</urlset>`;

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml',
    },
  });
}
